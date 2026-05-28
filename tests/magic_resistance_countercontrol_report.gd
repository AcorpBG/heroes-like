extends Node

const REPORT_ID := "MAGIC_RESISTANCE_COUNTERCONTROL_REPORT"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var cases := {
		"damage_resistance": _damage_resistance_case(),
		"control_immunity": _control_immunity_case(),
		"control_resistance": _control_resistance_case(),
		"cleanse_immunity": _cleanse_immunity_case(),
		"artifact_resistance": _artifact_resistance_case(),
	}
	for case_id in cases.keys():
		if not bool(cases[case_id].get("ok", false)):
			_fail("%s failed: %s" % [case_id, cases[case_id]])
			return
	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"cases": cases,
		"policy": "Damage mitigation, control resistance, temporary immunity, and artifact resistance are live battle mechanics.",
	}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _damage_resistance_case() -> Dictionary:
	var hero := _hero(["spell_cinder_burst"])
	var battle := _battle("damage_case", _target("enemy_target", "enemy", {"spell_resistance_pct": 50}))
	var active := _stack_by_id(battle, "player_line")
	var target := _stack_by_id(battle, "enemy_target")
	var resolution := SpellRules.resolve_battle_spell(hero, battle, active, target, "spell_cinder_burst")
	if not bool(resolution.get("ok", false)):
		return {"ok": false, "error": resolution}
	if int(resolution.get("raw_damage", 0)) <= int(resolution.get("final_damage", 0)):
		return {"ok": false, "error": "damage was not mitigated", "resolution": resolution}
	if int(resolution.get("prevented_damage", 0)) <= 0 or int(resolution.get("resistance_pct", 0)) <= 0:
		return {"ok": false, "error": "missing resistance metadata", "resolution": resolution}
	return {
		"ok": true,
		"raw_damage": int(resolution.get("raw_damage", 0)),
		"final_damage": int(resolution.get("final_damage", 0)),
		"resistance_pct": int(resolution.get("resistance_pct", 0)),
	}

func _control_immunity_case() -> Dictionary:
	var hero := _hero(["spell_briar_bind"])
	var battle := _battle("immune_case", _target("enemy_target", "enemy", {"status_immunity_ids": ["status_rooted"]}))
	var resolution := SpellRules.resolve_battle_spell(hero, battle, _stack_by_id(battle, "player_line"), _stack_by_id(battle, "enemy_target"), "spell_briar_bind")
	if not bool(resolution.get("ok", false)) or not bool(resolution.get("immune", false)):
		return {"ok": false, "error": "control immunity did not block", "resolution": resolution}
	if resolution.get("effect", {}) is Dictionary and not resolution.get("effect", {}).is_empty():
		return {"ok": false, "error": "immune control still returned an apply effect", "resolution": resolution}
	return {"ok": true, "blocked_status_id": String(resolution.get("blocked_status_id", ""))}

func _control_resistance_case() -> Dictionary:
	for seed in range(100):
		var hero := _hero(["spell_briar_bind"])
		var battle := _battle("resist_%d" % seed, _target("enemy_target", "enemy", {"control_resistance_pct": 80}))
		battle["resistance_seed"] = seed
		var resolution := SpellRules.resolve_battle_spell(hero, battle, _stack_by_id(battle, "player_line"), _stack_by_id(battle, "enemy_target"), "spell_briar_bind")
		if bool(resolution.get("ok", false)) and bool(resolution.get("resisted", false)):
			return {
				"ok": true,
				"seed": seed,
				"roll": int(resolution.get("resistance_roll", -1)),
				"control_resistance_pct": int(resolution.get("control_resistance_pct", 0)),
				"blocked_status_id": String(resolution.get("blocked_status_id", "")),
			}
	return {"ok": false, "error": "no deterministic resistance roll succeeded across fixture seeds"}

