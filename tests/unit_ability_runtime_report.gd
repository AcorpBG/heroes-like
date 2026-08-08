extends Node

const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const BattleAiRulesScript = preload("res://scripts/core/BattleAiRules.gd")
const SpellRulesScript = preload("res://scripts/core/SpellRules.gd")

const OUTPUT_DIR := "res://.artifacts/unit_ability_runtime_report"
const REQUIRED_ABILITY_IDS := [
	"reach",
	"hookline",
	"rot_cant",
	"brace",
	"harry",
	"backstab",
	"fogwake",
	"shielding",
	"volley",
	"formation_guard",
	"resonance_relay",
	"solar_array_lane",
	"bloodrush",
	"obituary",
	"overheat",
	"pressure_artillery",
	"counter_ambush_flare",
	"sporeglass_mend",
	"foundry_aura",
]
const BASE_DEFENDER_UNIT_ID := "unit_river_guard"

var _errors: Array[String] = []
var _report := {
	"ok": false,
	"unit_count": 0,
	"ability_instance_count": 0,
	"runtime_consequence_count": 0,
	"ability_family_counts": {},
	"ability_family_consequence_counts": {},
	"units": [],
	"errors": [],
}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_ensure_output_dir()
	var units := _items(ContentService.load_json(ContentService.UNITS_PATH))
	_report["unit_count"] = units.size()
	for ability_id in REQUIRED_ABILITY_IDS:
		_report["ability_family_counts"][ability_id] = 0
		_report["ability_family_consequence_counts"][ability_id] = 0
	for unit in units:
		if not (unit is Dictionary):
			_error("Unit record is not a dictionary.")
			continue
		_validate_unit(unit)
	for ability_id in REQUIRED_ABILITY_IDS:
		if int(_report["ability_family_counts"].get(ability_id, 0)) <= 0:
			_error("No authored unit ability instances found for %s." % ability_id)
	_report["ok"] = _errors.is_empty()
	_report["errors"] = _errors.duplicate()
	_write_json("%s/report.json" % OUTPUT_DIR, _report)
	if _errors.is_empty():
		print("UNIT_ABILITY_RUNTIME_REPORT %s" % JSON.stringify(_summary_payload()))
	get_tree().quit(0 if _errors.is_empty() else 1)

func _validate_unit(unit: Dictionary) -> void:
	var unit_id := String(unit.get("id", "")).strip_edges()
	if unit_id == "":
		_error("Unit record is missing id.")
		return
	var ability_summaries := []
	var abilities: Array = unit.get("abilities", []) if unit.get("abilities", []) is Array else []
	var player_summary := BattleRulesScript._stack_ability_summary(_stack_for_unit(unit_id, "player", 0)) if not abilities.is_empty() else ""
	for ability in abilities:
		if not (ability is Dictionary):
			_error("Unit %s has non-dictionary ability payload." % unit_id)
			continue
		var ability_id := String(ability.get("id", "")).strip_edges()
		if ability_id == "":
			_error("Unit %s has ability with missing id." % unit_id)
			continue
		if ability_id not in REQUIRED_ABILITY_IDS:
			_error("Unit %s uses unsupported ability %s." % [unit_id, ability_id])
			continue
		var ability_name := String(ability.get("name", ability_id)).strip_edges()
		var player_summary_visible := ability_name != "" and player_summary.contains(ability_name)
		if not player_summary_visible:
			_error("Unit %s ability %s is missing from the player-facing stack summary." % [unit_id, ability_id])
		_report["ability_instance_count"] = int(_report["ability_instance_count"]) + 1
		_report["ability_family_counts"][ability_id] = int(_report["ability_family_counts"].get(ability_id, 0)) + 1
		var consequence := _runtime_consequence_for_ability(unit_id, ability_id)
		if bool(consequence.get("ok", false)):
			_report["runtime_consequence_count"] = int(_report["runtime_consequence_count"]) + 1
			_report["ability_family_consequence_counts"][ability_id] = int(_report["ability_family_consequence_counts"].get(ability_id, 0)) + 1
		else:
			_error("Unit %s ability %s has no proved runtime consequence: %s." % [unit_id, ability_id, String(consequence.get("reason", ""))])
		ability_summaries.append({
			"ability_id": ability_id,
			"player_summary_visible": player_summary_visible,
			"runtime_consequence": consequence,
		})
	_report["units"].append({
		"unit_id": unit_id,
		"name": String(unit.get("name", unit_id)),
		"ability_count": abilities.size(),
		"player_summary": player_summary,
		"abilities": ability_summaries,
	})

func _runtime_consequence_for_ability(unit_id: String, ability_id: String) -> Dictionary:
	match ability_id:
		"reach":
			return _probe_reach(unit_id)
		"hookline":
			return _probe_hookline(unit_id)
		"rot_cant":
			return _probe_rot_cant(unit_id)
		"brace":
			return _probe_brace(unit_id)
		"harry":
			return _probe_harry(unit_id)
		"obituary":
			return _probe_obituary(unit_id)
		"backstab":
			return _probe_backstab(unit_id)
		"fogwake":
			return _probe_fogwake(unit_id)
		"shielding":
			return _probe_shielding(unit_id)
		"volley":
			return _probe_volley(unit_id)
		"formation_guard":
			return _probe_formation_guard(unit_id)
		"resonance_relay":
			return _probe_resonance_relay(unit_id)
		"solar_array_lane":
			return _probe_solar_array_lane(unit_id)
		"bloodrush":
			return _probe_bloodrush(unit_id)
		"overheat":
			return _probe_overheat(unit_id)
		"pressure_artillery":
			return _probe_pressure_artillery(unit_id)
		"counter_ambush_flare":
			return _probe_counter_ambush_flare(unit_id)
		"sporeglass_mend":
			return _probe_sporeglass_mend(unit_id)
		"foundry_aura":
			return _probe_foundry_aura(unit_id)
		_:
			return {"ok": false, "reason": "unsupported ability"}

func _probe_reach(unit_id: String) -> Dictionary:
	var attacker := _stack_for_unit(unit_id, "player", 0)
	var defender := _defender_stack()
	var reach := _ability_by_id(attacker, "reach")
	var held_objective_types: Array = reach.get("held_objective_types", []) if reach.get("held_objective_types", []) is Array else []
	_set_hex(attacker, 4, 3)
	_set_hex(defender, 6, 3)
	var battle := _battle_for_stacks([attacker, defender])
	if not held_objective_types.is_empty():
		battle["field_objectives"] = [{"type": String(held_objective_types[0]), "control_side": "player"}]
	var stripped := _without_ability(attacker, "reach")
	var stripped_battle := _battle_for_stacks([stripped, defender.duplicate(true)])
	if not held_objective_types.is_empty():
		stripped_battle["field_objectives"] = battle["field_objectives"].duplicate(true)
	var legal_with := BattleRulesScript._can_make_melee_attack(attacker, battle, defender)
	var legal_without := BattleRulesScript._can_make_melee_attack(stripped, stripped_battle, defender)
	var ai_legal_with := BattleAiRulesScript._can_make_melee_attack(attacker, battle, defender)
	var unsupported_attacker := attacker.duplicate(true)
	var unsupported_defender := defender.duplicate(true)
	var unsupported_battle := _battle_for_stacks([unsupported_attacker, unsupported_defender])
	var unsupported_blocked := held_objective_types.is_empty() or (
		not BattleRulesScript._can_make_melee_attack(unsupported_attacker, unsupported_battle, unsupported_defender)
		and not BattleAiRulesScript._can_make_melee_attack(unsupported_attacker, unsupported_battle, unsupported_defender)
	)
	return {
		"ok": legal_with and ai_legal_with and not legal_without and unsupported_blocked,
		"probe": "reach_hex_distance_two_held_objective_melee_legality",
		"legal_with": legal_with,
		"ai_legal_with": ai_legal_with,
		"legal_without": legal_without,
		"held_objective_types": held_objective_types,
		"unsupported_lane_blocked": unsupported_blocked,
		"reason": "" if legal_with and ai_legal_with and not legal_without and unsupported_blocked else "reach did not uniquely unlock its authored distance-two objective lane",
	}

func _probe_hookline(unit_id: String) -> Dictionary:
	var attacker := _stack_for_unit(unit_id, "player", 0)
	var defender := _defender_stack()
	_set_hex(attacker, 4, 3)
	_set_hex(defender, 6, 3)
	var opening_battle := _battle_for_stacks([attacker.duplicate(true), defender.duplicate(true)], [], "plains", 1)
	var opening_attacker := BattleRulesScript._get_stack_by_id(opening_battle, String(attacker.get("battle_id", "")))
	var opening_defender := BattleRulesScript._get_stack_by_id(opening_battle, String(defender.get("battle_id", "")))
	var opening_blocked := (
		not BattleRulesScript._can_make_melee_attack(opening_attacker, opening_battle, opening_defender)
		and not BattleAiRulesScript._can_make_melee_attack(opening_attacker, opening_battle, opening_defender)
	)
	var battle := _battle_for_stacks([attacker, defender])
	var stripped := _without_ability(attacker, "hookline")
	var stripped_defender := defender.duplicate(true)
	var stripped_battle := _battle_for_stacks([stripped, stripped_defender])
	var legal_with := BattleRulesScript._can_make_melee_attack(attacker, battle, defender)
	var legal_without := BattleRulesScript._can_make_melee_attack(stripped, stripped_battle, stripped_defender)
	var ai_legal_with := BattleAiRulesScript._can_make_melee_attack(attacker, battle, defender)
	var damage_with := BattleRulesScript._ability_damage_modifier(attacker, defender, battle, false, false, 1)
	var damage_without := BattleRulesScript._ability_damage_modifier(stripped, stripped_defender, stripped_battle, false, false, 1)
	var messages := BattleRulesScript._apply_attack_ability_effects(battle, attacker, defender, false, 1)
	var updated_defender := BattleRulesScript._get_stack_by_id(battle, String(defender.get("battle_id", "")))
	var pulled_into_contact := BattleRulesScript._stack_hex_distance(attacker, updated_defender) == 1 and int(battle.get("distance", 1)) == 0
	var status_id := String(_ability_by_id(attacker, "hookline").get("status_id", ""))
	var pinned := SpellRulesScript.has_effect_id(updated_defender, battle, status_id)
	var uses_recorded := int(attacker.get("ability_uses", {}).get("hookline", 0))
	var second_live_attack := BattleRulesScript._can_make_melee_attack(attacker, battle, updated_defender)
	var second_ai_attack := BattleAiRulesScript._can_make_melee_attack(attacker, battle, updated_defender)
	var second_live_hookline := BattleRulesScript._hookline_available(attacker, battle)
	var second_ai_hookline := BattleAiRulesScript._hookline_available(attacker, battle)
	var ok := (
		opening_blocked
		and legal_with
		and ai_legal_with
		and not legal_without
		and damage_with < damage_without
		and pulled_into_contact
		and pinned
		and uses_recorded == 1
		and second_live_attack
		and second_ai_attack
		and not second_live_hookline
		and not second_ai_hookline
		and not messages.is_empty()
	)
	return {
		"ok": ok,
		"probe": "hookline_bounded_range_pin_and_ai_legality",
		"legal_with": legal_with,
		"opening_round_blocked": opening_blocked,
		"legal_without": legal_without,
		"ai_legal_with": ai_legal_with,
		"damage_modifier_with": damage_with,
		"damage_modifier_without": damage_without,
		"pulled_into_contact": pulled_into_contact,
		"pinned": pinned,
		"uses_recorded": uses_recorded,
		"second_live_attack": second_live_attack,
		"second_ai_attack": second_ai_attack,
		"second_live_hookline": second_live_hookline,
		"second_ai_hookline": second_ai_hookline,
		"reason": "" if ok else "hookline did not prove bounded cross-lane damage, pin, and AI legality",
	}

func _probe_rot_cant(unit_id: String) -> Dictionary:
	var attacker := _stack_for_unit(unit_id, "player", 0)
	var rot_cant := _ability_by_id(attacker, "rot_cant")
	var min_tier := int(rot_cant.get("target_min_tier", 1))
	var status_id := String(rot_cant.get("status_id", ""))
	var low_target := _defender_stack()
	low_target["tier"] = min_tier - 1
	var low_battle := _battle_for_stacks([attacker, low_target])
	var low_score := BattleAiRulesScript._attack_score(attacker, low_target, low_battle, true)
	var low_messages := BattleRulesScript._apply_attack_ability_effects(low_battle, attacker, low_target, true, 1)
	var low_updated := BattleRulesScript._get_stack_by_id(low_battle, String(low_target.get("battle_id", "")))
	var low_blocked := (
		not SpellRulesScript.has_effect_id(low_updated, low_battle, status_id)
		and int(attacker.get("ability_uses", {}).get("rot_cant", 0)) == 0
		and low_messages.is_empty()
	)
	var opening_attacker := _stack_for_unit(unit_id, "player", 0)
	var opening_target := _defender_stack()
	opening_target["tier"] = min_tier
	var opening_battle := _battle_for_stacks([opening_attacker, opening_target], [], "plains", 1)
	var opening_messages := BattleRulesScript._apply_attack_ability_effects(opening_battle, opening_attacker, opening_target, true, 1)
	var opening_updated := BattleRulesScript._get_stack_by_id(opening_battle, String(opening_target.get("battle_id", "")))
	var opening_applied := (
		SpellRulesScript.has_effect_id(opening_updated, opening_battle, status_id)
		and int(opening_attacker.get("ability_uses", {}).get("rot_cant", 0)) == 1
		and not opening_messages.is_empty()
	)

	attacker = _stack_for_unit(unit_id, "player", 0)
	rot_cant = _ability_by_id(attacker, "rot_cant")
	var target := _defender_stack()
	target["tier"] = min_tier
	var battle := _battle_for_stacks([attacker, target])
	var eligible_score := BattleAiRulesScript._attack_score(attacker, target, battle, true)
	var preview := BattleRulesScript._active_ability_window_summary(attacker, battle, target)
	var messages := BattleRulesScript._apply_attack_ability_effects(battle, attacker, target, true, 1)
	var updated := BattleRulesScript._get_stack_by_id(battle, String(target.get("battle_id", "")))
	var status_applied := SpellRulesScript.has_effect_id(updated, battle, status_id)
	var uses_recorded := int(attacker.get("ability_uses", {}).get("rot_cant", 0))
	var second_target := _defender_stack("enemy", 1)
	second_target["tier"] = min_tier
	battle["stacks"].append(second_target)
	BattleRulesScript._apply_attack_ability_effects(battle, attacker, second_target, true, 1)
	var second_updated := BattleRulesScript._get_stack_by_id(battle, String(second_target.get("battle_id", "")))
	var second_blocked := not SpellRulesScript.has_effect_id(second_updated, battle, status_id)
	var wounded := target.duplicate(true)
	var threshold := float(rot_cant.get("wounded_threshold_ratio", 0.5))
	wounded["total_health"] = maxi(1, int(float(wounded.get("base_count", 1) * wounded.get("unit_hp", 1)) * threshold))
	var stripped := _without_ability(attacker, "rot_cant")
	var damage_with := BattleRulesScript._ability_damage_modifier(attacker, wounded, battle, true, false, 1)
	var damage_without := BattleRulesScript._ability_damage_modifier(stripped, wounded, battle, true, false, 1)
	var priority_bonus := float(rot_cant.get("ai_target_priority_bonus", 0.0))
	var ok := (
		min_tier == 4
		and int(rot_cant.get("available_from_round", 0)) == 1
		and opening_applied
		and low_blocked
		and priority_bonus > 0.0
		and eligible_score - low_score >= priority_bonus
		and status_applied
		and uses_recorded == 1
		and second_blocked
		and damage_with > damage_without
		and preview.contains(String(rot_cant.get("name", "Rot Cant")))
		and not messages.is_empty()
	)
	return {
		"ok": ok,
		"probe": "rot_cant_veteran_gate_bounded_status_wounded_damage_and_ai",
		"target_min_tier": min_tier,
		"week_two_veteran_target_proven": min_tier == 4,
		"ai_target_priority_bonus": priority_bonus,
		"low_tier_blocked": low_blocked,
		"opening_round_applied": opening_applied,
		"low_tier_score": low_score,
		"eligible_score": eligible_score,
		"status_applied": status_applied,
		"uses_recorded": uses_recorded,
		"second_mark_blocked": second_blocked,
		"wounded_modifier_with": damage_with,
		"wounded_modifier_without": damage_without,
		"preview": preview,
		"reason": "" if ok else "rot cant did not prove its week-two veteran gate, use bound, status, wounded pressure, and AI contract",
	}

func _probe_brace(unit_id: String) -> Dictionary:
	var attacker := _stack_for_unit(unit_id, "player", 0)
	var defender := _defender_stack()
	attacker["defending"] = true
	var brace := _ability_by_id(attacker, "brace")
	var battle := _battle_for_stacks([attacker, defender])
	var stripped := _without_ability(attacker, "brace")
	var stripped_battle := _battle_for_stacks([stripped, defender.duplicate(true)])
	var retaliation_with := BattleRulesScript._ability_damage_modifier(attacker, defender, battle, false, true, 0)
	var retaliation_without := BattleRulesScript._ability_damage_modifier(stripped, defender, stripped_battle, false, true, 0)
	var ai_retaliation_with := BattleAiRulesScript._ability_damage_modifier(attacker, defender, battle, false, true, 0)
	var held_attacker := attacker.duplicate(true)
	var held_defender := defender.duplicate(true)
	var held_battle := _battle_for_stacks([held_attacker, held_defender])
	var held_objective_types: Array = brace.get("held_objective_types", []) if brace.get("held_objective_types", []) is Array else []
	if not held_objective_types.is_empty():
		held_battle["field_objectives"] = [{"type": String(held_objective_types[0]), "control_side": "player"}]
	var held_retaliation := BattleRulesScript._ability_damage_modifier(held_attacker, held_defender, held_battle, false, true, 0)
	var held_ai_retaliation := BattleAiRulesScript._ability_damage_modifier(held_attacker, held_defender, held_battle, false, true, 0)
	var defend_with := _defend_cohesion_delta(attacker, "brace", held_objective_types)
	var defend_without := _defend_cohesion_delta(stripped, "brace_stripped", held_objective_types)
	var base_retaliation_contract_ok := (
		retaliation_with > retaliation_without
		if held_objective_types.is_empty()
		else is_equal_approx(retaliation_with, retaliation_without)
	)
	var held_objective_contract_ok := held_objective_types.is_empty() or (
		held_retaliation > retaliation_with
		and is_equal_approx(held_ai_retaliation, held_retaliation)
	)
	var ok := (
		base_retaliation_contract_ok
		and is_equal_approx(ai_retaliation_with, retaliation_with)
		and defend_with > defend_without
		and held_objective_contract_ok
	)
	return {
		"ok": ok,
		"probe": "brace_retaliation_defend_and_held_objective_pressure",
		"retaliation_modifier_with": retaliation_with,
		"retaliation_modifier_without": retaliation_without,
		"ai_retaliation_modifier_with": ai_retaliation_with,
		"held_objective_types": held_objective_types,
		"held_objective_retaliation_modifier": held_retaliation,
		"held_objective_ai_retaliation_modifier": held_ai_retaliation,
		"defend_cohesion_delta_with": defend_with,
		"defend_cohesion_delta_without": defend_without,
		"reason": "" if ok else "brace did not preserve live/AI retaliation, defend cohesion, and held-objective pressure",
	}

