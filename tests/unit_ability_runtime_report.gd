extends Node

const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
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
	var ok := modifier_with < modifier_without
	return {
		"ok": ok,
		"probe": "shielding_ranged_damage_reduction",
		"modifier_with": modifier_with,
		"modifier_without": modifier_without,
		"reason": "" if ok else "shielding did not reduce incoming ranged damage",
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