func _cleanse_immunity_case() -> Dictionary:
	var hero := _hero(["spell_prism_bastion"])
	var harried := SpellRules.build_battle_effect("status_harried", "Harried", {"defense": -1}, 2, {"round": 1}, "test", "seed")
	var player := _target("player_line", "player", {"effects": [harried]})
	var battle := _battle("cleanse_case", _target("enemy_target", "enemy", {}), player)
	var resolution := SpellRules.resolve_battle_spell(hero, battle, _stack_by_id(battle, "player_line"), {}, "spell_prism_bastion")
	if not bool(resolution.get("ok", false)):
		return {"ok": false, "error": resolution}
	var effect: Dictionary = resolution.get("effect", {}) if resolution.get("effect", {}) is Dictionary else {}
	var immunity_ids := SpellRules.normalize_status_immunity_ids(effect.get("status_immunity_ids", []))
	for status_id in resolution.get("cleanse_effect_ids", []):
		if String(status_id) not in immunity_ids:
			return {"ok": false, "error": "cleanse immunity did not mirror cleanse ids", "resolution": resolution}
	return {"ok": true, "cleanse_effect_ids": resolution.get("cleanse_effect_ids", []), "status_immunity_ids": immunity_ids}

func _artifact_resistance_case() -> Dictionary:
	var hero := {
		"artifacts": {
			"equipped": {"trinket": "artifact_choir_tuning_fork"},
			"inventory": [],
		},
	}
	var totals := ArtifactRules.aggregate_bonuses(hero)
	var school_resistance: Dictionary = totals.get("battle_school_resistance_pct", {}) if totals.get("battle_school_resistance_pct", {}) is Dictionary else {}
	if int(totals.get("battle_spell_resistance_pct", 0)) < 8 or int(totals.get("battle_control_resistance_pct", 0)) < 8:
		return {"ok": false, "error": "Choir Tuning Fork did not aggregate general resistance", "totals": totals}
	if int(school_resistance.get("lens", 0)) < 10:
		return {"ok": false, "error": "Choir Tuning Fork did not aggregate Lens resistance", "totals": totals}
	return {"ok": true, "spell_resistance_pct": int(totals.get("battle_spell_resistance_pct", 0)), "control_resistance_pct": int(totals.get("battle_control_resistance_pct", 0)), "lens_resistance_pct": int(school_resistance.get("lens", 0))}

func _hero(spell_ids: Array) -> Dictionary:
	return SpellRules.ensure_hero_spellbook(
		{
			"name": "Resistance Report Caster",
			"command": {"power": 2, "knowledge": 4},
			"spellbook": {
				"known_spell_ids": spell_ids,
				"mana": {"current": 40, "max": 40},
			},
		}
	)

func _battle(seed: String, target: Dictionary, player_stack: Dictionary = {}) -> Dictionary:
	var player := player_stack if not player_stack.is_empty() else _target("player_line", "player", {})
	return {
		"round": 1,
		"resistance_seed": seed,
		"player_hero": {"battle_spell_resistance_pct": 0, "battle_control_resistance_pct": 0, "battle_school_resistance_pct": {}},
		"enemy_hero_payload": {"battle_spell_resistance_pct": 0, "battle_control_resistance_pct": 0, "battle_school_resistance_pct": {}},
		"stacks": [player, target],
	}

func _target(battle_id: String, side: String, overrides: Dictionary) -> Dictionary:
	var stack := {
		"battle_id": battle_id,
		"side": side,
		"name": battle_id.capitalize(),
		"base_count": 8,
		"unit_hp": 10,
		"total_health": 80,
		"attack": 4,
		"defense": 4,
		"initiative": 5,
		"effects": [],
		"spell_resistance_pct": 0,
		"control_resistance_pct": 0,
		"spell_school_resistance_pct": {},
		"status_immunity_ids": [],
	}
	for key in overrides.keys():
		stack[key] = overrides[key]
	return stack

func _stack_by_id(battle: Dictionary, battle_id: String) -> Dictionary:
	for stack in battle.get("stacks", []):
		if stack is Dictionary and String(stack.get("battle_id", "")) == battle_id:
			return stack
	return {}

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