func _probe_harry(unit_id: String) -> Dictionary:
	var attacker := _stack_for_unit(unit_id, "player", 0)
	var defender := _defender_stack()
	var harry := _ability_by_id(attacker, "harry")
	var status_id := String(harry.get("status_id", "")).strip_edges()
	if status_id == "":
		return {"ok": false, "probe": "harry_status_application", "reason": "harry ability has no status_id"}
	var target_min_tier := int(harry.get("target_min_tier", 1))
	var target_role := String(harry.get("target_role", ""))
	var required_support := int(harry.get("min_adjacent_allies_to_target", 0))
	var tier_gate_ok := true
	var ai_tier_gate_ok := true
	if target_min_tier > 1:
		var low_tier_attacker := _stack_for_unit(unit_id, "player", 0)
		var low_tier_defender := _defender_stack()
		low_tier_defender["tier"] = target_min_tier - 1
		if target_role != "":
			low_tier_defender["ranged"] = target_role == "ranged"
		_set_hex(low_tier_attacker, 4, 3)
		_set_hex(low_tier_defender, 5, 3)
		var low_tier_stacks := [low_tier_attacker, low_tier_defender]
		if required_support > 0:
			var low_tier_supporter := _defender_stack("player", 1)
			_set_hex(low_tier_supporter, 5, 2)
			low_tier_stacks.append(low_tier_supporter)
		var low_tier_battle := _battle_for_stacks(low_tier_stacks)
		var eligible_score_target := low_tier_defender.duplicate(true)
		eligible_score_target["tier"] = target_min_tier
		var low_tier_score := BattleAiRulesScript._attack_score(low_tier_attacker, low_tier_defender, low_tier_battle, bool(low_tier_attacker.get("ranged", false)))
		var eligible_tier_score := BattleAiRulesScript._attack_score(low_tier_attacker, eligible_score_target, low_tier_battle, bool(low_tier_attacker.get("ranged", false)))
		ai_tier_gate_ok = eligible_tier_score > low_tier_score
		var low_tier_messages := BattleRulesScript._apply_attack_ability_effects(
			low_tier_battle,
			low_tier_attacker,
			low_tier_defender,
			bool(low_tier_attacker.get("ranged", false)),
			1 if bool(low_tier_attacker.get("ranged", false)) else 0
		)
		var low_tier_updated := BattleRulesScript._get_stack_by_id(low_tier_battle, String(low_tier_defender.get("battle_id", "")))
		tier_gate_ok = (
			not SpellRulesScript.has_effect_id(low_tier_updated, low_tier_battle, status_id)
			and low_tier_messages.is_empty()
			and int(low_tier_attacker.get("ability_uses", {}).get("harry", 0)) == 0
		)
	_set_hex(attacker, 4, 3)
	_set_hex(defender, 5, 3)
	defender["tier"] = maxi(int(defender.get("tier", 1)), int(harry.get("target_min_tier", 1)))
	if target_role != "":
		defender["ranged"] = target_role == "ranged"
	var battle_stacks := [attacker, defender]
	if required_support > 0:
		var supporter := _defender_stack("player", 1)
		_set_hex(supporter, 5, 2)
		battle_stacks.append(supporter)
	var battle := _battle_for_stacks(battle_stacks)
	var preview := BattleRulesScript._active_ability_window_summary(attacker, battle, defender)
	var supported_harry_score := BattleAiRulesScript._attack_score(attacker, defender, battle, bool(attacker.get("ranged", false)))
	var messages := BattleRulesScript._apply_attack_ability_effects(
		battle,
		attacker,
		defender,
		bool(attacker.get("ranged", false)),
		1 if bool(attacker.get("ranged", false)) else 0
	)
	var updated_defender := BattleRulesScript._get_stack_by_id(battle, String(defender.get("battle_id", "")))
	var status_with := SpellRulesScript.has_effect_id(updated_defender, battle, status_id)
	var support_gate_ok := true
	var support_ai_gate_ok := true
	var unsupported_preview := ""
	if required_support > 0:
		var unsupported_attacker := _stack_for_unit(unit_id, "player", 0)
		var unsupported_defender := _defender_stack()
		var distant_supporter := _defender_stack("player", 1)
		_set_hex(unsupported_attacker, 4, 3)
		_set_hex(unsupported_defender, 5, 3)
		_set_hex(distant_supporter, 9, 6)
		unsupported_defender["tier"] = maxi(int(unsupported_defender.get("tier", 1)), int(harry.get("target_min_tier", 1)))
		if target_role != "":
			unsupported_defender["ranged"] = target_role == "ranged"
		var unsupported_battle := _battle_for_stacks([unsupported_attacker, unsupported_defender, distant_supporter])
		unsupported_preview = BattleRulesScript._active_ability_window_summary(unsupported_attacker, unsupported_battle, unsupported_defender)
		var unsupported_score := BattleAiRulesScript._attack_score(unsupported_attacker, unsupported_defender, unsupported_battle, bool(unsupported_attacker.get("ranged", false)))
		var unsupported_messages := BattleRulesScript._apply_attack_ability_effects(
			unsupported_battle,
			unsupported_attacker,
			unsupported_defender,
			bool(unsupported_attacker.get("ranged", false)),
			1 if bool(unsupported_attacker.get("ranged", false)) else 0
		)
		var unsupported_updated := BattleRulesScript._get_stack_by_id(unsupported_battle, String(unsupported_defender.get("battle_id", "")))
		support_gate_ok = (
			BattleRulesScript._harry_support_ready(attacker, defender, battle, harry)
			and BattleAiRulesScript._harry_support_ready(attacker, defender, battle, harry)
			and not BattleRulesScript._harry_support_ready(unsupported_attacker, unsupported_defender, unsupported_battle, harry)
			and not BattleAiRulesScript._harry_support_ready(unsupported_attacker, unsupported_defender, unsupported_battle, harry)
			and not SpellRulesScript.has_effect_id(unsupported_updated, unsupported_battle, status_id)
			and unsupported_messages.is_empty()
			and preview.contains("supported snare")
			and unsupported_preview.contains("needs 1 allied stack")
		)
		support_ai_gate_ok = supported_harry_score > unsupported_score
	var uses_per_battle := int(harry.get("uses_per_battle", 0))
	var bounded_second_mark_blocked := true
	var bounded_summary_ok := true
	var spent_preview := ""
	if uses_per_battle > 0:
		var second_defender := _defender_stack("enemy", 1)
		_set_hex(second_defender, 6, 3)
		second_defender["tier"] = maxi(int(second_defender.get("tier", 1)), int(harry.get("target_min_tier", 1)))
		if target_role != "":
			second_defender["ranged"] = target_role == "ranged"
		battle["stacks"].append(second_defender)
		BattleRulesScript._apply_attack_ability_effects(
			battle,
			attacker,
			second_defender,
			bool(attacker.get("ranged", false)),
			1 if bool(attacker.get("ranged", false)) else 0
		)
		var second_updated := BattleRulesScript._get_stack_by_id(battle, String(second_defender.get("battle_id", "")))
		bounded_second_mark_blocked = not SpellRulesScript.has_effect_id(second_updated, battle, status_id)
		spent_preview = BattleRulesScript._active_ability_window_summary(attacker, battle, second_defender)
		bounded_summary_ok = (
			preview.contains(String(harry.get("name", "Harry")))
			and spent_preview.contains("already been placed")
		)
	var stripped := _without_ability(attacker, "harry")
	var stripped_defender := _defender_stack()
	_set_hex(stripped, 4, 3)
	_set_hex(stripped_defender, 5, 3)
	var stripped_battle := _battle_for_stacks([stripped, stripped_defender])
	BattleRulesScript._apply_attack_ability_effects(
		stripped_battle,
		stripped,
		stripped_defender,
		bool(stripped.get("ranged", false)),
		1 if bool(stripped.get("ranged", false)) else 0
	)
	var stripped_updated := BattleRulesScript._get_stack_by_id(stripped_battle, String(stripped_defender.get("battle_id", "")))
	var status_without := SpellRulesScript.has_effect_id(stripped_updated, stripped_battle, status_id)
	var authored_harry := _ability_by_id(ContentService.get_unit(unit_id), "harry")
	var shielding_damage_multiplier := float(authored_harry.get("shielding_damage_multiplier", 1.0))
	var shielding_ai_target_priority_bonus := float(authored_harry.get("shielding_ai_target_priority_bonus", 0.0))
	var screen_snare_ok := true
	var shielded_damage_modifier := 1.0
	var stripped_shielded_damage_modifier := 1.0
	var ordinary_shield_damage_modifier := 1.0
	var stripped_ordinary_shield_damage_modifier := 1.0
	var unshielded_damage_modifier := 1.0
	var stripped_unshielded_damage_modifier := 1.0
	var screen_ai_target_id := ""
	var stripped_screen_ai_target_id := ""
	var screen_preview := ""
	var ordinary_shield_preview := ""
	if shielding_damage_multiplier > 1.0:
		var screen_attacker := _stack_for_unit(unit_id, "enemy", 0)
		var shielded_target := _defender_stack("player", 3)
		shielded_target["battle_id"] = "screen_snare_shielded_target"
		shielded_target["abilities"] = [{"id": "shielding", "ranged_damage_multiplier": 0.99, "snare_vulnerable": true}]
		var unshielded_target: Dictionary = shielded_target.duplicate(true)
		unshielded_target["battle_id"] = "screen_snare_unshielded_target"
		unshielded_target["abilities"] = []
		var ordinary_shield_target: Dictionary = shielded_target.duplicate(true)
		ordinary_shield_target["battle_id"] = "screen_snare_ordinary_shield_target"
		ordinary_shield_target["abilities"] = [{"id": "shielding", "ranged_damage_multiplier": 0.99}]
		_set_hex(screen_attacker, 4, 3)
		_set_hex(shielded_target, 6, 2)
		_set_hex(unshielded_target, 6, 4)
		var screen_battle := _battle_for_stacks([screen_attacker, shielded_target, unshielded_target])
		var stripped_screen_attacker := _without_ability(screen_attacker, "harry")
		var stripped_screen_battle := _battle_for_stacks([
			stripped_screen_attacker,
			shielded_target.duplicate(true),
			unshielded_target.duplicate(true),
		])
		shielded_damage_modifier = BattleRulesScript._ability_damage_modifier(screen_attacker, shielded_target, screen_battle, true, false, 1)
		stripped_shielded_damage_modifier = BattleRulesScript._ability_damage_modifier(stripped_screen_attacker, shielded_target, stripped_screen_battle, true, false, 1)
		unshielded_damage_modifier = BattleRulesScript._ability_damage_modifier(screen_attacker, unshielded_target, screen_battle, true, false, 1)
		stripped_unshielded_damage_modifier = BattleRulesScript._ability_damage_modifier(stripped_screen_attacker, unshielded_target, stripped_screen_battle, true, false, 1)
		ordinary_shield_damage_modifier = BattleRulesScript._ability_damage_modifier(screen_attacker, ordinary_shield_target, screen_battle, true, false, 1)
		stripped_ordinary_shield_damage_modifier = BattleRulesScript._ability_damage_modifier(stripped_screen_attacker, ordinary_shield_target, stripped_screen_battle, true, false, 1)
		var screen_ai_action := BattleAiRulesScript.choose_enemy_action(screen_battle, screen_attacker, {})
		var stripped_screen_ai_action := BattleAiRulesScript.choose_enemy_action(stripped_screen_battle, stripped_screen_attacker, {})
		screen_ai_target_id = String(screen_ai_action.get("target_battle_id", ""))
		stripped_screen_ai_target_id = String(stripped_screen_ai_action.get("target_battle_id", ""))
		screen_preview = BattleRulesScript._active_ability_window_summary(screen_attacker, screen_battle, shielded_target)
		ordinary_shield_preview = BattleRulesScript._active_ability_window_summary(screen_attacker, screen_battle, ordinary_shield_target)
		screen_snare_ok = (
			shielding_ai_target_priority_bonus > 0.0
			and is_equal_approx(shielded_damage_modifier, stripped_shielded_damage_modifier * shielding_damage_multiplier)
			and is_equal_approx(unshielded_damage_modifier, stripped_unshielded_damage_modifier)
			and is_equal_approx(ordinary_shield_damage_modifier, stripped_ordinary_shield_damage_modifier)
			and screen_ai_target_id == "screen_snare_shielded_target"
			and stripped_screen_ai_target_id == "screen_snare_unshielded_target"
			and screen_preview.contains("shield screen")
			and not ordinary_shield_preview.contains("shield screen")
		)
	var ok := status_with and not status_without and not messages.is_empty() and bounded_second_mark_blocked and bounded_summary_ok and tier_gate_ok and ai_tier_gate_ok and support_gate_ok and support_ai_gate_ok and screen_snare_ok
	return {
		"ok": ok,
		"probe": "harry_status_application",
		"status_id": status_id,
		"is_ranged": bool(attacker.get("ranged", false)),
		"status_with": status_with,
		"status_without": status_without,
		"message_count": messages.size(),
		"uses_per_battle": uses_per_battle,
		"target_min_tier": target_min_tier,
		"tier_gate_ok": tier_gate_ok,
		"ai_tier_gate_ok": ai_tier_gate_ok,
		"required_support": required_support,
		"support_gate_ok": support_gate_ok,
		"support_ai_gate_ok": support_ai_gate_ok,
		"unsupported_preview": unsupported_preview,
		"uses_recorded": int(attacker.get("ability_uses", {}).get("harry", 0)),
		"bounded_second_mark_blocked": bounded_second_mark_blocked,
		"preview": preview,
		"spent_preview": spent_preview,
		"bounded_summary_ok": bounded_summary_ok,
		"shielding_damage_multiplier": shielding_damage_multiplier,
		"shielding_ai_target_priority_bonus": shielding_ai_target_priority_bonus,
		"shielded_damage_modifier": shielded_damage_modifier,
		"stripped_shielded_damage_modifier": stripped_shielded_damage_modifier,
		"ordinary_shield_damage_modifier": ordinary_shield_damage_modifier,
		"stripped_ordinary_shield_damage_modifier": stripped_ordinary_shield_damage_modifier,
		"unshielded_damage_modifier": unshielded_damage_modifier,
		"stripped_unshielded_damage_modifier": stripped_unshielded_damage_modifier,
		"screen_ai_target_id": screen_ai_target_id,
		"stripped_screen_ai_target_id": stripped_screen_ai_target_id,
		"screen_preview": screen_preview,
		"ordinary_shield_preview": ordinary_shield_preview,
		"screen_snare_ok": screen_snare_ok,
		"reason": "" if ok else "harry did not uniquely apply its authored status and optional shield-screen pressure",
	}

func _probe_obituary(unit_id: String) -> Dictionary:
	var scribe := _stack_for_unit(unit_id, "player", 0)
	var defender := _defender_stack("enemy", 0)
	_set_hex(scribe, 4, 3)
	_set_hex(defender, 5, 3)
	var battle := _battle_for_stacks([scribe, defender])
	var preview := BattleRulesScript._active_ability_window_summary(scribe, battle, defender)
	var base_retaliation := BattleRulesScript._ability_damage_modifier(defender, scribe, battle, false, true, 0)
	var messages := BattleRulesScript._apply_attack_ability_effects(battle, scribe, defender, true, 1)
	var message_text := " ".join(messages).to_lower()
	var marked := BattleRulesScript._get_stack_by_id(battle, String(defender.get("battle_id", "")))
	var cohesion_pressure := SpellRulesScript.effect_bonus_for_kind(marked, battle, "cohesion")
	var retaliation_pressure := SpellRulesScript.effect_bonus_for_kind(marked, battle, "retaliation")
	var marked_retaliation := BattleRulesScript._ability_damage_modifier(marked, scribe, battle, false, true, 0)
	var second_defender := _defender_stack("enemy", 1)
	_set_hex(second_defender, 6, 3)
	battle["stacks"].append(second_defender)
	BattleRulesScript._apply_attack_ability_effects(battle, scribe, second_defender, true, 1)
	var second_marked := BattleRulesScript._get_stack_by_id(battle, String(second_defender.get("battle_id", "")))
	var spent_preview := BattleRulesScript._active_ability_window_summary(scribe, battle, second_defender)
	var braced_defender := _stack_for_unit("unit_thornwake_barkmantle_rams", "enemy", 0)
	var braced_scribe := _stack_for_unit(unit_id, "player", 0)
	_set_hex(braced_scribe, 4, 3)
	_set_hex(braced_defender, 5, 3)
	var braced_battle := _battle_for_stacks([braced_scribe, braced_defender])
	var braced_preview := BattleRulesScript._active_ability_window_summary(braced_scribe, braced_battle, braced_defender)
	BattleRulesScript._apply_attack_ability_effects(braced_battle, braced_scribe, braced_defender, true, 1)
	var braced_marked := BattleRulesScript._get_stack_by_id(braced_battle, String(braced_defender.get("battle_id", "")))
	var braced_cohesion_pressure := SpellRulesScript.effect_bonus_for_kind(braced_marked, braced_battle, "cohesion")
	var braced_retaliation_pressure := SpellRulesScript.effect_bonus_for_kind(braced_marked, braced_battle, "retaliation")
	var ai_scribe := _stack_for_unit(unit_id, "enemy", 0)
	var ai_ranged_target := _stack_for_unit("unit_thornwake_sporeglass_menders", "player", 0)
	var ai_braced_target := _stack_for_unit("unit_thornwake_thornwhip_carriers", "player", 1)
	var ai_tier_one_brace := _stack_for_unit("unit_river_guard", "player", 2)
	_set_hex(ai_scribe, 4, 3)
	_set_hex(ai_ranged_target, 6, 2)
	_set_hex(ai_braced_target, 6, 3)
	_set_hex(ai_tier_one_brace, 6, 4)
	var ai_battle := _battle_for_stacks([ai_scribe, ai_ranged_target, ai_braced_target])
	var ai_action := BattleAiRulesScript.choose_enemy_action(ai_battle, ai_scribe, {})
	var stripped_ai_scribe := _without_ability(ai_scribe, "obituary")
	var braced_score := BattleAiRulesScript._attack_score(ai_scribe, ai_braced_target, ai_battle, true)
	var ranged_score := BattleAiRulesScript._attack_score(ai_scribe, ai_ranged_target, ai_battle, true)
	var stripped_braced_score := BattleAiRulesScript._attack_score(stripped_ai_scribe, ai_braced_target, ai_battle, true)
	var braced_priority_delta := braced_score - stripped_braced_score
	var tier_one_battle := _battle_for_stacks([ai_scribe, ai_tier_one_brace])
	var tier_one_score := BattleAiRulesScript._attack_score(ai_scribe, ai_tier_one_brace, tier_one_battle, true)
	var stripped_tier_one_score := BattleAiRulesScript._attack_score(stripped_ai_scribe, ai_tier_one_brace, tier_one_battle, true)
	var tier_one_priority_delta := tier_one_score - stripped_tier_one_score

	var stripped := _without_ability(scribe, "obituary")
	var stripped_defender := _defender_stack("enemy", 0)
	_set_hex(stripped, 4, 3)
	_set_hex(stripped_defender, 5, 3)
	var stripped_battle := _battle_for_stacks([stripped, stripped_defender])
	BattleRulesScript._apply_attack_ability_effects(stripped_battle, stripped, stripped_defender, true, 1)
	var stripped_marked := BattleRulesScript._get_stack_by_id(stripped_battle, String(stripped_defender.get("battle_id", "")))

	battle["round"] = 4
	var expired_retaliation := BattleRulesScript._ability_damage_modifier(marked, scribe, battle, false, true, 0)
	var ok := (
		SpellRulesScript.has_effect_id(marked, {"round": 1}, "status_obituary_marked")
		and cohesion_pressure == -1
		and retaliation_pressure == -10
		and braced_cohesion_pressure == -2
		and braced_retaliation_pressure == -20
		and String(ai_action.get("action", "")) == "shoot"
		and String(ai_action.get("target_battle_id", "")) == String(ai_braced_target.get("battle_id", ""))
		and braced_score > ranged_score
		and is_equal_approx(braced_priority_delta, 4.0)
		and is_equal_approx(tier_one_priority_delta, 0.25)
		and marked_retaliation < base_retaliation
		and not SpellRulesScript.has_effect_id(second_marked, battle, "status_obituary_marked")
		and spent_preview.contains("already been issued")
		and is_equal_approx(expired_retaliation, base_retaliation)
		and not SpellRulesScript.has_effect_id(stripped_marked, stripped_battle, "status_obituary_marked")
		and preview.contains("Final Notice")
		and preview.contains("retaliation")
		and braced_preview.contains("prioritizes")
		and message_text.contains("obituary-marked")
		and message_text.contains("retaliation weakens")
	)
	return {
		"ok": ok,
		"probe": "obituary_cohesion_and_retaliation_pressure",
		"cohesion_pressure": cohesion_pressure,
		"retaliation_pressure_pct": retaliation_pressure,
		"braced_cohesion_pressure": braced_cohesion_pressure,
		"braced_retaliation_pressure_pct": braced_retaliation_pressure,
		"ai_selected_target_id": String(ai_action.get("target_battle_id", "")),
		"braced_target_score": braced_score,
		"ranged_target_score": ranged_score,
		"braced_priority_delta": braced_priority_delta,
		"tier_one_priority_delta": tier_one_priority_delta,
		"uses_after_second_attack": int(scribe.get("ability_uses", {}).get("obituary", 0)),
		"base_retaliation_modifier": base_retaliation,
		"marked_retaliation_modifier": marked_retaliation,
		"expired_retaliation_modifier": expired_retaliation,
		"preview": preview,
		"braced_preview": braced_preview,
		"spent_preview": spent_preview,
		"message_count": messages.size(),
		"reason": "" if ok else "obituary did not prioritize and apply bounded one-round pressure to a qualifying veteran brace",
	}

