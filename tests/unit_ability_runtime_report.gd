extends Node

const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const BattleAiRulesScript = preload("res://scripts/core/BattleAiRules.gd")
const SpellRulesScript = preload("res://scripts/core/SpellRules.gd")

const OUTPUT_DIR := "res://.artifacts/unit_ability_runtime_report"
const REQUIRED_ABILITY_IDS := [
	"reach",
	"brace",
	"harry",
	"backstab",
	"shielding",
	"volley",
	"formation_guard",
	"bloodrush",
	"obituary",
	"overheat",
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
			"runtime_consequence": consequence,
		})
	_report["units"].append({
		"unit_id": unit_id,
		"name": String(unit.get("name", unit_id)),
		"ability_count": abilities.size(),
		"abilities": ability_summaries,
	})

func _runtime_consequence_for_ability(unit_id: String, ability_id: String) -> Dictionary:
	match ability_id:
		"reach":
			return _probe_reach(unit_id)
		"brace":
			return _probe_brace(unit_id)
		"harry":
			return _probe_harry(unit_id)
		"obituary":
			return _probe_obituary(unit_id)
		"backstab":
			return _probe_backstab(unit_id)
		"shielding":
			return _probe_shielding(unit_id)
		"volley":
			return _probe_volley(unit_id)
		"formation_guard":
			return _probe_formation_guard(unit_id)
		"bloodrush":
			return _probe_bloodrush(unit_id)
		"overheat":
			return _probe_overheat(unit_id)
		"foundry_aura":
			return _probe_foundry_aura(unit_id)
		_:
			return {"ok": false, "reason": "unsupported ability"}

func _probe_reach(unit_id: String) -> Dictionary:
	var attacker := _stack_for_unit(unit_id, "player", 0)
	var defender := _defender_stack()
	_set_hex(attacker, 4, 3)
	_set_hex(defender, 6, 3)
	var battle := _battle_for_stacks([attacker, defender])
	var stripped := _without_ability(attacker, "reach")
	var stripped_battle := _battle_for_stacks([stripped, defender.duplicate(true)])
	var legal_with := BattleRulesScript._can_make_melee_attack(attacker, battle, defender)
	var legal_without := BattleRulesScript._can_make_melee_attack(stripped, stripped_battle, defender)
	return {
		"ok": legal_with and not legal_without,
		"probe": "reach_hex_distance_two_melee_legality",
		"legal_with": legal_with,
		"legal_without": legal_without,
		"reason": "" if legal_with and not legal_without else "reach did not uniquely unlock distance-two melee",
	}

func _probe_brace(unit_id: String) -> Dictionary:
	var attacker := _stack_for_unit(unit_id, "player", 0)
	var defender := _defender_stack()
	attacker["defending"] = true
	var battle := _battle_for_stacks([attacker, defender])
	var stripped := _without_ability(attacker, "brace")
	var stripped_battle := _battle_for_stacks([stripped, defender.duplicate(true)])
	var retaliation_with := BattleRulesScript._ability_damage_modifier(attacker, defender, battle, false, true, 0)
	var retaliation_without := BattleRulesScript._ability_damage_modifier(stripped, defender, stripped_battle, false, true, 0)
	var defend_with := _defend_cohesion_delta(attacker, "brace")
	var defend_without := _defend_cohesion_delta(stripped, "brace_stripped")
	var ok := retaliation_with > retaliation_without and defend_with > defend_without
	return {
		"ok": ok,
		"probe": "brace_retaliation_and_defend_pressure",
		"retaliation_modifier_with": retaliation_with,
		"retaliation_modifier_without": retaliation_without,
		"defend_cohesion_delta_with": defend_with,
		"defend_cohesion_delta_without": defend_without,
		"reason": "" if ok else "brace did not increase both retaliation modifier and defend cohesion",
	}