func _probe_backstab(unit_id: String) -> Dictionary:
	var attacker := _stack_for_unit(unit_id, "player", 0)
	var defender := _defender_stack()
	var backstab := _ability_by_id(attacker, "backstab")
	var primary_melee_only := bool(backstab.get("primary_melee_only", false))
	var status_id := _first_status_id(backstab)
	if status_id == "":
		return {"ok": false, "probe": "backstab_status_damage_modifier", "reason": "backstab has no status_ids"}
	_add_effect(defender, status_id)
	var battle := _battle_for_stacks([attacker, defender])
	var stripped := _without_ability(attacker, "backstab")
	var stripped_battle := _battle_for_stacks([stripped, defender.duplicate(true)])
	var modifier_with := BattleRulesScript._ability_damage_modifier(attacker, defender, battle, false, false, 0)
	var modifier_without := BattleRulesScript._ability_damage_modifier(stripped, defender, stripped_battle, false, false, 0)
	var ai_modifier_with := BattleAiRulesScript._ability_damage_modifier(attacker, defender, battle, false, false, 0)
	var clean_defender := _defender_stack()
	var clean_battle := _battle_for_stacks([attacker.duplicate(true), clean_defender])
	var clean_stripped := _without_ability(attacker, "backstab")
	var clean_stripped_defender := clean_defender.duplicate(true)
	var clean_stripped_battle := _battle_for_stacks([clean_stripped, clean_stripped_defender])
	var clean_modifier := BattleRulesScript._ability_damage_modifier(attacker, clean_defender, clean_battle, false, false, 0)
	var clean_modifier_without := BattleRulesScript._ability_damage_modifier(clean_stripped, clean_stripped_defender, clean_stripped_battle, false, false, 0)
	var ranged_modifier := BattleRulesScript._ability_damage_modifier(attacker, defender, battle, true, false, 1)
	var ranged_modifier_without := BattleRulesScript._ability_damage_modifier(stripped, defender, stripped_battle, true, false, 1)
	var retaliation_modifier := BattleRulesScript._ability_damage_modifier(attacker, defender, battle, false, true, 0)
	var retaliation_modifier_without := BattleRulesScript._ability_damage_modifier(stripped, defender, stripped_battle, false, true, 0)
	var role_contract_ok := not primary_melee_only or (
		is_equal_approx(ranged_modifier, ranged_modifier_without)
		and is_equal_approx(retaliation_modifier, retaliation_modifier_without)
	)
	var ok := (
		modifier_with > modifier_without
		and is_equal_approx(ai_modifier_with, modifier_with)
		and is_equal_approx(clean_modifier, clean_modifier_without)
		and role_contract_ok
	)
	return {
		"ok": ok,
		"probe": "backstab_primary_melee_status_damage_modifier",
		"status_id": status_id,
		"modifier_with": modifier_with,
		"modifier_without": modifier_without,
		"ai_modifier_with": ai_modifier_with,
		"clean_modifier": clean_modifier,
		"clean_modifier_without": clean_modifier_without,
		"primary_melee_only": primary_melee_only,
		"ranged_modifier": ranged_modifier,
		"ranged_modifier_without": ranged_modifier_without,
		"retaliation_modifier": retaliation_modifier,
		"retaliation_modifier_without": retaliation_modifier_without,
		"reason": "" if ok else "backstab did not preserve status, clean-target, AI, and authored primary-melee scope",
	}

func _probe_fogwake(unit_id: String) -> Dictionary:
	var attacker := _stack_for_unit(unit_id, "player", 0)
	var target := _defender_stack("enemy", 0)
	var distant_ally := _defender_stack("enemy", 1)
	_set_hex(attacker, 4, 3)
	_set_hex(target, 5, 3)
	_set_hex(distant_ally, 9, 3)
	var isolated_battle := _battle_for_stacks([attacker, target, distant_ally])
	var stripped := _without_ability(attacker, "fogwake")
	var stripped_target := target.duplicate(true)
	var stripped_battle := _battle_for_stacks([stripped, stripped_target, distant_ally.duplicate(true)])
	var isolated_live := BattleRulesScript._stack_is_hex_isolated(isolated_battle, target)
	var isolated_ai := BattleAiRulesScript._stack_is_hex_isolated(isolated_battle, target)
	var live_modifier := BattleRulesScript._ability_damage_modifier(attacker, target, isolated_battle, false, false, 0)
	var stripped_modifier := BattleRulesScript._ability_damage_modifier(stripped, stripped_target, stripped_battle, false, false, 0)
	var ai_damage := BattleAiRulesScript._estimate_damage(attacker, target, isolated_battle, false, false, 0)
	var stripped_ai_damage := BattleAiRulesScript._estimate_damage(stripped, stripped_target, stripped_battle, false, false, 0)
	var preview := BattleRulesScript._active_ability_window_summary(attacker, isolated_battle, target)
	var messages := BattleRulesScript._apply_attack_ability_effects(isolated_battle, attacker, target, false, 0)
	var fogwake := _ability_by_id(attacker, "fogwake")
	var status_id := String(fogwake.get("status_id", ""))
	var updated_target := BattleRulesScript._get_stack_by_id(isolated_battle, String(target.get("battle_id", "")))
	var status_applied := SpellRulesScript.has_effect_id(updated_target, isolated_battle, status_id)

	var supported_attacker := _stack_for_unit(unit_id, "player", 0)
	var supported_target := _defender_stack("enemy", 0)
	var adjacent_ally := _defender_stack("enemy", 1)
	_set_hex(supported_attacker, 4, 3)
	_set_hex(supported_target, 5, 3)
	_set_hex(adjacent_ally, 6, 3)
	var supported_battle := _battle_for_stacks([supported_attacker, supported_target, adjacent_ally])
	var supported_stripped := _without_ability(supported_attacker, "fogwake")
	var supported_stripped_target := supported_target.duplicate(true)
	var supported_stripped_battle := _battle_for_stacks([supported_stripped, supported_stripped_target, adjacent_ally.duplicate(true)])
	var supported_live := BattleRulesScript._stack_is_hex_isolated(supported_battle, supported_target)
	var supported_ai := BattleAiRulesScript._stack_is_hex_isolated(supported_battle, supported_target)
	var supported_modifier := BattleRulesScript._ability_damage_modifier(supported_attacker, supported_target, supported_battle, false, false, 0)
	var supported_stripped_modifier := BattleRulesScript._ability_damage_modifier(supported_stripped, supported_stripped_target, supported_stripped_battle, false, false, 0)
	var isolated_score := BattleAiRulesScript._attack_score(attacker, target, isolated_battle, false)
	var supported_score := BattleAiRulesScript._attack_score(supported_attacker, supported_target, supported_battle, false)
	var supported_messages := BattleRulesScript._apply_attack_ability_effects(supported_battle, supported_attacker, supported_target, false, 0)
	var supported_updated := BattleRulesScript._get_stack_by_id(supported_battle, String(supported_target.get("battle_id", "")))
	var supported_status := SpellRulesScript.has_effect_id(supported_updated, supported_battle, status_id)
	var priority_bonus := float(fogwake.get("ai_target_priority_bonus", 0.0))
	var ok := (
		isolated_live
		and isolated_ai
		and not supported_live
		and not supported_ai
		and live_modifier > stripped_modifier
		and ai_damage > stripped_ai_damage
		and is_equal_approx(supported_modifier, supported_stripped_modifier)
		and isolated_score - supported_score >= priority_bonus
		and status_applied
		and not supported_status
		and SpellRulesScript.effect_bonus_for_kind(updated_target, isolated_battle, "defense") == -1
		and SpellRulesScript.effect_bonus_for_kind(updated_target, isolated_battle, "initiative") == -1
		and SpellRulesScript.effect_bonus_for_kind(updated_target, isolated_battle, "cohesion") == -1
		and preview.contains(String(fogwake.get("name", "Fogwake")))
		and preview.contains("no adjacent allied stack")
		and not messages.is_empty()
		and supported_messages.is_empty()
	)
	return {
		"ok": ok,
		"probe": "fogwake_true_hex_isolation_damage_status_and_ai",
		"isolated_live": isolated_live,
		"isolated_ai": isolated_ai,
		"supported_live": supported_live,
		"supported_ai": supported_ai,
		"isolated_modifier": live_modifier,
		"stripped_modifier": stripped_modifier,
		"supported_modifier": supported_modifier,
		"supported_stripped_modifier": supported_stripped_modifier,
		"isolated_ai_damage": ai_damage,
		"stripped_ai_damage": stripped_ai_damage,
		"isolated_score": isolated_score,
		"supported_score": supported_score,
		"ai_target_priority_bonus": priority_bonus,
		"status_applied": status_applied,
		"supported_status_blocked": not supported_status,
		"preview": preview,
		"reason": "" if ok else "fogwake did not remain gated to true hex isolation across damage, status, AI, and player summary behavior",
	}

func _probe_counter_ambush_flare(unit_id: String) -> Dictionary:
	var backstab_attacker := _stack_for_unit("unit_blackbranch_cutthroat", "player", 0)
	var marked_target := _defender_stack("enemy", 0)
	var sapper := _stack_for_unit(unit_id, "enemy", 1)
	_add_effect(marked_target, "status_harried")
	var protected_battle := _battle_for_stacks([backstab_attacker, marked_target, sapper])
	var stripped_sapper := _without_ability(sapper, "counter_ambush_flare")
	var unprotected_attacker := backstab_attacker.duplicate(true)
	var unprotected_target := marked_target.duplicate(true)
	var unprotected_battle := _battle_for_stacks([unprotected_attacker, unprotected_target, stripped_sapper])
	var protected_backstab_modifier := BattleRulesScript._ability_damage_modifier(backstab_attacker, marked_target, protected_battle, false, false, 0)
	var protected_backstab_ai_modifier := BattleAiRulesScript._ability_damage_modifier(backstab_attacker, marked_target, protected_battle, false, false, 0)
	var unprotected_backstab_modifier := BattleRulesScript._ability_damage_modifier(unprotected_attacker, unprotected_target, unprotected_battle, false, false, 0)
	var unprotected_backstab_ai_modifier := BattleAiRulesScript._ability_damage_modifier(unprotected_attacker, unprotected_target, unprotected_battle, false, false, 0)
	var protected_backstab_score := BattleAiRulesScript._attack_score(backstab_attacker, marked_target, protected_battle, false)
	var unprotected_backstab_score := BattleAiRulesScript._attack_score(unprotected_attacker, unprotected_target, unprotected_battle, false)
	var backstab_messages := BattleRulesScript._apply_attack_ability_effects(protected_battle, backstab_attacker, marked_target, false, 0, marked_target)
	var revealed_backstab_attacker := BattleRulesScript._get_stack_by_id(protected_battle, String(backstab_attacker.get("battle_id", "")))
	var no_flare_messages := BattleRulesScript._apply_attack_ability_effects(unprotected_battle, unprotected_attacker, unprotected_target, false, 0, unprotected_target)

	var wounded_attacker := _stack_for_unit("unit_blackbranch_cutthroat", "player", 0)
	var wounded_target := _defender_stack("enemy", 0)
	var wounded_sapper := _stack_for_unit(unit_id, "enemy", 1)
	wounded_target["total_health"] = int(wounded_target.get("unit_hp", 1)) * 4
	var wounded_battle := _battle_for_stacks([wounded_attacker, wounded_target, wounded_sapper])
	var wounded_stripped_target := wounded_target.duplicate(true)
	var wounded_unprotected_battle := _battle_for_stacks([
		wounded_attacker.duplicate(true),
		wounded_stripped_target,
		_without_ability(wounded_sapper, "counter_ambush_flare"),
	])
	var protected_wounded_modifier := BattleRulesScript._ability_damage_modifier(wounded_attacker, wounded_target, wounded_battle, false, false, 0)
	var unprotected_wounded_modifier := BattleRulesScript._ability_damage_modifier(wounded_unprotected_battle["stacks"][0], wounded_stripped_target, wounded_unprotected_battle, false, false, 0)

	var dead_sapper := sapper.duplicate(true)
	dead_sapper["total_health"] = 0
	var dead_target := marked_target.duplicate(true)
	var dead_battle := _battle_for_stacks([backstab_attacker.duplicate(true), dead_target, dead_sapper])
	var dead_source_modifier := BattleRulesScript._ability_damage_modifier(dead_battle["stacks"][0], dead_target, dead_battle, false, false, 0)
	var second_sapper := _stack_for_unit(unit_id, "enemy", 2)
	var duplicate_target := marked_target.duplicate(true)
	var duplicate_battle := _battle_for_stacks([backstab_attacker.duplicate(true), duplicate_target, sapper.duplicate(true), second_sapper])
	var duplicate_source_modifier := BattleRulesScript._ability_damage_modifier(duplicate_battle["stacks"][0], duplicate_target, duplicate_battle, false, false, 0)

	var fogwake_attacker := _stack_for_unit("unit_veilmourn_fogbound_leviathan", "player", 0)
	var fogwake_target := _defender_stack("enemy", 0)
	var fogwake_sapper := _stack_for_unit(unit_id, "enemy", 1)
	_set_hex(fogwake_attacker, 4, 3)
	_set_hex(fogwake_target, 5, 3)
	_set_hex(fogwake_sapper, 9, 6)
	var fogwake_battle := _battle_for_stacks([fogwake_attacker, fogwake_target, fogwake_sapper])
	var no_fogwake_source := _without_ability(fogwake_sapper, "counter_ambush_flare")
	var unprotected_fogwake_attacker := fogwake_attacker.duplicate(true)
	var unprotected_fogwake_target := fogwake_target.duplicate(true)
	var unprotected_fogwake_battle := _battle_for_stacks([unprotected_fogwake_attacker, unprotected_fogwake_target, no_fogwake_source])
	var protected_fogwake_modifier := BattleRulesScript._ability_damage_modifier(fogwake_attacker, fogwake_target, fogwake_battle, false, false, 0)
	var protected_fogwake_ai_modifier := BattleAiRulesScript._ability_damage_modifier(fogwake_attacker, fogwake_target, fogwake_battle, false, false, 0)
	var unprotected_fogwake_modifier := BattleRulesScript._ability_damage_modifier(unprotected_fogwake_attacker, unprotected_fogwake_target, unprotected_fogwake_battle, false, false, 0)
	var unprotected_fogwake_ai_modifier := BattleAiRulesScript._ability_damage_modifier(unprotected_fogwake_attacker, unprotected_fogwake_target, unprotected_fogwake_battle, false, false, 0)
	var protected_fogwake_score := BattleAiRulesScript._attack_score(fogwake_attacker, fogwake_target, fogwake_battle, false)
	var unprotected_fogwake_score := BattleAiRulesScript._attack_score(unprotected_fogwake_attacker, unprotected_fogwake_target, unprotected_fogwake_battle, false)
	var fogwake_messages := BattleRulesScript._apply_attack_ability_effects(fogwake_battle, fogwake_attacker, fogwake_target, false, 0, fogwake_target)
	var fogwake_status_id := String(_ability_by_id(fogwake_attacker, "fogwake").get("status_id", "status_fogbound"))
	var protected_fogwake_target := BattleRulesScript._get_stack_by_id(fogwake_battle, String(fogwake_target.get("battle_id", "")))
	var revealed_fogwake_attacker := BattleRulesScript._get_stack_by_id(fogwake_battle, String(fogwake_attacker.get("battle_id", "")))
	var lethal_fogwake_attacker := fogwake_attacker.duplicate(true)
	var lethal_fogwake_target_before := fogwake_target.duplicate(true)
	var lethal_fogwake_target_after := fogwake_target.duplicate(true)
	lethal_fogwake_target_after["total_health"] = 0
	var lethal_fogwake_battle := _battle_for_stacks([lethal_fogwake_attacker, lethal_fogwake_target_after, fogwake_sapper.duplicate(true)])
	var lethal_fogwake_messages := BattleRulesScript._apply_attack_ability_effects(
		lethal_fogwake_battle,
		lethal_fogwake_attacker,
		lethal_fogwake_target_after,
		false,
		0,
		lethal_fogwake_target_before
	)
	var lethal_revealed_attacker := BattleRulesScript._get_stack_by_id(lethal_fogwake_battle, String(lethal_fogwake_attacker.get("battle_id", "")))

	var unrelated_attacker := _stack_for_unit("unit_embercourt_sluicefire_lindworms", "player", 0)
	var unrelated_target := _defender_stack("enemy", 0)
	unrelated_target["total_health"] = int(unrelated_target.get("unit_hp", 1)) * 4
	var unrelated_sapper := _stack_for_unit(unit_id, "enemy", 1)
	var unrelated_battle := _battle_for_stacks([unrelated_attacker, unrelated_target, unrelated_sapper])
	var unrelated_stripped_target := unrelated_target.duplicate(true)
	var unrelated_stripped_battle := _battle_for_stacks([
		unrelated_attacker.duplicate(true),
		unrelated_stripped_target,
		_without_ability(unrelated_sapper, "counter_ambush_flare"),
	])
	var unrelated_modifier := BattleRulesScript._ability_damage_modifier(unrelated_attacker, unrelated_target, unrelated_battle, false, false, 0)
	var unrelated_stripped_modifier := BattleRulesScript._ability_damage_modifier(unrelated_stripped_battle["stacks"][0], unrelated_stripped_target, unrelated_stripped_battle, false, false, 0)
	var direct_before := int(unrelated_target.get("total_health", 0))
	BattleRulesScript._apply_damage_to_stack(unrelated_battle, String(unrelated_target.get("battle_id", "")), 7)
	var direct_after := int(BattleRulesScript._get_stack_by_id(unrelated_battle, String(unrelated_target.get("battle_id", ""))).get("total_health", 0))

	var flare_event_count := 0
	for event in protected_battle.get("battle_presentation_events", []):
		if event is Dictionary and String(event.get("event_type", "")) == "ability" and String(event.get("action_id", "")) == "counter_ambush_flare":
			flare_event_count += 1
	for event in fogwake_battle.get("battle_presentation_events", []):
		if event is Dictionary and String(event.get("event_type", "")) == "debuff" and String(event.get("action_id", "")) == "counter_ambush_flare":
			flare_event_count += 1
	var flare := _ability_by_id(sapper, "counter_ambush_flare")
	var role_line := BattleRulesScript._ability_role_sentence(sapper, flare, protected_battle, backstab_attacker)
	var window_line := BattleRulesScript._active_ability_window_summary(sapper, protected_battle, backstab_attacker)
	var denied_backstab_window := BattleRulesScript._active_ability_window_summary(backstab_attacker, protected_battle, marked_target)
	var denied_fogwake_window := BattleRulesScript._active_ability_window_summary(fogwake_attacker, fogwake_battle, fogwake_target)
	var live_context := BattleRulesScript._counter_ambush_flare_context(protected_battle, marked_target, "backstab")
	var ai_context := BattleAiRulesScript._counter_ambush_flare_context(protected_battle, marked_target, "backstab")
	var ok: bool = (
		is_equal_approx(protected_backstab_modifier, 1.0)
		and is_equal_approx(protected_backstab_ai_modifier, protected_backstab_modifier)
		and unprotected_backstab_modifier > protected_backstab_modifier
		and is_equal_approx(unprotected_backstab_ai_modifier, unprotected_backstab_modifier)
		and unprotected_backstab_score > protected_backstab_score
		and is_equal_approx(protected_wounded_modifier, 1.0)
		and unprotected_wounded_modifier > protected_wounded_modifier
		and is_equal_approx(dead_source_modifier, unprotected_backstab_modifier)
		and is_equal_approx(duplicate_source_modifier, protected_backstab_modifier)
		and is_equal_approx(protected_fogwake_modifier, 1.0)
		and is_equal_approx(protected_fogwake_ai_modifier, protected_fogwake_modifier)
		and unprotected_fogwake_modifier > protected_fogwake_modifier
		and is_equal_approx(unprotected_fogwake_ai_modifier, unprotected_fogwake_modifier)
		and unprotected_fogwake_score > protected_fogwake_score
		and not SpellRulesScript.has_effect_id(protected_fogwake_target, fogwake_battle, fogwake_status_id)
		and not SpellRulesScript.has_effect_id(revealed_backstab_attacker, protected_battle, "status_flare_revealed")
		and SpellRulesScript.has_effect_id(revealed_fogwake_attacker, fogwake_battle, "status_flare_revealed")
		and SpellRulesScript.effect_bonus_for_kind(revealed_fogwake_attacker, fogwake_battle, "defense") == -1
		and SpellRulesScript.effect_bonus_for_kind(revealed_fogwake_attacker, fogwake_battle, "initiative") == -1
		and lethal_fogwake_messages.size() == 1
		and SpellRulesScript.has_effect_id(lethal_revealed_attacker, lethal_fogwake_battle, "status_flare_revealed")
		and is_equal_approx(unrelated_modifier, unrelated_stripped_modifier)
		and direct_before - direct_after == 7
		and backstab_messages.size() == 1
		and no_flare_messages.is_empty()
		and fogwake_messages.size() == 1
		and flare_event_count == 2
		and not live_context.is_empty()
		and not ai_context.is_empty()
		and String(live_context.get("source", {}).get("battle_id", "")) == String(sapper.get("battle_id", ""))
		and String(ai_context.get("source", {}).get("battle_id", "")) == String(sapper.get("battle_id", ""))
		and role_line.contains("removes bonus damage")
		and role_line.contains("prevents Fogbound")
		and role_line.contains("flare-reveals")
		and window_line.contains("exposing backstab and fogwake")
		and denied_backstab_window.contains("ambush bonus is removed")
		and denied_fogwake_window.contains("Fogbound are blocked")
	)
	return {
		"ok": ok,
		"probe": "counter_ambush_flare_backstab_fogwake_source_scope_ai_and_events",
		"protected_backstab_modifier": protected_backstab_modifier,
		"unprotected_backstab_modifier": unprotected_backstab_modifier,
		"protected_backstab_ai_modifier": protected_backstab_ai_modifier,
		"unprotected_backstab_ai_modifier": unprotected_backstab_ai_modifier,
		"protected_backstab_score": protected_backstab_score,
		"unprotected_backstab_score": unprotected_backstab_score,
		"protected_wounded_modifier": protected_wounded_modifier,
		"unprotected_wounded_modifier": unprotected_wounded_modifier,
		"dead_source_modifier": dead_source_modifier,
		"duplicate_source_modifier": duplicate_source_modifier,
		"protected_fogwake_modifier": protected_fogwake_modifier,
		"unprotected_fogwake_modifier": unprotected_fogwake_modifier,
		"protected_fogwake_ai_modifier": protected_fogwake_ai_modifier,
		"unprotected_fogwake_ai_modifier": unprotected_fogwake_ai_modifier,
		"lethal_fogwake_message_count": lethal_fogwake_messages.size(),
		"lethal_fogwake_revealed": SpellRulesScript.has_effect_id(lethal_revealed_attacker, lethal_fogwake_battle, "status_flare_revealed"),
		"protected_fogwake_score": protected_fogwake_score,
		"unprotected_fogwake_score": unprotected_fogwake_score,
		"fogbound_blocked": not SpellRulesScript.has_effect_id(protected_fogwake_target, fogwake_battle, fogwake_status_id),
		"backstab_attacker_revealed": SpellRulesScript.has_effect_id(revealed_backstab_attacker, protected_battle, "status_flare_revealed"),
		"fogwake_attacker_revealed": SpellRulesScript.has_effect_id(revealed_fogwake_attacker, fogwake_battle, "status_flare_revealed"),
		"revealed_defense_modifier": SpellRulesScript.effect_bonus_for_kind(revealed_fogwake_attacker, fogwake_battle, "defense"),
		"revealed_initiative_modifier": SpellRulesScript.effect_bonus_for_kind(revealed_fogwake_attacker, fogwake_battle, "initiative"),
		"unrelated_modifier": unrelated_modifier,
		"unrelated_stripped_modifier": unrelated_stripped_modifier,
		"direct_health_loss": direct_before - direct_after,
		"flare_event_count": flare_event_count,
		"role_line": role_line,
		"window_line": window_line,
		"denied_backstab_window": denied_backstab_window,
		"denied_fogwake_window": denied_fogwake_window,
		"reason": "" if ok else "counter-ambush flare did not preserve its exact bonus-only backstab/fogwake denial, source scope, AI parity, events, or exclusions",
	}

func _probe_resonance_relay(unit_id: String) -> Dictionary:
	var relay := _stack_for_unit(unit_id, "player", 2)
	var attacker := _stack_for_unit("unit_sunvault_shard_wardens", "player", 0)
	var calibrated_ally := _stack_for_unit("unit_sunvault_prism_adepts", "player", 1)
	var defender := _defender_stack("enemy", 0)
	_set_hex(relay, 3, 3)
	_set_hex(attacker, 4, 3)
	_set_hex(calibrated_ally, 5, 3)
	_set_hex(defender, 6, 3)
	_add_positive_effect(attacker, "relay_probe_attack")
	_add_positive_effect(calibrated_ally, "relay_probe_initiative", "initiative")
	var relay_battle := _battle_for_stacks([attacker, calibrated_ally, relay, defender], [], "plains", 3)
	var relay_modifier := BattleRulesScript._faction_damage_modifier(attacker, defender, relay_battle, false, 0)
	var relay_ai_modifier := BattleAiRulesScript._faction_damage_modifier(attacker, defender, relay_battle, false, 0)
	var relay_initiative := BattleRulesScript._faction_initiative_bonus(attacker, relay_battle)
	var relay_linked_initiative := BattleRulesScript._faction_initiative_bonus(calibrated_ally, relay_battle)
	var relay_summary := BattleRulesScript._side_doctrine_summary(relay_battle, "player")

	var no_relay := _without_ability(relay, "resonance_relay")
	var no_relay_attacker := attacker.duplicate(true)
	var no_relay_ally := calibrated_ally.duplicate(true)
	var no_relay_defender := defender.duplicate(true)
	var no_relay_battle := _battle_for_stacks([no_relay_attacker, no_relay_ally, no_relay, no_relay_defender], [], "plains", 3)
	var no_relay_modifier := BattleRulesScript._faction_damage_modifier(no_relay_attacker, no_relay_defender, no_relay_battle, false, 0)
	var no_relay_ai_modifier := BattleAiRulesScript._faction_damage_modifier(no_relay_attacker, no_relay_defender, no_relay_battle, false, 0)
	var no_relay_initiative := BattleRulesScript._faction_initiative_bonus(no_relay_attacker, no_relay_battle)
	var no_relay_linked_initiative := BattleRulesScript._faction_initiative_bonus(no_relay_ally, no_relay_battle)
	var no_relay_summary := BattleRulesScript._side_doctrine_summary(no_relay_battle, "player")

	var dead_relay := relay.duplicate(true)
	dead_relay["total_health"] = 0
	var dead_attacker := attacker.duplicate(true)
	var dead_ally := calibrated_ally.duplicate(true)
	var dead_defender := defender.duplicate(true)
	var dead_relay_battle := _battle_for_stacks([dead_attacker, dead_ally, dead_relay, dead_defender], [], "plains", 3)
	var dead_relay_modifier := BattleRulesScript._faction_damage_modifier(dead_attacker, dead_defender, dead_relay_battle, false, 0)
	var dead_relay_ai_modifier := BattleAiRulesScript._faction_damage_modifier(dead_attacker, dead_defender, dead_relay_battle, false, 0)
	var dead_relay_initiative := BattleRulesScript._faction_initiative_bonus(dead_attacker, dead_relay_battle)
	var dead_relay_linked_initiative := BattleRulesScript._faction_initiative_bonus(dead_ally, dead_relay_battle)

	var single_attacker := attacker.duplicate(true)
	var uncalibrated_ally := calibrated_ally.duplicate(true)
	uncalibrated_ally["effects"] = []
	var single_defender := defender.duplicate(true)
	var single_battle := _battle_for_stacks([single_attacker, uncalibrated_ally, no_relay.duplicate(true), single_defender], [], "plains", 3)
	var single_modifier := BattleRulesScript._faction_damage_modifier(single_attacker, single_defender, single_battle, false, 0)
	var single_initiative := BattleRulesScript._faction_initiative_bonus(single_attacker, single_battle)
	var ok := (
		relay_modifier > no_relay_modifier
		and relay_ai_modifier > no_relay_ai_modifier
		and is_equal_approx(relay_modifier, relay_ai_modifier)
		and is_equal_approx(no_relay_modifier, no_relay_ai_modifier)
		and is_equal_approx(no_relay_modifier, dead_relay_modifier)
		and is_equal_approx(no_relay_ai_modifier, dead_relay_ai_modifier)
		and is_equal_approx(no_relay_modifier, single_modifier)
		and no_relay_modifier > 1.0
		and relay_initiative > no_relay_initiative
		and relay_linked_initiative == relay_initiative + 1
		and no_relay_initiative == dead_relay_initiative
		and no_relay_linked_initiative == dead_relay_linked_initiative
		and relay_linked_initiative > no_relay_linked_initiative
		and no_relay_initiative == single_initiative
		and relay_summary.contains("syncing the line")
		and no_relay_summary.contains("waiting for a living relay")
	)
	return {
		"ok": ok,
		"probe": "resonance_relay_living_line_activation_and_personal_fallback",
		"relay_modifier": relay_modifier,
		"no_relay_modifier": no_relay_modifier,
		"dead_relay_modifier": dead_relay_modifier,
		"single_calibration_modifier": single_modifier,
		"relay_ai_modifier": relay_ai_modifier,
		"no_relay_ai_modifier": no_relay_ai_modifier,
		"dead_relay_ai_modifier": dead_relay_ai_modifier,
		"relay_initiative": relay_initiative,
		"relay_linked_initiative": relay_linked_initiative,
		"no_relay_initiative": no_relay_initiative,
		"no_relay_linked_initiative": no_relay_linked_initiative,
		"dead_relay_initiative": dead_relay_initiative,
		"dead_relay_linked_initiative": dead_relay_linked_initiative,
		"single_calibration_initiative": single_initiative,
		"relay_summary": relay_summary,
		"no_relay_summary": no_relay_summary,
		"reason": "" if ok else "resonance relay did not gate line damage/initiative while preserving personal calibration after relay absence or defeat",
	}

func _probe_solar_array_lane(unit_id: String) -> Dictionary:
	var source := _stack_for_unit(unit_id, "player", 0)
	var linked := _stack_for_unit("unit_sunvault_daybreak_colossus", "player", 1)
	var ranged_ally := _stack_for_unit("unit_sunvault_resonant_choristers", "player", 2)
	var melee_ally := _stack_for_unit("unit_sunvault_shard_wardens", "player", 3)
	var outsider_ranged := _stack_for_unit("unit_ember_archer", "player", 4)
	var melee_attacker := _defender_stack("enemy", 0)
	var ranged_attacker := _stack_for_unit("unit_ember_archer", "enemy", 1)
	ranged_attacker["abilities"] = []
	ranged_attacker["effects"] = []
	var battle := _battle_for_stacks([
		source,
		linked,
		ranged_ally,
		melee_ally,
		outsider_ranged,
		melee_attacker,
		ranged_attacker,
	])
	var primary_modifier := BattleRulesScript._ability_damage_modifier(melee_attacker, ranged_ally, battle, false, false, 0)
	var retaliation_modifier := BattleRulesScript._ability_damage_modifier(melee_attacker, ranged_ally, battle, false, true, 0)
	var ai_primary_modifier := BattleAiRulesScript._ability_damage_modifier(melee_attacker, ranged_ally, battle, false, false, 0)
	var ai_retaliation_modifier := BattleAiRulesScript._ability_damage_modifier(melee_attacker, ranged_ally, battle, false, true, 0)
	var ranged_attack_modifier := BattleRulesScript._ability_damage_modifier(ranged_attacker, ranged_ally, battle, true, false, 2)
	var melee_ally_modifier := BattleRulesScript._ability_damage_modifier(melee_attacker, melee_ally, battle, false, false, 0)
	var outsider_modifier := BattleRulesScript._ability_damage_modifier(melee_attacker, outsider_ranged, battle, false, false, 0)

	var dead_source := source.duplicate(true)
	dead_source["total_health"] = 0
	var dead_source_ally := ranged_ally.duplicate(true)
	var dead_source_battle := _battle_for_stacks([
		dead_source,
		linked.duplicate(true),
		dead_source_ally,
		melee_attacker.duplicate(true),
	])
	var dead_source_modifier := BattleRulesScript._ability_damage_modifier(
		dead_source_battle["stacks"][3],
		dead_source_ally,
		dead_source_battle,
		false,
		false,
		0
	)

	var dead_linked := linked.duplicate(true)
	dead_linked["total_health"] = 0
	var dead_linked_source := source.duplicate(true)
	var dead_linked_ally := ranged_ally.duplicate(true)
	var dead_linked_battle := _battle_for_stacks([
		dead_linked_source,
		dead_linked,
		dead_linked_ally,
		melee_attacker.duplicate(true),
	])
	var dead_linked_modifier := BattleRulesScript._ability_damage_modifier(
		dead_linked_battle["stacks"][3],
		dead_linked_ally,
		dead_linked_battle,
		false,
		false,
		0
	)

	var stripped_source := _without_ability(source, "solar_array_lane")
	var stripped_ally := ranged_ally.duplicate(true)
	var stripped_battle := _battle_for_stacks([
		stripped_source,
		linked.duplicate(true),
		stripped_ally,
		melee_attacker.duplicate(true),
	])
	var stripped_modifier := BattleRulesScript._ability_damage_modifier(
		stripped_battle["stacks"][3],
		stripped_ally,
		stripped_battle,
		false,
		false,
		0
	)

	var direct_health_before := int(ranged_ally.get("total_health", 0))
	BattleRulesScript._apply_damage_to_stack(battle, String(ranged_ally.get("battle_id", "")), 11)
	var direct_health_after := int(BattleRulesScript._get_stack_by_id(
		battle,
		String(ranged_ally.get("battle_id", ""))
	).get("total_health", 0))
	var ability := _ability_by_id(source, "solar_array_lane")
	var role_line := BattleRulesScript._ability_role_sentence(source, ability, battle, ranged_ally)
	var active_window := BattleRulesScript._active_ability_window_summary(source, battle, melee_attacker)
	var waiting_window := BattleRulesScript._active_ability_window_summary(dead_linked_source, dead_linked_battle, dead_linked_battle["stacks"][3])
	var ok: bool = (
		is_equal_approx(primary_modifier, 0.95)
		and is_equal_approx(retaliation_modifier, 0.95)
		and is_equal_approx(ai_primary_modifier, 0.95)
		and is_equal_approx(ai_retaliation_modifier, 0.95)
		and is_equal_approx(ranged_attack_modifier, 1.0)
		and is_equal_approx(melee_ally_modifier, 1.0)
		and is_equal_approx(outsider_modifier, 1.0)
		and is_equal_approx(dead_source_modifier, 1.0)
		and is_equal_approx(dead_linked_modifier, 1.0)
		and is_equal_approx(stripped_modifier, 1.0)
		and direct_health_after == direct_health_before - 11
		and float(ability.get("incoming_melee_damage_multiplier", 0.0)) == 0.95
		and ability.get("linked_unit_ids", []) == ["unit_sunvault_daybreak_colossus"]
		and role_line.contains("5%")
		and role_line.contains("Daybreak Colossus")
		and active_window.contains("screening")
		and waiting_window.contains("waiting")
	)
	return {
		"ok": ok,
		"probe": "solar_array_lane_linked_melee_screen_scope_and_ai",
		"primary_modifier": primary_modifier,
		"retaliation_modifier": retaliation_modifier,
		"ai_primary_modifier": ai_primary_modifier,
		"ai_retaliation_modifier": ai_retaliation_modifier,
		"ranged_attack_modifier": ranged_attack_modifier,
		"melee_ally_modifier": melee_ally_modifier,
		"outsider_modifier": outsider_modifier,
		"dead_source_modifier": dead_source_modifier,
		"dead_linked_modifier": dead_linked_modifier,
		"stripped_modifier": stripped_modifier,
		"direct_health_loss": direct_health_before - direct_health_after,
		"role_line": role_line,
		"active_window": active_window,
		"waiting_window": waiting_window,
		"reason": "" if ok else "Solar Array Lanes did not preserve its linked, melee-only, Sunvault-ranged runtime and AI contract",
	}