func _probe_harry(unit_id: String) -> Dictionary:
	var attacker := _stack_for_unit(unit_id, "player", 0)
	var defender := _defender_stack()
	var harry := _ability_by_id(attacker, "harry")
	var status_id := String(harry.get("status_id", "")).strip_edges()
	if status_id == "":
		return {"ok": false, "probe": "harry_status_application", "reason": "harry ability has no status_id"}
	_set_hex(attacker, 4, 3)
	_set_hex(defender, 5, 3)
	var battle := _battle_for_stacks([attacker, defender])
	var messages := BattleRulesScript._apply_attack_ability_effects(
		battle,
		attacker,
		defender,
		bool(attacker.get("ranged", false)),
		1 if bool(attacker.get("ranged", false)) else 0
	)
	var updated_defender := BattleRulesScript._get_stack_by_id(battle, String(defender.get("battle_id", "")))
	var status_with := SpellRulesScript.has_effect_id(updated_defender, battle, status_id)
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
	var ok := status_with and not status_without and not messages.is_empty()
	return {
		"ok": ok,
		"probe": "harry_status_application",
		"status_id": status_id,
		"is_ranged": bool(attacker.get("ranged", false)),
		"status_with": status_with,
		"status_without": status_without,
		"message_count": messages.size(),
		"reason": "" if ok else "harry did not uniquely apply its status effect",
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
	BattleRulesScript._apply_attack_ability_effects(braced_battle, braced_scribe, braced_defender, true, 1)
	var braced_marked := BattleRulesScript._get_stack_by_id(braced_battle, String(braced_defender.get("battle_id", "")))
	var braced_cohesion_pressure := SpellRulesScript.effect_bonus_for_kind(braced_marked, braced_battle, "cohesion")
	var braced_retaliation_pressure := SpellRulesScript.effect_bonus_for_kind(braced_marked, braced_battle, "retaliation")

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
		and marked_retaliation < base_retaliation
		and not SpellRulesScript.has_effect_id(second_marked, battle, "status_obituary_marked")
		and spent_preview.contains("already been issued")
		and is_equal_approx(expired_retaliation, base_retaliation)
		and not SpellRulesScript.has_effect_id(stripped_marked, stripped_battle, "status_obituary_marked")
		and preview.contains("Final Notice")
		and preview.contains("retaliation")
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
		"uses_after_second_attack": int(scribe.get("ability_uses", {}).get("obituary", 0)),
		"base_retaliation_modifier": base_retaliation,
		"marked_retaliation_modifier": marked_retaliation,
		"expired_retaliation_modifier": expired_retaliation,
		"preview": preview,
		"spent_preview": spent_preview,
		"message_count": messages.size(),
		"reason": "" if ok else "obituary did not apply bounded one-round cohesion and retaliation pressure",
	}

func _probe_backstab(unit_id: String) -> Dictionary:
	var attacker := _stack_for_unit(unit_id, "player", 0)
	var defender := _defender_stack()
	var backstab := _ability_by_id(attacker, "backstab")
	var status_id := _first_status_id(backstab)
	if status_id == "":
		return {"ok": false, "probe": "backstab_status_damage_modifier", "reason": "backstab has no status_ids"}
	_add_effect(defender, status_id)
	var battle := _battle_for_stacks([attacker, defender])
	var stripped := _without_ability(attacker, "backstab")
	var stripped_battle := _battle_for_stacks([stripped, defender.duplicate(true)])
	var modifier_with := BattleRulesScript._ability_damage_modifier(attacker, defender, battle, false, false, 0)
	var modifier_without := BattleRulesScript._ability_damage_modifier(stripped, defender, stripped_battle, false, false, 0)
	var ok := modifier_with > modifier_without
	return {
		"ok": ok,
		"probe": "backstab_status_damage_modifier",
		"status_id": status_id,
		"modifier_with": modifier_with,
		"modifier_without": modifier_without,
		"reason": "" if ok else "backstab did not increase damage against a status-marked target",
	}