func _probe_shielding(unit_id: String) -> Dictionary:
	var defender := _stack_for_unit(unit_id, "player", 0)
	var attacker := _defender_stack("enemy", 0)
	var battle := _battle_for_stacks([defender, attacker])
	var stripped_defender := _without_ability(defender, "shielding")
	var stripped_battle := _battle_for_stacks([stripped_defender, attacker.duplicate(true)])
	var modifier_with := BattleRulesScript._ability_damage_modifier(attacker, defender, battle, true, false, 2)
	var modifier_without := BattleRulesScript._ability_damage_modifier(attacker, stripped_defender, stripped_battle, true, false, 2)
	var harried_damage_multiplier := float(_ability_by_id(defender, "shielding").get("harried_damage_multiplier", 1.0))
	var harried_payoff_ok := true
	var harried_modifier_with := 1.0
	var harried_modifier_without := 1.0
	var clean_modifier_with := 1.0
	var clean_modifier_without := 1.0
	var harried_ai_modifier := 1.0
	var harried_role_line := ""
	if harried_damage_multiplier > 1.0:
		var payoff_attacker := _stack_for_unit(unit_id, "player", 0)
		var payoff_target := _defender_stack("enemy", 0)
		var payoff_status_ids: Array = _ability_by_id(payoff_attacker, "shielding").get("payoff_status_ids", ["status_harried"])
		var payoff_status_id := String(payoff_status_ids[0]) if not payoff_status_ids.is_empty() else "status_harried"
		_add_effect(payoff_target, payoff_status_id)
		var payoff_battle := _battle_for_stacks([payoff_attacker, payoff_target])
		var stripped_payoff_attacker := _without_ability(payoff_attacker, "shielding")
		var stripped_payoff_target := payoff_target.duplicate(true)
		var stripped_payoff_battle := _battle_for_stacks([stripped_payoff_attacker, stripped_payoff_target])
		harried_modifier_with = BattleRulesScript._ability_damage_modifier(payoff_attacker, payoff_target, payoff_battle, false, false, 0)
		harried_modifier_without = BattleRulesScript._ability_damage_modifier(stripped_payoff_attacker, stripped_payoff_target, stripped_payoff_battle, false, false, 0)
		harried_ai_modifier = BattleAiRulesScript._ability_damage_modifier(payoff_attacker, payoff_target, payoff_battle, false, false, 0)
		var clean_attacker := _stack_for_unit(unit_id, "player", 0)
		var clean_target := _defender_stack("enemy", 0)
		var clean_battle := _battle_for_stacks([clean_attacker, clean_target])
		var stripped_clean_attacker := _without_ability(clean_attacker, "shielding")
		var stripped_clean_battle := _battle_for_stacks([stripped_clean_attacker, clean_target.duplicate(true)])
		clean_modifier_with = BattleRulesScript._ability_damage_modifier(clean_attacker, clean_target, clean_battle, false, false, 0)
		clean_modifier_without = BattleRulesScript._ability_damage_modifier(stripped_clean_attacker, clean_target, stripped_clean_battle, false, false, 0)
		harried_role_line = BattleRulesScript._active_ability_role_line(payoff_attacker, payoff_battle, payoff_target)
		harried_payoff_ok = (
			is_equal_approx(harried_modifier_with, clean_modifier_with * harried_damage_multiplier)
			and is_equal_approx(harried_modifier_without, clean_modifier_without)
			and is_equal_approx(harried_ai_modifier, harried_modifier_with)
			and (unit_id != "unit_mireclaw_bogplate_maulers" or is_equal_approx(clean_modifier_with, clean_modifier_without))
			and (unit_id != "unit_mireclaw_bogplate_maulers" or harried_role_line.contains("marked targets"))
		)
	var cohesion_hold_bonus := int(_ability_by_id(defender, "shielding").get("cohesion_hold_bonus", 0))
	var cohesion_contract_ok := unit_id != "unit_thornwake_barkmantle_rams" or cohesion_hold_bonus == 0
	var ally_screen_reduction_pct := int(_ability_by_id(defender, "shielding").get("ally_ranged_melee_damage_reduction_pct", 0))
	var linebreaker_bonus_pct := int(_ability_by_id(defender, "shielding").get("linebreaker_screen_bonus_pct", 0))
	var authored_shielding := _ability_by_id(ContentService.get_unit(unit_id), "shielding")
	var committed_screen_reduction_pct := int(authored_shielding.get("committed_assault_screen_reduction_pct", 0))
	var total_linebreaker_screen_pct := ally_screen_reduction_pct + linebreaker_bonus_pct
	var ally_modifier_with := 1.0
	var ally_modifier_without := 1.0
	var ally_modifier_with_second_screen := 1.0
	var ai_damage_with := 0
	var ai_damage_without := 0
	var committed_modifier_with := 1.0
	var committed_modifier_without := 1.0
	var committed_modifier_with_second_screen := 1.0
	var committed_dead_source_modifier := 1.0
	var committed_melee_ally_modifier := 1.0
	var committed_melee_ally_modifier_without := 1.0
	var committed_ranged_modifier := 1.0
	var committed_ranged_modifier_without := 1.0
	var committed_ai_damage_with := 0
	var committed_ai_damage_without := 0
	var committed_role_line := ""
	var return_ratio := float(_ability_by_id(defender, "shielding").get("ranged_damage_return_ratio", 0.0))
	var return_contract_ok := true
	var reflected_damage := 0
	var lethal_return_blocked := true
	var excluded_scope_ok := true
	var lethal_shooter_killed := true
	var ai_score_with_return := 0.0
	var ai_score_without_return := 0.0
	var action_summary := ""
	var role_line := ""
	var reflected_hit_event_visible := true
	var linked_screen_contract := _probe_linked_ranged_screen(unit_id)
	if total_linebreaker_screen_pct > 0:
		var ally := _stack_for_unit("unit_brasshollow_boiler_rivetcasters", "player", 1)
		var second_screen := _stack_for_unit(unit_id, "player", 2)
		var melee_attacker := _stack_for_unit("unit_thornwake_stagknot_runners", "enemy", 0)
		battle = _battle_for_stacks([defender, ally, melee_attacker])
		stripped_battle = _battle_for_stacks([stripped_defender, ally.duplicate(true), melee_attacker.duplicate(true)])
		var stacked_battle := _battle_for_stacks([defender.duplicate(true), second_screen, ally.duplicate(true), melee_attacker.duplicate(true)])
		ally_modifier_with = BattleRulesScript._ability_damage_modifier(melee_attacker, ally, battle, false, false, 0)
		ally_modifier_without = BattleRulesScript._ability_damage_modifier(melee_attacker, ally, stripped_battle, false, false, 0)
		ally_modifier_with_second_screen = BattleRulesScript._ability_damage_modifier(melee_attacker, ally, stacked_battle, false, false, 0)
		ai_damage_with = BattleAiRulesScript._estimate_damage(melee_attacker, ally, battle, false, false, 0)
		ai_damage_without = BattleAiRulesScript._estimate_damage(melee_attacker, ally, stripped_battle, false, false, 0)
	var ally_screen_ok := (
		total_linebreaker_screen_pct <= 0
		or (
			ally_modifier_with < ally_modifier_without
			and is_equal_approx(ally_modifier_with, ally_modifier_with_second_screen)
			and ai_damage_with < ai_damage_without
		)
	)
	if committed_screen_reduction_pct > 0:
		var committed_ally := _stack_for_unit("unit_sunvault_prism_adepts", "player", 1)
		var committed_second_source := _stack_for_unit(unit_id, "player", 2)
		var committed_attacker := _stack_for_unit("unit_embercourt_sluicefire_lindworms", "enemy", 0)
		var committed_battle := _battle_for_stacks([defender, committed_ally, committed_attacker])
		var committed_stripped_battle := _battle_for_stacks([stripped_defender, committed_ally.duplicate(true), committed_attacker.duplicate(true)])
		var committed_stacked_battle := _battle_for_stacks([defender.duplicate(true), committed_second_source, committed_ally.duplicate(true), committed_attacker.duplicate(true)])
		committed_modifier_with = BattleRulesScript._ability_damage_modifier(committed_attacker, committed_ally, committed_battle, false, false, 0)
		committed_modifier_without = BattleRulesScript._ability_damage_modifier(committed_attacker, committed_ally, committed_stripped_battle, false, false, 0)
		committed_modifier_with_second_screen = BattleRulesScript._ability_damage_modifier(committed_attacker, committed_ally, committed_stacked_battle, false, false, 0)
		committed_ai_damage_with = BattleAiRulesScript._estimate_damage(committed_attacker, committed_ally, committed_battle, false, false, 0)
		committed_ai_damage_without = BattleAiRulesScript._estimate_damage(committed_attacker, committed_ally, committed_stripped_battle, false, false, 0)
		var committed_dead_source := defender.duplicate(true)
		committed_dead_source["total_health"] = 0
		var committed_dead_ally := _stack_for_unit("unit_sunvault_prism_adepts", "player", 1)
		var committed_dead_attacker := _stack_for_unit("unit_embercourt_sluicefire_lindworms", "enemy", 0)
		var committed_dead_battle := _battle_for_stacks([committed_dead_source, committed_dead_ally, committed_dead_attacker])
		committed_dead_source_modifier = BattleRulesScript._ability_damage_modifier(committed_dead_attacker, committed_dead_ally, committed_dead_battle, false, false, 0)
		var committed_melee_ally := _stack_for_unit("unit_sunvault_solar_array_striders", "player", 1)
		var committed_melee_control := committed_melee_ally.duplicate(true)
		var committed_melee_attacker := _stack_for_unit("unit_embercourt_sluicefire_lindworms", "enemy", 0)
		var committed_melee_battle := _battle_for_stacks([defender.duplicate(true), committed_melee_ally, committed_melee_attacker])
		var committed_melee_control_battle := _battle_for_stacks([stripped_defender.duplicate(true), committed_melee_control, committed_melee_attacker.duplicate(true)])
		committed_melee_ally_modifier = BattleRulesScript._ability_damage_modifier(committed_melee_attacker, committed_melee_ally, committed_melee_battle, false, false, 0)
		committed_melee_ally_modifier_without = BattleRulesScript._ability_damage_modifier(committed_melee_attacker, committed_melee_control, committed_melee_control_battle, false, false, 0)
		var committed_ranged_attacker := _stack_for_unit("unit_embercourt_sluicefire_lindworms", "enemy", 0)
		var committed_ranged_control := committed_ranged_attacker.duplicate(true)
		committed_ranged_modifier = BattleRulesScript._ability_damage_modifier(committed_ranged_attacker, committed_ally, committed_battle, true, false, 2)
		committed_ranged_modifier_without = BattleRulesScript._ability_damage_modifier(committed_ranged_control, committed_ally, committed_stripped_battle, true, false, 2)
		committed_role_line = BattleRulesScript._active_ability_role_line(defender, committed_battle, committed_attacker)
	var committed_screen_ok := (
		committed_screen_reduction_pct <= 0
		or (
			is_equal_approx(committed_modifier_with, committed_modifier_without * (1.0 - (float(committed_screen_reduction_pct) / 100.0)))
			and is_equal_approx(committed_modifier_with, committed_modifier_with_second_screen)
			and is_equal_approx(committed_dead_source_modifier, committed_modifier_without)
			and is_equal_approx(committed_melee_ally_modifier, committed_melee_ally_modifier_without)
			and is_equal_approx(committed_ranged_modifier, committed_ranged_modifier_without)
			and committed_ai_damage_with < committed_ai_damage_without
			and committed_role_line.contains("%d%%" % committed_screen_reduction_pct)
			and committed_role_line.contains("committed assaults")
		)
	)
	if return_ratio > 0.0:
		var return_defender := _stack_for_unit(unit_id, "player", 0)
		var return_attacker := _stack_for_unit("unit_embercourt_bargebow_crews", "enemy", 0)
		_set_hex(return_defender, 6, 3)
		_set_hex(return_attacker, 2, 3)
		var return_battle := _battle_for_stacks([return_defender, return_attacker])
		var return_defender_before := return_defender.duplicate(true)
		var attacker_health_before := int(return_attacker.get("total_health", 0))
		BattleRulesScript._apply_damage_to_stack(return_battle, String(return_defender.get("battle_id", "")), 20)
		var return_messages := BattleRulesScript._apply_ranged_damage_return(
			return_battle,
			String(return_attacker.get("battle_id", "")),
			return_defender_before,
			true,
			"attack"
		)
		var return_attacker_after := BattleRulesScript._get_stack_by_id(return_battle, String(return_attacker.get("battle_id", "")))
		reflected_damage = attacker_health_before - int(return_attacker_after.get("total_health", 0))
		reflected_hit_event_visible = false
		for animation_event in BattleRulesScript.animation_event_queue(return_battle):
			if (
				animation_event is Dictionary
				and String(animation_event.get("battle_id", "")) == String(return_attacker.get("battle_id", ""))
				and String(animation_event.get("event_id", "")) == "battle_unit_hit"
			):
				reflected_hit_event_visible = true
				break

		var lethal_defender := _stack_for_unit(unit_id, "player", 0)
		var lethal_attacker := _stack_for_unit("unit_embercourt_bargebow_crews", "enemy", 0)
		var lethal_battle := _battle_for_stacks([lethal_defender, lethal_attacker])
		var lethal_before := lethal_defender.duplicate(true)
		var lethal_attacker_health := int(lethal_attacker.get("total_health", 0))
		BattleRulesScript._apply_damage_to_stack(lethal_battle, String(lethal_defender.get("battle_id", "")), int(lethal_defender.get("total_health", 0)))
		var lethal_messages := BattleRulesScript._apply_ranged_damage_return(
			lethal_battle,
			String(lethal_attacker.get("battle_id", "")),
			lethal_before,
			true,
			"attack"
		)
		var lethal_attacker_after := BattleRulesScript._get_stack_by_id(lethal_battle, String(lethal_attacker.get("battle_id", "")))
		lethal_return_blocked = lethal_messages.is_empty() and int(lethal_attacker_after.get("total_health", 0)) == lethal_attacker_health

		for excluded_case in [
			{"is_ranged": false, "source_type": "attack"},
			{"is_ranged": true, "source_type": "spell"},
			{"is_ranged": true, "source_type": "direct"},
			{"is_ranged": true, "source_type": "retaliation"},
		]:
			var excluded_defender := _stack_for_unit(unit_id, "player", 0)
			var excluded_attacker := _stack_for_unit("unit_embercourt_bargebow_crews", "enemy", 0)
			var excluded_battle := _battle_for_stacks([excluded_defender, excluded_attacker])
			var excluded_before := excluded_defender.duplicate(true)
			var excluded_attacker_health := int(excluded_attacker.get("total_health", 0))
			BattleRulesScript._apply_damage_to_stack(excluded_battle, String(excluded_defender.get("battle_id", "")), 20)
			var excluded_messages := BattleRulesScript._apply_ranged_damage_return(
				excluded_battle,
				String(excluded_attacker.get("battle_id", "")),
				excluded_before,
				bool(excluded_case.get("is_ranged", false)),
				String(excluded_case.get("source_type", ""))
			)
			var excluded_attacker_after := BattleRulesScript._get_stack_by_id(excluded_battle, String(excluded_attacker.get("battle_id", "")))
			excluded_scope_ok = excluded_scope_ok and excluded_messages.is_empty() and int(excluded_attacker_after.get("total_health", 0)) == excluded_attacker_health

		var fragile_defender := _stack_for_unit(unit_id, "player", 0)
		var fragile_attacker := _stack_for_unit("unit_embercourt_bargebow_crews", "enemy", 0)
		fragile_attacker["total_health"] = 1
		var fragile_battle := _battle_for_stacks([fragile_defender, fragile_attacker])
		var fragile_before := fragile_defender.duplicate(true)
		BattleRulesScript._apply_damage_to_stack(fragile_battle, String(fragile_defender.get("battle_id", "")), 20)
		BattleRulesScript._apply_ranged_damage_return(fragile_battle, String(fragile_attacker.get("battle_id", "")), fragile_before, true, "attack")
		var fragile_attacker_after := BattleRulesScript._get_stack_by_id(fragile_battle, String(fragile_attacker.get("battle_id", "")))
		lethal_shooter_killed = int(fragile_attacker_after.get("total_health", 0)) == 0

		var ai_return_defender := _stack_for_unit(unit_id, "player", 0)
		ai_return_defender["total_health"] = int(ai_return_defender.get("total_health", 0)) * 2
		var no_return_defender := ai_return_defender.duplicate(true)
		var no_return_abilities: Array = no_return_defender.get("abilities", []).duplicate(true)
		for ability_index in range(no_return_abilities.size()):
			var no_return_ability = no_return_abilities[ability_index]
			if no_return_ability is Dictionary and String(no_return_ability.get("id", "")) == "shielding":
				no_return_ability = no_return_ability.duplicate(true)
				no_return_ability["ranged_damage_return_ratio"] = 0.0
				no_return_abilities[ability_index] = no_return_ability
		no_return_defender["abilities"] = no_return_abilities
		var ai_return_attacker := _stack_for_unit("unit_embercourt_bargebow_crews", "enemy", 0)
		var ai_return_battle := _battle_for_stacks([ai_return_defender, ai_return_attacker])
		var ai_no_return_attacker := _stack_for_unit("unit_embercourt_bargebow_crews", "enemy", 0)
		var ai_no_return_battle := _battle_for_stacks([no_return_defender, ai_no_return_attacker])
		ai_score_with_return = BattleAiRulesScript._attack_score(ai_return_attacker, ai_return_defender, ai_return_battle, true)
		ai_score_without_return = BattleAiRulesScript._attack_score(ai_no_return_attacker, no_return_defender, ai_no_return_battle, true)
		action_summary = BattleRulesScript._attack_action_summary(return_attacker, return_defender, return_battle, true)
		role_line = BattleRulesScript._active_ability_role_line(return_defender, return_battle, return_attacker)
		return_contract_ok = (
			is_equal_approx(return_ratio, 0.1)
			and reflected_damage == 2
			and not return_messages.is_empty()
			and reflected_hit_event_visible
			and lethal_return_blocked
			and excluded_scope_ok
			and lethal_shooter_killed
			and ai_score_with_return < ai_score_without_return
			and action_summary.contains("Facet Reprisal")
			and action_summary.contains("10%")
			and role_line.contains("2%")
			and role_line.contains("10%")
		)
	var ok := (
		modifier_with < modifier_without
		and harried_payoff_ok
		and ally_screen_ok
		and committed_screen_ok
		and cohesion_contract_ok
		and return_contract_ok
		and bool(linked_screen_contract.get("ok", false))
	)
	return {
		"ok": ok,
		"probe": "shielding_self_and_allied_engine_damage_reduction",
		"modifier_with": modifier_with,
		"modifier_without": modifier_without,
		"harried_damage_multiplier": harried_damage_multiplier,
		"harried_payoff_ok": harried_payoff_ok,
		"harried_modifier_with": harried_modifier_with,
		"harried_modifier_without": harried_modifier_without,
		"harried_ai_modifier": harried_ai_modifier,
		"clean_modifier_with": clean_modifier_with,
		"clean_modifier_without": clean_modifier_without,
		"harried_role_line": harried_role_line,
		"cohesion_hold_bonus": cohesion_hold_bonus,
		"cohesion_contract_ok": cohesion_contract_ok,
		"ally_screen_reduction_pct": ally_screen_reduction_pct,
		"linebreaker_bonus_pct": linebreaker_bonus_pct,
		"committed_screen_reduction_pct": committed_screen_reduction_pct,
		"total_linebreaker_screen_pct": total_linebreaker_screen_pct,
		"ally_modifier_with": ally_modifier_with,
		"ally_modifier_without": ally_modifier_without,
		"ally_modifier_with_second_screen": ally_modifier_with_second_screen,
		"ai_damage_with": ai_damage_with,
		"ai_damage_without": ai_damage_without,
		"committed_modifier_with": committed_modifier_with,
		"committed_modifier_without": committed_modifier_without,
		"committed_modifier_with_second_screen": committed_modifier_with_second_screen,
		"committed_dead_source_modifier": committed_dead_source_modifier,
		"committed_melee_ally_modifier": committed_melee_ally_modifier,
		"committed_melee_ally_modifier_without": committed_melee_ally_modifier_without,
		"committed_ranged_modifier": committed_ranged_modifier,
		"committed_ranged_modifier_without": committed_ranged_modifier_without,
		"committed_ai_damage_with": committed_ai_damage_with,
		"committed_ai_damage_without": committed_ai_damage_without,
		"committed_role_line": committed_role_line,
		"committed_screen_ok": committed_screen_ok,
		"linked_ranged_screen": linked_screen_contract,
		"ranged_damage_return_ratio": return_ratio,
		"reflected_damage": reflected_damage,
		"reflected_hit_event_visible": reflected_hit_event_visible,
		"lethal_return_blocked": lethal_return_blocked,
		"excluded_scope_ok": excluded_scope_ok,
		"lethal_shooter_killed": lethal_shooter_killed,
		"ai_score_with_return": ai_score_with_return,
		"ai_score_without_return": ai_score_without_return,
		"action_summary": action_summary,
		"role_line": role_line,
		"return_contract_ok": return_contract_ok,
		"reason": "" if ok else "shielding did not preserve its authored damage screen and bounded cohesion contract",
	}

func _probe_linked_ranged_screen(unit_id: String) -> Dictionary:
	var source := _stack_for_unit(unit_id, "player", 0)
	var authored_shielding := _ability_by_id(ContentService.get_unit(unit_id), "shielding")
	var reduction_pct := int(authored_shielding.get("linked_ranged_damage_reduction_pct", 0))
	if reduction_pct <= 0:
		return {"ok": true, "reduction_pct": 0, "skipped": true}
	var linked_unit_ids: Array = authored_shielding.get("linked_ranged_unit_ids", [])
	var linked_unit_id := String(linked_unit_ids[0]) if not linked_unit_ids.is_empty() else ""
	var linked_ally := _stack_for_unit(linked_unit_id, "player", 1)
	var ranged_attacker := _stack_for_unit("unit_embercourt_bargebow_crews", "enemy", 0)
	var battle := _battle_for_stacks([source, linked_ally, ranged_attacker])
	var stripped_source := _without_ability(source, "shielding")
	var stripped_linked := linked_ally.duplicate(true)
	var stripped_attacker := ranged_attacker.duplicate(true)
	var stripped_battle := _battle_for_stacks([stripped_source, stripped_linked, stripped_attacker])
	var modifier_with := BattleRulesScript._ability_damage_modifier(ranged_attacker, linked_ally, battle, true, false, 2)
	var modifier_without := BattleRulesScript._ability_damage_modifier(stripped_attacker, stripped_linked, stripped_battle, true, false, 2)
	var ai_modifier_with := BattleAiRulesScript._ability_damage_modifier(ranged_attacker, linked_ally, battle, true, false, 2)
	var ai_modifier_without := BattleAiRulesScript._ability_damage_modifier(stripped_attacker, stripped_linked, stripped_battle, true, false, 2)

	var second_source := _stack_for_unit(unit_id, "player", 2)
	var stacked_ally := _stack_for_unit(linked_unit_id, "player", 1)
	var stacked_attacker := _stack_for_unit("unit_embercourt_bargebow_crews", "enemy", 0)
	var stacked_battle := _battle_for_stacks([source.duplicate(true), second_source, stacked_ally, stacked_attacker])
	var stacked_modifier := BattleRulesScript._ability_damage_modifier(stacked_attacker, stacked_ally, stacked_battle, true, false, 2)

	var dead_source := source.duplicate(true)
	dead_source["total_health"] = 0
	var dead_ally := _stack_for_unit(linked_unit_id, "player", 1)
	var dead_attacker := _stack_for_unit("unit_embercourt_bargebow_crews", "enemy", 0)
	var dead_battle := _battle_for_stacks([dead_source, dead_ally, dead_attacker])
	var dead_source_modifier := BattleRulesScript._ability_damage_modifier(dead_attacker, dead_ally, dead_battle, true, false, 2)

	var unlinked_ally := _stack_for_unit("unit_sunvault_daybreak_colossus", "player", 1)
	var unlinked_control := unlinked_ally.duplicate(true)
	var unlinked_attacker := _stack_for_unit("unit_embercourt_bargebow_crews", "enemy", 0)
	var unlinked_battle := _battle_for_stacks([source.duplicate(true), unlinked_ally, unlinked_attacker])
	var unlinked_control_battle := _battle_for_stacks([stripped_source.duplicate(true), unlinked_control, unlinked_attacker.duplicate(true)])
	var unlinked_modifier := BattleRulesScript._ability_damage_modifier(unlinked_attacker, unlinked_ally, unlinked_battle, true, false, 2)
	var unlinked_control_modifier := BattleRulesScript._ability_damage_modifier(unlinked_attacker, unlinked_control, unlinked_control_battle, true, false, 2)

	var melee_ally := _stack_for_unit(linked_unit_id, "player", 1)
	var melee_control := melee_ally.duplicate(true)
	var melee_attacker := _stack_for_unit("unit_thornwake_stagknot_runners", "enemy", 0)
	var melee_battle := _battle_for_stacks([source.duplicate(true), melee_ally, melee_attacker])
	var melee_control_battle := _battle_for_stacks([stripped_source.duplicate(true), melee_control, melee_attacker.duplicate(true)])
	var melee_modifier := BattleRulesScript._ability_damage_modifier(melee_attacker, melee_ally, melee_battle, false, false, 0)
	var melee_control_modifier := BattleRulesScript._ability_damage_modifier(melee_attacker, melee_control, melee_control_battle, false, false, 0)
	var role_line := BattleRulesScript._active_ability_role_line(source, battle, ranged_attacker)
	var ok := (
		linked_unit_id != ""
		and is_equal_approx(modifier_with, modifier_without * (1.0 - (float(reduction_pct) / 100.0)))
		and is_equal_approx(ai_modifier_with, modifier_with)
		and is_equal_approx(ai_modifier_without, modifier_without)
		and is_equal_approx(stacked_modifier, modifier_with)
		and is_equal_approx(dead_source_modifier, modifier_without)
		and is_equal_approx(unlinked_modifier, unlinked_control_modifier)
		and is_equal_approx(melee_modifier, melee_control_modifier)
		and role_line.contains("%d%%" % reduction_pct)
		and role_line.contains("linked ranged arrays")
	)
	return {
		"ok": ok,
		"reduction_pct": reduction_pct,
		"linked_unit_ids": linked_unit_ids,
		"modifier_with": modifier_with,
		"modifier_without": modifier_without,
		"ai_modifier_with": ai_modifier_with,
		"ai_modifier_without": ai_modifier_without,
		"stacked_modifier": stacked_modifier,
		"dead_source_modifier": dead_source_modifier,
		"unlinked_modifier": unlinked_modifier,
		"unlinked_control_modifier": unlinked_control_modifier,
		"melee_modifier": melee_modifier,
		"melee_control_modifier": melee_control_modifier,
		"role_line": role_line,
		"reason": "" if ok else "linked ranged screen did not preserve its authored living-source, linked-target, ranged-only, and nonstacking contract",
	}

func _probe_volley(unit_id: String) -> Dictionary:
	var attacker := _stack_for_unit(unit_id, "player", 0)
	var defender := _defender_stack()
	var volley := _ability_by_id(attacker, "volley")
	var requires_protected_lane := bool(volley.get("requires_protected_lane", false))
	var min_distance: int = max(1, int(volley.get("min_distance", 1)))
	var battle := _battle_for_stacks([attacker, defender])
	var stripped := _without_ability(attacker, "volley")
	var stripped_battle := _battle_for_stacks([stripped, defender.duplicate(true)])
	var modifier_with := BattleRulesScript._ability_damage_modifier(attacker, defender, battle, true, false, min_distance)
	var modifier_without := BattleRulesScript._ability_damage_modifier(stripped, defender, stripped_battle, true, false, min_distance)
	var ai_modifier_with := BattleAiRulesScript._ability_damage_modifier(attacker, defender, battle, true, false, min_distance)
	var ai_modifier_without := BattleAiRulesScript._ability_damage_modifier(stripped, defender, stripped_battle, true, false, min_distance)
	var status_defender := _defender_stack()
	_add_effect(status_defender, "status_staggered")
	var status_attacker := attacker.duplicate(true)
	var status_battle := _battle_for_stacks([status_attacker, status_defender])
	var status_modifier := BattleRulesScript._ability_damage_modifier(status_attacker, status_defender, status_battle, true, false, min_distance)
	var status_ai_modifier := BattleAiRulesScript._ability_damage_modifier(status_attacker, status_defender, status_battle, true, false, min_distance)
	var defending_ally := _defender_stack("player", 1)
	defending_ally["defending"] = true
	var held_attacker := attacker.duplicate(true)
	var held_defender := _defender_stack()
	_set_hex(held_attacker, 4, 3)
	_set_hex(defending_ally, 3, 3)
	_set_hex(held_defender, 7, 3)
	var held_battle := _battle_for_stacks([held_attacker, defending_ally, held_defender])
	var held_modifier := BattleRulesScript._ability_damage_modifier(held_attacker, held_defender, held_battle, true, false, min_distance)
	var held_ai_modifier := BattleAiRulesScript._ability_damage_modifier(held_attacker, held_defender, held_battle, true, false, min_distance)
	var objective_attacker := attacker.duplicate(true)
	var objective_defender := defender.duplicate(true)
	var objective_battle := _battle_for_stacks([objective_attacker, objective_defender])
	var protected_objective_types: Array = volley.get("protected_lane_objective_types", []) if volley.get("protected_lane_objective_types", []) is Array else []
	if not protected_objective_types.is_empty():
		objective_battle["field_objectives"] = [{"type": String(protected_objective_types[0]), "control_side": "player"}]
	var objective_modifier := BattleRulesScript._ability_damage_modifier(objective_attacker, objective_defender, objective_battle, true, false, min_distance)
	var objective_ai_modifier := BattleAiRulesScript._ability_damage_modifier(objective_attacker, objective_defender, objective_battle, true, false, min_distance)
	var below_distance_modifier := BattleRulesScript._ability_damage_modifier(attacker, defender, battle, true, false, max(0, min_distance - 1))
	var melee_modifier := BattleRulesScript._ability_damage_modifier(attacker, defender, battle, false, false, 0)
	var melee_control_modifier := BattleRulesScript._ability_damage_modifier(stripped, defender, stripped_battle, false, false, 0)
	var marked_role := BattleRulesScript._ability_role_sentence(status_attacker, volley, status_battle, status_defender)
	var exact_refraction_contract_ok: bool = unit_id != "unit_sunvault_prism_adepts" or (
		is_equal_approx(float(volley.get("damage_multiplier", 1.0)), 1.12)
		and volley.get("status_ids", []) == ["status_staggered"]
		and is_equal_approx(float(volley.get("status_damage_multiplier", 1.0)), 1.12)
		and is_equal_approx(float(volley.get("ally_defending_multiplier", 1.0)), 1.05)
		and is_equal_approx(status_modifier, modifier_with * 1.12)
		and is_equal_approx(held_modifier, modifier_with * 1.05)
		and marked_role.contains("marked targets")
	)
	var protected_lane_contract_ok := (
		modifier_with > modifier_without
		if not requires_protected_lane
		else (
			is_equal_approx(modifier_with, modifier_without)
			and held_modifier > modifier_with
			and not protected_objective_types.is_empty()
			and objective_modifier > modifier_with
			and is_equal_approx(objective_ai_modifier, objective_modifier)
		)
	)
	var ok: bool = (
		bool(attacker.get("ranged", false))
		and protected_lane_contract_ok
		and is_equal_approx(ai_modifier_with, modifier_with)
		and is_equal_approx(ai_modifier_without, modifier_without)
		and is_equal_approx(status_ai_modifier, status_modifier)
		and is_equal_approx(held_ai_modifier, held_modifier)
		and is_equal_approx(below_distance_modifier, modifier_without)
		and is_equal_approx(melee_modifier, melee_control_modifier)
		and exact_refraction_contract_ok
	)
	return {
		"ok": ok,
		"probe": "volley_range_damage_modifier",
		"min_distance": min_distance,
		"modifier_with": modifier_with,
		"modifier_without": modifier_without,
		"ai_modifier_with": ai_modifier_with,
		"ai_modifier_without": ai_modifier_without,
		"status_modifier": status_modifier,
		"status_ai_modifier": status_ai_modifier,
		"held_modifier": held_modifier,
		"held_ai_modifier": held_ai_modifier,
		"requires_protected_lane": requires_protected_lane,
		"protected_lane_objective_types": protected_objective_types,
		"objective_modifier": objective_modifier,
		"objective_ai_modifier": objective_ai_modifier,
		"below_distance_modifier": below_distance_modifier,
		"melee_modifier": melee_modifier,
		"melee_control_modifier": melee_control_modifier,
		"marked_role": marked_role,
		"exact_refraction_contract_ok": exact_refraction_contract_ok,
		"reason": "" if ok else "volley did not preserve its range, setup, held-line, melee-exclusion, and tactical-AI contract",
	}

func _probe_formation_guard(unit_id: String) -> Dictionary:
	var attacker := _stack_for_unit(unit_id, "player", 0)
	var stripped := _without_ability(attacker, "formation_guard")
	var defend_with := _defend_cohesion_delta(attacker, "formation_guard")
	var defend_without := _defend_cohesion_delta(stripped, "formation_guard_stripped")
	var ok := defend_with > defend_without
	return {
		"ok": ok,
		"probe": "formation_guard_defend_pressure",
		"defend_cohesion_delta_with": defend_with,
		"defend_cohesion_delta_without": defend_without,
		"reason": "" if ok else "formation_guard did not increase defend cohesion",
	}

func _probe_bloodrush(unit_id: String) -> Dictionary:
	var attacker := _stack_for_unit(unit_id, "player", 0)
	var defender := _wounded_defender_for_ability(attacker, "bloodrush")
	var battle := _battle_for_stacks([attacker, defender])
	var stripped := _without_ability(attacker, "bloodrush")
	var stripped_battle := _battle_for_stacks([stripped, defender.duplicate(true)])
	var modifier_with := BattleRulesScript._ability_damage_modifier(attacker, defender, battle, false, false, 0)
	var modifier_without := BattleRulesScript._ability_damage_modifier(stripped, defender, stripped_battle, false, false, 0)
	var clean_defender := _defender_stack()
	var clean_battle := _battle_for_stacks([attacker.duplicate(true), clean_defender])
	var clean_attacker := BattleRulesScript._get_stack_by_id(clean_battle, String(attacker.get("battle_id", "")))
	var clean_target := BattleRulesScript._get_stack_by_id(clean_battle, String(clean_defender.get("battle_id", "")))
	var clean_modifier := BattleRulesScript._ability_damage_modifier(clean_attacker, clean_target, clean_battle, false, false, 0)
	var clean_retaliation_modifier := BattleRulesScript._ability_damage_modifier(clean_attacker, clean_target, clean_battle, false, true, 0)
	var clean_ai_modifier := BattleAiRulesScript._ability_damage_modifier(clean_attacker, clean_target, clean_battle, false, false, 0)
	var clean_role := BattleRulesScript._ability_role_sentence(clean_attacker, _ability_by_id(clean_attacker, "bloodrush"), clean_battle, clean_target)
	var disrupted_defender := _defender_stack()
	_add_effect(disrupted_defender, "status_staggered")
	var disrupted_battle := _battle_for_stacks([attacker.duplicate(true), disrupted_defender])
	var disrupted_attacker := BattleRulesScript._get_stack_by_id(disrupted_battle, String(attacker.get("battle_id", "")))
	var disrupted_target := BattleRulesScript._get_stack_by_id(disrupted_battle, String(disrupted_defender.get("battle_id", "")))
	var disrupted_modifier := BattleRulesScript._ability_damage_modifier(disrupted_attacker, disrupted_target, disrupted_battle, false, false, 0)
	var disrupted_ai_modifier := BattleAiRulesScript._ability_damage_modifier(disrupted_attacker, disrupted_target, disrupted_battle, false, false, 0)
	var disrupted_role := BattleRulesScript._ability_role_sentence(disrupted_attacker, _ability_by_id(disrupted_attacker, "bloodrush"), disrupted_battle, disrupted_target)
	var prepared_breach_contract_ok := unit_id != "unit_embercourt_sluicefire_lindworms" or (
		clean_modifier < 1.0
		and is_equal_approx(clean_retaliation_modifier, 1.0)
		and disrupted_modifier > clean_modifier
		and is_equal_approx(clean_ai_modifier, clean_modifier)
		and is_equal_approx(disrupted_ai_modifier, disrupted_modifier)
		and clean_role.contains("15%")
		and disrupted_role.contains("now")
	)
	var ok := modifier_with > modifier_without and prepared_breach_contract_ok
	return {
		"ok": ok,
		"probe": "bloodrush_prepared_breach_damage_modifier",
		"target_health_ratio": BattleRulesScript._health_ratio(defender),
		"modifier_with": modifier_with,
		"modifier_without": modifier_without,
		"clean_modifier": clean_modifier,
		"clean_retaliation_modifier": clean_retaliation_modifier,
		"clean_ai_modifier": clean_ai_modifier,
		"clean_role": clean_role,
		"disrupted_modifier": disrupted_modifier,
		"disrupted_ai_modifier": disrupted_ai_modifier,
		"disrupted_role": disrupted_role,
		"prepared_breach_contract_ok": prepared_breach_contract_ok,
		"reason": "" if ok else "bloodrush did not preserve its wounded payoff and bounded prepared-breach contract",
	}