func _probe_shielding(unit_id: String) -> Dictionary:
	var defender := _stack_for_unit(unit_id, "player", 0)
	var attacker := _defender_stack("enemy", 0)
	var battle := _battle_for_stacks([defender, attacker])
	var stripped_defender := _without_ability(defender, "shielding")
	var stripped_battle := _battle_for_stacks([stripped_defender, attacker.duplicate(true)])
	var modifier_with := BattleRulesScript._ability_damage_modifier(attacker, defender, battle, true, false, 2)
	var modifier_without := BattleRulesScript._ability_damage_modifier(attacker, stripped_defender, stripped_battle, true, false, 2)
	var ally_screen_reduction_pct := int(_ability_by_id(defender, "shielding").get("ally_ranged_melee_damage_reduction_pct", 0))
	var linebreaker_bonus_pct := int(_ability_by_id(defender, "shielding").get("linebreaker_screen_bonus_pct", 0))
	var total_linebreaker_screen_pct := ally_screen_reduction_pct + linebreaker_bonus_pct
	var ally_modifier_with := 1.0
	var ally_modifier_without := 1.0
	var ally_modifier_with_second_screen := 1.0
	var ai_damage_with := 0
	var ai_damage_without := 0
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
	var ok := modifier_with < modifier_without and ally_screen_ok
	return {
		"ok": ok,
		"probe": "shielding_self_and_allied_engine_damage_reduction",
		"modifier_with": modifier_with,
		"modifier_without": modifier_without,
		"ally_screen_reduction_pct": ally_screen_reduction_pct,
		"linebreaker_bonus_pct": linebreaker_bonus_pct,
		"total_linebreaker_screen_pct": total_linebreaker_screen_pct,
		"ally_modifier_with": ally_modifier_with,
		"ally_modifier_without": ally_modifier_without,
		"ally_modifier_with_second_screen": ally_modifier_with_second_screen,
		"ai_damage_with": ai_damage_with,
		"ai_damage_without": ai_damage_without,
		"reason": "" if ok else "shielding did not reduce its authored self or allied-engine incoming damage",
	}

func _probe_volley(unit_id: String) -> Dictionary:
	var attacker := _stack_for_unit(unit_id, "player", 0)
	var defender := _defender_stack()
	var volley := _ability_by_id(attacker, "volley")
	var min_distance: int = max(1, int(volley.get("min_distance", 1)))
	var battle := _battle_for_stacks([attacker, defender])
	var stripped := _without_ability(attacker, "volley")
	var stripped_battle := _battle_for_stacks([stripped, defender.duplicate(true)])
	var modifier_with := BattleRulesScript._ability_damage_modifier(attacker, defender, battle, true, false, min_distance)
	var modifier_without := BattleRulesScript._ability_damage_modifier(stripped, defender, stripped_battle, true, false, min_distance)
	var ok := bool(attacker.get("ranged", false)) and modifier_with > modifier_without
	return {
		"ok": ok,
		"probe": "volley_range_damage_modifier",
		"min_distance": min_distance,
		"modifier_with": modifier_with,
		"modifier_without": modifier_without,
		"reason": "" if ok else "volley did not increase ranged damage at its minimum distance",
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
	var ok := modifier_with > modifier_without
	return {
		"ok": ok,
		"probe": "bloodrush_wounded_damage_modifier",
		"target_health_ratio": BattleRulesScript._health_ratio(defender),
		"modifier_with": modifier_with,
		"modifier_without": modifier_without,
		"reason": "" if ok else "bloodrush did not increase damage against a wounded target",
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

func _defend_cohesion_delta(stack: Dictionary, label: String) -> int:
	var actor := stack.duplicate(true)
	actor["battle_id"] = "%s_%s" % [String(actor.get("battle_id", "stack")), label]
	actor["cohesion_base"] = 4
	actor["cohesion"] = 4
	actor["defending"] = false
	var defender := _defender_stack("enemy", 0)
	var battle := _battle_for_stacks([actor, defender])
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