func _probe_overheat(unit_id: String) -> Dictionary:
	var attacker := _stack_for_unit(unit_id, "player", 0)
	var defender := _defender_stack()
	var battle := _battle_for_stacks([attacker, defender], [], "plains", 3)
	var defense_before := BattleRulesScript._stack_defense_total(attacker, battle)
	var initiative_before := BattleRulesScript._stack_initiative_total(attacker, battle)
	var fresh_modifier := BattleRulesScript._ability_damage_modifier(attacker, defender, battle, false, false, 0)
	var retaliation_before := BattleRulesScript._ability_damage_modifier(attacker, defender, battle, false, true, 0)
	var messages := BattleRulesScript._apply_attack_ability_effects(battle, attacker, defender, false, 0)
	var updated := BattleRulesScript._get_stack_by_id(battle, String(attacker.get("battle_id", "")))
	var overheated := SpellRulesScript.has_effect_id(updated, battle, "status_overheated")
	var active_modifier := BattleRulesScript._ability_damage_modifier(updated, defender, battle, false, false, 0)
	var active_retaliation := BattleRulesScript._ability_damage_modifier(updated, defender, battle, false, true, 0)
	var defense_active := BattleRulesScript._stack_defense_total(updated, battle)
	var initiative_active := BattleRulesScript._stack_initiative_total(updated, battle)
	var active_defend_score := BattleAiRulesScript._defend_score(battle, updated, [defender])
	var effect_count: int = updated.get("effects", []).size()
	var expires_after_round := int(updated.get("effects", [])[0].get("expires_after_round", 0)) if effect_count > 0 else 0
	battle["round"] = 4
	BattleRulesScript._apply_attack_ability_effects(battle, updated, defender, false, 0)
	updated = BattleRulesScript._get_stack_by_id(battle, String(attacker.get("battle_id", "")))
	var did_not_refresh: bool = updated.get("effects", []).size() == effect_count
	if effect_count > 0:
		did_not_refresh = did_not_refresh and int(updated.get("effects", [])[0].get("expires_after_round", 0)) == expires_after_round
	battle["round"] = 5
	SpellRulesScript.purge_expired_stack_effects(updated, 5)
	var recovered := not SpellRulesScript.has_effect_id(updated, battle, "status_overheated")
	var recovered_modifier := BattleRulesScript._ability_damage_modifier(updated, defender, battle, false, false, 0)
	var recovered_defend_score := BattleAiRulesScript._defend_score(battle, updated, [defender])
	var ok: bool = (
		fresh_modifier > 1.0
		and is_equal_approx(retaliation_before, 1.0)
		and overheated
		and active_modifier < 1.0
		and active_retaliation < retaliation_before
		and defense_active == defense_before - 2
		and initiative_active == initiative_before - 2
		and active_defend_score > recovered_defend_score
		and did_not_refresh
		and recovered
		and is_equal_approx(recovered_modifier, fresh_modifier)
		and not messages.is_empty()
	)
	return {
		"ok": ok,
		"probe": "overheat_burst_self_debuff_expiry_and_ai",
		"fresh_modifier": fresh_modifier,
		"active_modifier": active_modifier,
		"retaliation_before": retaliation_before,
		"active_retaliation": active_retaliation,
		"defense_before": defense_before,
		"defense_active": defense_active,
		"initiative_before": initiative_before,
		"initiative_active": initiative_active,
		"active_defend_score": active_defend_score,
		"recovered_defend_score": recovered_defend_score,
		"did_not_refresh": did_not_refresh,
		"recovered_modifier": recovered_modifier,
		"message_count": messages.size(),
		"reason": "" if ok else "overheat did not prove its complete burst, cooldown, expiry, and AI contract",
	}

func _probe_pressure_artillery(unit_id: String) -> Dictionary:
	var attacker := _stack_for_unit(unit_id, "player", 0)
	var primary := _defender_stack("enemy", 0)
	var selected_secondary := _stack_for_unit("unit_mireclaw_ferrychain_lashers", "enemy", 1)
	var tied_secondary := _stack_for_unit("unit_thornwake_thornwhip_carriers", "enemy", 2)
	var distant_secondary := _stack_for_unit("unit_veilmourn_bellwake_oars", "enemy", 3)
	var allied_bystander := _stack_for_unit("unit_brasshollow_scrip_haulers", "player", 1)
	_set_hex(attacker, 2, 3)
	_set_hex(primary, 6, 3)
	_set_hex(selected_secondary, 6, 4)
	_set_hex(tied_secondary, 5, 3)
	_set_hex(distant_secondary, 9, 6)
	_set_hex(allied_bystander, 6, 2)
	selected_secondary["total_health"] = 40
	tied_secondary["total_health"] = 40
	var battle := _battle_for_stacks([attacker, primary, selected_secondary, tied_secondary, distant_secondary, allied_bystander], [], "plains", 3)
	var ability := _ability_by_id(attacker, "pressure_artillery")
	var expected_damage := mini(
		int(ability.get("max_secondary_damage", 0)),
		BattleRulesScript._alive_count(attacker) * int(ability.get("secondary_damage_per_unit", 0))
	)
	var selected_id := String(selected_secondary.get("battle_id", ""))
	var tied_id := String(tied_secondary.get("battle_id", ""))
	var distant_id := String(distant_secondary.get("battle_id", ""))
	var ally_id := String(allied_bystander.get("battle_id", ""))
	var selected_before := int(selected_secondary.get("total_health", 0))
	var tied_before := int(tied_secondary.get("total_health", 0))
	var distant_before := int(distant_secondary.get("total_health", 0))
	var ally_before := int(allied_bystander.get("total_health", 0))
	var ai_secondary := BattleAiRulesScript._pressure_artillery_secondary_target(battle, attacker, primary)
	var ai_secondary_damage := BattleAiRulesScript._pressure_artillery_secondary_damage(attacker)
	var cluster_score := BattleAiRulesScript._attack_score(attacker, primary, battle, true)
	var messages := BattleRulesScript._apply_attack_ability_effects(battle, attacker, primary, true, 1)
	var updated_attacker := BattleRulesScript._get_stack_by_id(battle, String(attacker.get("battle_id", "")))
	var selected_after := BattleRulesScript._get_stack_by_id(battle, selected_id)
	var tied_after := BattleRulesScript._get_stack_by_id(battle, tied_id)
	var distant_after := BattleRulesScript._get_stack_by_id(battle, distant_id)
	var ally_after := BattleRulesScript._get_stack_by_id(battle, ally_id)
	var selected_after_health := int(selected_after.get("total_health", 0))
	var tied_after_health := int(tied_after.get("total_health", 0))
	var distant_after_health := int(distant_after.get("total_health", 0))
	var ally_after_health := int(ally_after.get("total_health", 0))
	var overheated := SpellRulesScript.has_effect_id(updated_attacker, battle, "status_overheated")
	var initiative_before := BattleRulesScript._stack_initiative_total(attacker, _battle_for_stacks([attacker.duplicate(true), primary.duplicate(true)], [], "plains", 3))
	var initiative_after := BattleRulesScript._stack_initiative_total(updated_attacker, battle)
	var heat_initiative_modifier := SpellRulesScript.effect_bonus_for_kind(updated_attacker, battle, "initiative")
	var effect_count: int = updated_attacker.get("effects", []).size()
	var expires_after_round := int(updated_attacker.get("effects", [])[0].get("expires_after_round", 0)) if effect_count > 0 else 0
	battle["round"] = 4
	BattleRulesScript._apply_attack_ability_effects(battle, updated_attacker, primary, true, 1)
	updated_attacker = BattleRulesScript._get_stack_by_id(battle, String(attacker.get("battle_id", "")))
	var did_not_refresh: bool = (
		updated_attacker.get("effects", []).size() == effect_count
		and effect_count > 0
		and int(updated_attacker.get("effects", [])[0].get("expires_after_round", 0)) == expires_after_round
	)
	battle["round"] = 5
	SpellRulesScript.purge_expired_stack_effects(updated_attacker, 5)
	var recovered := not SpellRulesScript.has_effect_id(updated_attacker, battle, "status_overheated")

	var event_found := false
	var heat_event_found := false
	for event in battle.get("battle_presentation_events", []):
		if event is Dictionary \
				and String(event.get("event_type", "")) == "ability" \
				and String(event.get("action_id", "")) == "pressure_artillery" \
				and String(event.get("target_battle_id", "")) == selected_id \
				and int(event.get("damage", 0)) == expected_damage:
			event_found = true
		if event is Dictionary \
				and String(event.get("event_type", "")) == "debuff" \
				and String(event.get("action_id", "")) == "pressure_artillery_heat" \
				and String(event.get("target_battle_id", "")) == String(attacker.get("battle_id", "")) \
				and String(event.get("visible_text", "")).to_lower().contains("overheated"):
			heat_event_found = true

	var no_cluster_attacker := _stack_for_unit(unit_id, "player", 0)
	var no_cluster_primary := _defender_stack("enemy", 0)
	_set_hex(no_cluster_attacker, 2, 3)
	_set_hex(no_cluster_primary, 6, 3)
	var no_cluster_battle := _battle_for_stacks([no_cluster_attacker, no_cluster_primary], [], "plains", 3)
	var no_cluster_primary_before := int(no_cluster_primary.get("total_health", 0))
	var no_cluster_score := BattleAiRulesScript._attack_score(no_cluster_attacker, no_cluster_primary, no_cluster_battle, true)
	var no_cluster_messages := BattleRulesScript._apply_attack_ability_effects(no_cluster_battle, no_cluster_attacker, no_cluster_primary, true, 1)
	var no_cluster_updated := BattleRulesScript._get_stack_by_id(no_cluster_battle, String(no_cluster_attacker.get("battle_id", "")))
	var no_cluster_primary_after := BattleRulesScript._get_stack_by_id(no_cluster_battle, String(no_cluster_primary.get("battle_id", "")))

	var stripped_attacker := _without_ability(_stack_for_unit(unit_id, "player", 0), "pressure_artillery")
	var stripped_primary := _defender_stack("enemy", 0)
	var stripped_secondary := _stack_for_unit("unit_mireclaw_ferrychain_lashers", "enemy", 1)
	_set_hex(stripped_attacker, 2, 3)
	_set_hex(stripped_primary, 6, 3)
	_set_hex(stripped_secondary, 6, 4)
	var stripped_battle := _battle_for_stacks([stripped_attacker, stripped_primary, stripped_secondary], [], "plains", 3)
	var stripped_secondary_before := int(stripped_secondary.get("total_health", 0))
	BattleRulesScript._apply_attack_ability_effects(stripped_battle, stripped_attacker, stripped_primary, true, 1)
	var stripped_updated := BattleRulesScript._get_stack_by_id(stripped_battle, String(stripped_attacker.get("battle_id", "")))
	var stripped_secondary_after := BattleRulesScript._get_stack_by_id(stripped_battle, String(stripped_secondary.get("battle_id", "")))

	var melee_attacker := _stack_for_unit(unit_id, "player", 0)
	var melee_primary := _defender_stack("enemy", 0)
	var melee_secondary := _stack_for_unit("unit_mireclaw_ferrychain_lashers", "enemy", 1)
	_set_hex(melee_attacker, 5, 3)
	_set_hex(melee_primary, 6, 3)
	_set_hex(melee_secondary, 6, 4)
	var melee_battle := _battle_for_stacks([melee_attacker, melee_primary, melee_secondary], [], "plains", 3)
	var melee_secondary_before := int(melee_secondary.get("total_health", 0))
	BattleRulesScript._apply_attack_ability_effects(melee_battle, melee_attacker, melee_primary, false, 0)
	var melee_updated := BattleRulesScript._get_stack_by_id(melee_battle, String(melee_attacker.get("battle_id", "")))
	var melee_secondary_after := BattleRulesScript._get_stack_by_id(melee_battle, String(melee_secondary.get("battle_id", "")))
	var role_line := BattleRulesScript._ability_role_sentence(attacker, ability, battle, primary)
	var ok: bool = (
		expected_damage == 8
		and String(ai_secondary.get("battle_id", "")) == selected_id
		and ai_secondary_damage == expected_damage
		and selected_after_health == selected_before - expected_damage
		and tied_after_health == tied_before
		and distant_after_health == distant_before
		and ally_after_health == ally_before
		and overheated
		and heat_initiative_modifier == -1
		and did_not_refresh
		and recovered
		and event_found
		and heat_event_found
		and cluster_score > no_cluster_score
		and int(no_cluster_primary_after.get("total_health", 0)) == no_cluster_primary_before
		and SpellRulesScript.has_effect_id(no_cluster_updated, no_cluster_battle, "status_overheated")
		and not no_cluster_messages.is_empty()
		and int(stripped_secondary_after.get("total_health", 0)) == stripped_secondary_before
		and not SpellRulesScript.has_effect_id(stripped_updated, stripped_battle, "status_overheated")
		and int(melee_secondary_after.get("total_health", 0)) == melee_secondary_before
		and not SpellRulesScript.has_effect_id(melee_updated, melee_battle, "status_overheated")
		and messages.size() >= 2
		and role_line.contains("up to 10")
		and role_line.contains("one enemy adjacent")
		and role_line.contains("Overheated")
		and role_line.contains("2 rounds")
	)
	return {
		"ok": ok,
		"probe": "pressure_artillery_cluster_heat_ai_and_exclusions",
		"expected_damage": expected_damage,
		"selected_secondary_id": selected_id,
		"ai_secondary_id": String(ai_secondary.get("battle_id", "")),
		"ai_secondary_damage": ai_secondary_damage,
		"selected_health_before": selected_before,
		"selected_health_after": selected_after_health,
		"tied_health_before": tied_before,
		"tied_health_after": tied_after_health,
		"distant_health_before": distant_before,
		"distant_health_after": distant_after_health,
		"ally_health_before": ally_before,
		"ally_health_after": ally_after_health,
		"overheated": overheated,
		"initiative_before": initiative_before,
		"initiative_after": initiative_after,
		"heat_initiative_modifier": heat_initiative_modifier,
		"did_not_refresh": did_not_refresh,
		"recovered": recovered,
		"event_found": event_found,
		"heat_event_found": heat_event_found,
		"cluster_score": cluster_score,
		"no_cluster_score": no_cluster_score,
		"no_cluster_primary_health": int(no_cluster_primary_after.get("total_health", 0)),
		"stripped_secondary_health": int(stripped_secondary_after.get("total_health", 0)),
		"melee_secondary_health": int(melee_secondary_after.get("total_health", 0)),
		"role_line": role_line,
		"reason": "" if ok else "pressure artillery did not preserve its deterministic clustered hit, heat cycle, AI parity, events, or excluded paths",
	}

func _probe_sporeglass_mend(unit_id: String) -> Dictionary:
	var source := _stack_for_unit(unit_id, "player", 0)
	var high_first := _stack_for_unit("unit_thornwake_barkmantle_rams", "player", 1)
	var high_second := _stack_for_unit("unit_thornwake_barkmantle_rams", "player", 2)
	var low_tier := _stack_for_unit("unit_thornwake_thornwhip_carriers", "player", 3)
	var defeated_target := _defender_stack("enemy", 0)
	for ally in [high_first, high_second, low_tier]:
		var full_health: int = int(ally.get("base_count", 1)) * int(ally.get("unit_hp", 1))
		ally["total_health"] = full_health - 9
	defeated_target["total_health"] = 0
	var battle := _battle_for_stacks([source, high_first, high_second, low_tier, defeated_target])
	var high_first_id := String(high_first.get("battle_id", ""))
	var high_second_id := String(high_second.get("battle_id", ""))
	var low_tier_id := String(low_tier.get("battle_id", ""))
	var high_first_before := int(high_first.get("total_health", 0))
	var high_second_before := int(high_second.get("total_health", 0))
	var low_tier_before := int(low_tier.get("total_health", 0))
	var messages := BattleRulesScript._apply_attack_ability_effects(battle, source, defeated_target, true, 1)
	var high_first_after := BattleRulesScript._get_stack_by_id(battle, high_first_id)
	var high_second_after := BattleRulesScript._get_stack_by_id(battle, high_second_id)
	var low_tier_after := BattleRulesScript._get_stack_by_id(battle, low_tier_id)
	var restored := int(high_first_after.get("total_health", 0)) - high_first_before
	var deterministic_target_only := (
		int(high_second_after.get("total_health", 0)) == high_second_before
		and int(low_tier_after.get("total_health", 0)) == low_tier_before
	)
	var heal_event_found := false
	for event in battle.get("battle_presentation_events", []):
		if event is Dictionary \
				and String(event.get("event_type", "")) == "heal" \
				and String(event.get("action_id", "")) == "sporeglass_mend" \
				and String(event.get("target_battle_id", "")) == high_first_id \
				and int(event.get("healing", 0)) == 8:
			heal_event_found = true
			break

	var full_source := _stack_for_unit(unit_id, "player", 0)
	var full_ally := _stack_for_unit("unit_thornwake_barkmantle_rams", "player", 1)
	var full_target := _defender_stack("enemy", 0)
	full_target["total_health"] = 0
	var full_battle := _battle_for_stacks([full_source, full_ally, full_target])
	var full_messages := BattleRulesScript._apply_attack_ability_effects(full_battle, full_source, full_target, true, 1)

	var casualty_source := _stack_for_unit(unit_id, "player", 0)
	var casualty_ally := _stack_for_unit("unit_thornwake_barkmantle_rams", "player", 1)
	var casualty_target := _defender_stack("enemy", 0)
	var casualty_health: int = int(casualty_ally.get("total_health", 0)) - int(casualty_ally.get("unit_hp", 1))
	casualty_ally["total_health"] = casualty_health
	casualty_target["total_health"] = 0
	var casualty_battle := _battle_for_stacks([casualty_source, casualty_ally, casualty_target])
	var casualty_messages := BattleRulesScript._apply_attack_ability_effects(casualty_battle, casualty_source, casualty_target, true, 1)
	var casualty_after := BattleRulesScript._get_stack_by_id(casualty_battle, String(casualty_ally.get("battle_id", "")))

	var dead_source := _stack_for_unit(unit_id, "player", 0)
	var dead_ally := _stack_for_unit("unit_thornwake_barkmantle_rams", "player", 1)
	dead_source["total_health"] = 0
	dead_ally["total_health"] = int(dead_ally.get("total_health", 0)) - 9
	var dead_target := _defender_stack("enemy", 0)
	dead_target["total_health"] = 0
	var dead_battle := _battle_for_stacks([dead_source, dead_ally, dead_target])
	var dead_ally_before := int(dead_ally.get("total_health", 0))
	var dead_messages := BattleRulesScript._apply_attack_ability_effects(dead_battle, dead_source, dead_target, true, 1)
	var dead_ally_after := BattleRulesScript._get_stack_by_id(dead_battle, String(dead_ally.get("battle_id", "")))

	var stripped_source := _without_ability(_stack_for_unit(unit_id, "player", 0), "sporeglass_mend")
	var stripped_ally := _stack_for_unit("unit_thornwake_barkmantle_rams", "player", 1)
	stripped_ally["total_health"] = int(stripped_ally.get("total_health", 0)) - 9
	var stripped_target := _defender_stack("enemy", 0)
	stripped_target["total_health"] = 0
	var stripped_battle := _battle_for_stacks([stripped_source, stripped_ally, stripped_target])
	var stripped_ally_before := int(stripped_ally.get("total_health", 0))
	var stripped_messages := BattleRulesScript._apply_attack_ability_effects(stripped_battle, stripped_source, stripped_target, true, 1)
	var stripped_ally_after := BattleRulesScript._get_stack_by_id(stripped_battle, String(stripped_ally.get("battle_id", "")))

	var ability := _ability_by_id(source, "sporeglass_mend")
	var role_line := BattleRulesScript._ability_role_sentence(source, ability, battle, defeated_target)
	var window_line := BattleRulesScript._active_ability_window_summary(source, battle, defeated_target)
	var ok: bool = (
		restored == 8
		and deterministic_target_only
		and not messages.is_empty()
		and heal_event_found
		and full_messages.is_empty()
		and casualty_messages.is_empty()
		and int(casualty_after.get("total_health", 0)) == casualty_health
		and dead_messages.is_empty()
		and int(dead_ally_after.get("total_health", 0)) == dead_ally_before
		and stripped_messages.is_empty()
		and int(stripped_ally_after.get("total_health", 0)) == stripped_ally_before
		and role_line.contains("8")
		and window_line.contains("fallen creatures cannot return")
	)
	return {
		"ok": ok,
		"probe": "sporeglass_mend_success_targeting_survivor_scope_and_presentation",
		"restored": restored,
		"selected_target": high_first_id,
		"deterministic_target_only": deterministic_target_only,
		"heal_event_found": heal_event_found,
		"full_health_message_count": full_messages.size(),
		"casualty_health_before": casualty_health,
		"casualty_health_after": int(casualty_after.get("total_health", 0)),
		"dead_source_health_before": dead_ally_before,
		"dead_source_health_after": int(dead_ally_after.get("total_health", 0)),
		"stripped_source_health_before": stripped_ally_before,
		"stripped_source_health_after": int(stripped_ally_after.get("total_health", 0)),
		"role_line": role_line,
		"window_line": window_line,
		"reason": "" if ok else "Mending Fire did not prove capped deterministic survivor-only repair and player-facing presentation",
	}

func _probe_foundry_aura(unit_id: String) -> Dictionary:
	var saint := _stack_for_unit(unit_id, "player", 0)
	var ally := _stack_for_unit("unit_brasshollow_debt_engine_exactors", "player", 1)
	var outsider := _stack_for_unit(BASE_DEFENDER_UNIT_ID, "player", 2)
	var enemy := _defender_stack("enemy", 0)
	ally["defending"] = true
	outsider["defending"] = true
	var battle := _battle_for_stacks([saint, ally, outsider, enemy], [], "plains", 1)
	var stripped_saint := _without_ability(saint, "foundry_aura")
	var stripped_ally := ally.duplicate(true)
	var stripped_outsider := outsider.duplicate(true)
	var stripped_enemy := enemy.duplicate(true)
	var stripped_battle := _battle_for_stacks([stripped_saint, stripped_ally, stripped_outsider, stripped_enemy], [], "plains", 1)
	var allied_defense_with := BattleRulesScript._stack_defense_total(ally, battle)
	var allied_defense_without := BattleRulesScript._stack_defense_total(stripped_ally, stripped_battle)
	var outsider_defense_with := BattleRulesScript._stack_defense_total(outsider, battle)
	var outsider_defense_without := BattleRulesScript._stack_defense_total(stripped_outsider, stripped_battle)
	var unbraced_saint := _stack_for_unit(unit_id, "player", 0)
	var unbraced_ally := _stack_for_unit("unit_brasshollow_debt_engine_exactors", "player", 1)
	var unbraced_stripped_saint := _without_ability(unbraced_saint, "foundry_aura")
	var unbraced_stripped_ally := unbraced_ally.duplicate(true)
	var unbraced_battle := _battle_for_stacks([unbraced_saint, unbraced_ally, _defender_stack("enemy", 0)], [], "plains", 1)
	var unbraced_stripped_battle := _battle_for_stacks([unbraced_stripped_saint, unbraced_stripped_ally, _defender_stack("enemy", 0)], [], "plains", 1)
	var unbraced_defense_with := BattleRulesScript._stack_defense_total(unbraced_ally, unbraced_battle)
	var unbraced_defense_without := BattleRulesScript._stack_defense_total(unbraced_stripped_ally, unbraced_stripped_battle)

	var unit_hp: int = max(1, int(ally.get("unit_hp", 1)))
	var full_health: int = int(ally.get("base_count", 1)) * unit_hp
	ally["total_health"] = full_health - 10
	ally["effects"] = [
		SpellRulesScript.build_battle_effect(
			"status_overheated",
			"Overheated",
			{"defense": -2, "initiative": -2},
			2,
			battle,
			"unit_ability_runtime_report",
			"overheat"
		)
	]
	var alive_before := BattleRulesScript._alive_count(ally)
	var health_before := int(ally.get("total_health", 0))
	BattleRulesScript._prepare_round(battle, 2)
	var repaired_ally := BattleRulesScript._get_stack_by_id(battle, String(ally.get("battle_id", "")))
	var overheated_repair := int(repaired_ally.get("total_health", 0)) - health_before
	var alive_after := BattleRulesScript._alive_count(repaired_ally)
	var repaired_saint := BattleRulesScript._get_stack_by_id(battle, String(saint.get("battle_id", "")))
	var repaired_stripped_saint := _without_ability(repaired_saint, "foundry_aura")
	var repaired_stripped_ally := repaired_ally.duplicate(true)
	var overheated_stripped_battle := _battle_for_stacks([repaired_stripped_saint, repaired_stripped_ally, _defender_stack("enemy", 0)], [], "plains", 1)
	var overheated_defense_with := BattleRulesScript._stack_defense_total(repaired_ally, battle)
	var overheated_defense_without := BattleRulesScript._stack_defense_total(repaired_stripped_ally, overheated_stripped_battle)
	var heal_event_found := false
	for event in battle.get("battle_presentation_events", []):
		if event is Dictionary and String(event.get("event_type", "")) == "heal" and String(event.get("action_id", "")) == "foundry_aura":
			heal_event_found = true
			break

	var plain_saint := _stack_for_unit(unit_id, "player", 0)
	var plain_ally := _stack_for_unit("unit_brasshollow_debt_engine_exactors", "player", 1)
	plain_ally["total_health"] = full_health - 10
	var plain_battle := _battle_for_stacks([plain_saint, plain_ally, _defender_stack("enemy", 0)], [], "plains", 1)
	var plain_health_before := int(plain_ally.get("total_health", 0))
	BattleRulesScript._prepare_round(plain_battle, 2)
	plain_ally = BattleRulesScript._get_stack_by_id(plain_battle, String(plain_ally.get("battle_id", "")))
	var plain_repair := int(plain_ally.get("total_health", 0)) - plain_health_before

	var hex_saint := _stack_for_unit(unit_id, "player", 0)
	var hex_ally := _stack_for_unit("unit_brasshollow_debt_engine_exactors", "player", 1)
	hex_ally["total_health"] = full_health - 10
	var hex_battle := _battle_for_stacks([hex_saint, hex_ally, _defender_stack("enemy", 0)], [], "plains", 1)
	var hex_health_before := int(hex_ally.get("total_health", 0))
	BattleRulesScript._ensure_battle_hex_state(hex_battle)
	hex_ally = BattleRulesScript._get_stack_by_id(hex_battle, String(hex_ally.get("battle_id", "")))
	var hex_health_after := int(hex_ally.get("total_health", 0))

	var lost_unit_saint := _stack_for_unit(unit_id, "player", 0)
	var lost_unit_ally := _stack_for_unit("unit_brasshollow_debt_engine_exactors", "player", 1)
	lost_unit_ally["total_health"] = full_health - unit_hp
	var lost_unit_battle := _battle_for_stacks([lost_unit_saint, lost_unit_ally, _defender_stack("enemy", 0)], [], "plains", 1)
	var lost_unit_health_before := int(lost_unit_ally.get("total_health", 0))
	BattleRulesScript._prepare_round(lost_unit_battle, 2)
	lost_unit_ally = BattleRulesScript._get_stack_by_id(lost_unit_battle, String(lost_unit_ally.get("battle_id", "")))
	var lost_unit_health_after := int(lost_unit_ally.get("total_health", 0))

	var dead_saint := saint.duplicate(true)
	dead_saint["total_health"] = 0
	var unsupported_ally := _stack_for_unit("unit_brasshollow_debt_engine_exactors", "player", 1)
	unsupported_ally["defending"] = true
	var dead_saint_battle := _battle_for_stacks([dead_saint, unsupported_ally, enemy.duplicate(true)], [], "plains", 1)
	var defense_without_living_saint := BattleRulesScript._stack_defense_total(unsupported_ally, dead_saint_battle)
	var dead_saint_aura_bonus := BattleRulesScript._side_max_ability_int(dead_saint_battle, "player", "foundry_aura", "ally_defense_bonus")
	var living_saint_same_shape := _stack_for_unit(unit_id, "player", 0)
	var supported_ally_same_shape := _stack_for_unit("unit_brasshollow_debt_engine_exactors", "player", 1)
	supported_ally_same_shape["defending"] = true
	var living_saint_battle := _battle_for_stacks([living_saint_same_shape, supported_ally_same_shape, _defender_stack("enemy", 0)], [], "plains", 1)
	var defense_with_living_saint := BattleRulesScript._stack_defense_total(supported_ally_same_shape, living_saint_battle)
	var living_saint_aura_bonus := BattleRulesScript._side_max_ability_int(living_saint_battle, "player", "foundry_aura", "ally_defense_bonus")
	var target_priority_with := BattleAiRulesScript._attack_score(enemy, saint, battle, false)
	var target_priority_without := BattleAiRulesScript._attack_score(stripped_enemy, stripped_saint, stripped_battle, false)
	var ok: bool = (
		allied_defense_with == allied_defense_without
		and outsider_defense_with == outsider_defense_without
		and unbraced_defense_with == unbraced_defense_without
		and overheated_defense_with == overheated_defense_without + 1
		and living_saint_aura_bonus == 1
		and dead_saint_aura_bonus == 0
		and overheated_repair > plain_repair
		and plain_repair > 0
		and hex_health_after == hex_health_before
		and alive_before == alive_after
		and lost_unit_health_after == lost_unit_health_before
		and heal_event_found
		and target_priority_with > target_priority_without
	)
	return {
		"ok": ok,
		"probe": "foundry_aura_hardening_repair_scope_and_ai",
		"allied_defense_with": allied_defense_with,
		"allied_defense_without": allied_defense_without,
		"outsider_defense_with": outsider_defense_with,
		"outsider_defense_without": outsider_defense_without,
		"unbraced_defense_with": unbraced_defense_with,
		"unbraced_defense_without": unbraced_defense_without,
		"overheated_defense_with": overheated_defense_with,
		"overheated_defense_without": overheated_defense_without,
		"defense_without_living_saint": defense_without_living_saint,
		"defense_with_living_saint": defense_with_living_saint,
		"living_saint_aura_bonus": living_saint_aura_bonus,
		"dead_saint_aura_bonus": dead_saint_aura_bonus,
		"plain_repair": plain_repair,
		"overheated_repair": overheated_repair,
		"hex_health_before": hex_health_before,
		"hex_health_after": hex_health_after,
		"alive_before": alive_before,
		"alive_after": alive_after,
		"lost_unit_health_before": lost_unit_health_before,
		"lost_unit_health_after": lost_unit_health_after,
		"heal_event_found": heal_event_found,
		"target_priority_with": target_priority_with,
		"target_priority_without": target_priority_without,
		"reason": "" if ok else "foundry aura mismatch: defended=%d/%d outsider=%d/%d unbraced=%d/%d overheated_defense=%d/%d repair=%d/%d hex=%d/%d alive=%d/%d lost=%d/%d aura=%d/%d heal=%s ai=%.2f/%.2f" % [
			allied_defense_with,
			allied_defense_without,
			outsider_defense_with,
			outsider_defense_without,
			unbraced_defense_with,
			unbraced_defense_without,
			overheated_defense_with,
			overheated_defense_without,
			overheated_repair,
			plain_repair,
			hex_health_before,
			hex_health_after,
			alive_before,
			alive_after,
			lost_unit_health_before,
			lost_unit_health_after,
			living_saint_aura_bonus,
			dead_saint_aura_bonus,
			str(heal_event_found),
			target_priority_with,
			target_priority_without,
		],
	}

func _defend_cohesion_delta(stack: Dictionary, label: String, held_objective_types: Array = []) -> int:
	var actor := stack.duplicate(true)
	actor["battle_id"] = "%s_%s" % [String(actor.get("battle_id", "stack")), label]
	actor["cohesion_base"] = 4
	actor["cohesion"] = 4
	actor["defending"] = false
	var defender := _defender_stack("enemy", 0)
	var battle := _battle_for_stacks([actor, defender])
	if not held_objective_types.is_empty():
		battle["field_objectives"] = [{"type": String(held_objective_types[0]), "control_side": "player"}]
	var before := BattleRulesScript._stack_cohesion_total(actor, battle)
	BattleRulesScript._apply_defend_pressure(battle, String(actor.get("battle_id", "")))
	var updated := BattleRulesScript._get_stack_by_id(battle, String(actor.get("battle_id", "")))
	var after := BattleRulesScript._stack_cohesion_total(updated, battle)
	return after - before

func _stack_for_unit(unit_id: String, side: String, index: int) -> Dictionary:
	var stack: Dictionary = BattleRulesScript._build_battle_stack(
		unit_id,
		8,
		side,
		index,
		{"source_type": "unit_ability_runtime_report"}
	)
	stack["battle_id"] = "%s_%d_%s" % [side, index, unit_id]
	stack["side"] = side
	return stack

func _defender_stack(side: String = "enemy", index: int = 0) -> Dictionary:
	var stack := _stack_for_unit(BASE_DEFENDER_UNIT_ID, side, index)
	stack["abilities"] = []
	stack["effects"] = []
	return stack

func _battle_for_stacks(stacks: Array, tags: Array = [], terrain: String = "plains", round_number: int = 3) -> Dictionary:
	var battle := {
		"round": round_number,
		"terrain": terrain,
		"distance": 1,
		"battlefield_tags": tags.duplicate(),
		"stacks": stacks,
	}
	BattleRulesScript._ensure_battle_hex_state(battle)
	return battle

func _without_ability(stack: Dictionary, ability_id: String) -> Dictionary:
	var copy := stack.duplicate(true)
	var abilities := []
	for ability in copy.get("abilities", []):
		if ability is Dictionary and String(ability.get("id", "")) == ability_id:
			continue
		abilities.append(ability)
	copy["abilities"] = abilities
	return copy

func _ability_by_id(stack: Dictionary, ability_id: String) -> Dictionary:
	for ability in stack.get("abilities", []):
		if ability is Dictionary and String(ability.get("id", "")) == ability_id:
			return ability
	return {}

func _first_status_id(ability: Dictionary) -> String:
	if String(ability.get("status_id", "")).strip_edges() != "":
		return String(ability.get("status_id", "")).strip_edges()
	for value in ability.get("status_ids", []):
		var status_id := String(value).strip_edges()
		if status_id != "":
			return status_id
	return ""

func _add_effect(stack: Dictionary, status_id: String) -> void:
	var battle := {"round": 3}
	stack["effects"] = [
		SpellRulesScript.build_battle_effect(status_id, status_id, {}, 2, battle, "unit_ability_runtime_report", status_id)
	]

func _add_positive_effect(stack: Dictionary, effect_id: String, modifier_kind: String = "attack") -> void:
	stack["effects"] = [
		SpellRulesScript.build_battle_effect(
			effect_id,
			effect_id,
			{modifier_kind: 1},
			2,
			{"round": 3},
			"unit_ability_runtime_report",
			effect_id
		)
	]

func _wounded_defender_for_ability(attacker: Dictionary, ability_id: String) -> Dictionary:
	var defender := _defender_stack()
	var ability := _ability_by_id(attacker, ability_id)
	var threshold := clampf(float(ability.get("wounded_threshold_ratio", 0.5)), 0.05, 1.0)
	var full_health: int = max(1, int(defender.get("base_count", 1)) * int(defender.get("unit_hp", 1)))
	defender["total_health"] = max(1, int(floor(float(full_health) * threshold * 0.8)))
	return defender

func _set_hex(stack: Dictionary, q: int, r: int) -> void:
	stack["hex"] = {"q": q, "r": r}

func _items(raw: Dictionary) -> Array:
	var items = raw.get("items", [])
	return items if items is Array else []

func _ensure_output_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))

func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.WRITE)
	if file == null:
		_error("Failed to open %s for writing." % path)
		return
	file.store_string(JSON.stringify(payload, "\t"))

func _summary_payload() -> Dictionary:
	return {
		"ok": bool(_report.get("ok", false)),
		"unit_count": int(_report.get("unit_count", 0)),
		"ability_instance_count": int(_report.get("ability_instance_count", 0)),
		"runtime_consequence_count": int(_report.get("runtime_consequence_count", 0)),
		"ability_family_counts": _report.get("ability_family_counts", {}),
		"ability_family_consequence_counts": _report.get("ability_family_consequence_counts", {}),
	}

func _error(message: String) -> void:
	_errors.append(message)
	push_error(message)
