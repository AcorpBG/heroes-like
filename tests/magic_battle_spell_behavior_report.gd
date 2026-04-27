extends Node

const REPORT_ID := "MAGIC_BATTLE_SPELL_BEHAVIOR_REPORT"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var raw := ContentService.load_json(ContentService.SPELLS_PATH)
	var spells: Array = raw.get("items", [])
	var report := SpellRules.battle_spell_behavior_report(spells)
	if not bool(report.get("ok", false)):
		_fail(String(report.get("errors", [])))
		return

	for effect_type in ["damage_enemy", "control_enemy", "recover_ally", "cleanse_ally"]:
		if int(report.get("effect_type_counts", {}).get(effect_type, 0)) <= 0:
			_fail("Missing behavior coverage for %s." % effect_type)
			return

	var hero := SpellRules.ensure_hero_spellbook(
		{
			"name": "Report Caster",
			"command": {"power": 2, "knowledge": 8},
			"spellbook": {
				"known_spell_ids": [
					"spell_cinder_burst",
					"spell_briar_bind",
					"spell_graft_mend",
					"spell_prism_bastion",
				],
				"mana": {"current": 40, "max": 40},
			},
		}
	)
	var battle := {
		"round": 1,
		"distance": 0,
		"stacks": [
			_stack("player_line", "player", "Report Line", 5, 10, 38, [
				SpellRules.build_battle_effect(
					"status_harried",
					"Harried",
					{"defense": -1, "cohesion": -2},
					2,
					{"round": 1},
					"test",
					"seed_harried"
				),
			]),
			_stack("enemy_fresh", "enemy", "Fresh Target", 8, 10, 80, []),
			_stack("enemy_wounded", "enemy", "Wounded Target", 8, 10, 32, []),
		],
	}
	var active := _stack_by_id(battle, "player_line")
	var fresh_target := _stack_by_id(battle, "enemy_fresh")
	var wounded_target := _stack_by_id(battle, "enemy_wounded")

	var actions := SpellRules.get_battle_actions(hero, battle, active, fresh_target)
	if not _assert_public_spell_actions(actions):
		return

	var fresh_burst := SpellRules.resolve_battle_spell(hero, battle, active, fresh_target, "spell_cinder_burst")
	var wounded_burst := SpellRules.resolve_battle_spell(hero, battle, active, wounded_target, "spell_cinder_burst")
	if not bool(fresh_burst.get("ok", false)) or not bool(wounded_burst.get("ok", false)):
		_fail("Priority damage resolution failed: fresh=%s wounded=%s" % [fresh_burst, wounded_burst])
		return
	if int(wounded_burst.get("damage", 0)) <= int(fresh_burst.get("damage", 0)):
		_fail("Cinder Burst did not apply a wounded-target priority bonus.")
		return

	var control := SpellRules.resolve_battle_spell(hero, battle, active, fresh_target, "spell_briar_bind")
	if not bool(control.get("ok", false)) or String(control.get("resolution_type", "")) != "effect":
		_fail("Briar Bind did not resolve as an enemy control effect: %s" % control)
		return
	BattleRules._apply_stack_effect(battle, "enemy_fresh", control.get("effect", {}))
	if not SpellRules.has_effect_id(_stack_by_id(battle, "enemy_fresh"), battle, "status_rooted"):
		_fail("Briar Bind control effect was not applied through the battle effect hook.")
		return

	var recover := SpellRules.resolve_battle_spell(hero, battle, active, {}, "spell_graft_mend")
	if not bool(recover.get("ok", false)) or String(recover.get("resolution_type", "")) != "recover_effect":
		_fail("Graft Mend did not resolve as a recovery effect: %s" % recover)
		return
	var restored := BattleRules._restore_stack_health(battle, "player_line", int(recover.get("recovery_amount", 0)))
	if restored <= 0:
		_fail("Graft Mend recovery hook did not restore stack health.")
		return
	if recover.get("effect", {}) is Dictionary and not recover.get("effect", {}).is_empty():
		BattleRules._apply_stack_effect(battle, "player_line", recover.get("effect", {}))
	if not SpellRules.has_effect_id(_stack_by_id(battle, "player_line"), battle, "spell:spell_graft_mend:recover_ally"):
		_fail("Graft Mend ward effect was not applied after recovery.")
		return

	var cleanse := SpellRules.resolve_battle_spell(hero, battle, _stack_by_id(battle, "player_line"), {}, "spell_prism_bastion")
	if not bool(cleanse.get("ok", false)) or String(cleanse.get("resolution_type", "")) != "cleanse_effect":
		_fail("Prism Bastion did not resolve as a cleanse effect: %s" % cleanse)
		return
	var cleansed := BattleRules._cleanse_stack_effects(battle, "player_line", cleanse.get("cleanse_effect_ids", []))
	if cleansed <= 0 or SpellRules.has_effect_id(_stack_by_id(battle, "player_line"), battle, "status_harried"):
		_fail("Prism Bastion cleanse hook did not clear Harried.")
		return
	if cleanse.get("effect", {}) is Dictionary and not cleanse.get("effect", {}).is_empty():
		BattleRules._apply_stack_effect(battle, "player_line", cleanse.get("effect", {}))
	if not SpellRules.has_effect_id(_stack_by_id(battle, "player_line"), battle, "spell:spell_prism_bastion:cleanse_ally"):
		_fail("Prism Bastion ward effect was not applied after cleanse.")
		return

	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"schema_status": report.get("schema_status", ""),
		"effect_type_counts": report.get("effect_type_counts", {}),
		"runtime_hook_counts": report.get("runtime_hook_counts", {}),
		"cases": {
			"priority_damage": {
				"spell_id": "spell_cinder_burst",
				"fresh_damage": int(fresh_burst.get("damage", 0)),
				"wounded_damage": int(wounded_burst.get("damage", 0)),
			},
			"control": {
				"spell_id": "spell_briar_bind",
				"effect_id": "status_rooted",
			},
			"recovery": {
				"spell_id": "spell_graft_mend",
				"restored_health": restored,
			},
			"countermagic": {
				"spell_id": "spell_prism_bastion",
				"cleansed_effects": cleansed,
			},
		},
		"caveats": [
			"This report proves bounded battle spell behavior through SpellRules resolution and BattleRules effect hooks; it does not add adventure-map magic, artifacts, rare-resource costs, animation, or save migration.",
		],
	}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _stack(
	battle_id: String,
	side: String,
	name: String,
	count: int,
	unit_hp: int,
	total_health: int,
	effects: Array
) -> Dictionary:
	return {
		"battle_id": battle_id,
		"side": side,
		"name": name,
		"count": count,
		"base_count": count,
		"unit_hp": unit_hp,
		"total_health": total_health,
		"attack": 4,
		"defense": 4,
		"initiative": 5,
		"cohesion": 5,
		"momentum": 0,
		"effects": effects,
	}

func _stack_by_id(battle: Dictionary, battle_id: String) -> Dictionary:
	for stack in battle.get("stacks", []):
		if stack is Dictionary and String(stack.get("battle_id", "")) == battle_id:
			return stack
	return {}

func _assert_public_spell_actions(actions: Array) -> bool:
	var required_ids := [
		"cast_spell:spell_cinder_burst",
		"cast_spell:spell_briar_bind",
		"cast_spell:spell_graft_mend",
		"cast_spell:spell_prism_bastion",
	]
	var surface_text := ""
	for action in actions:
		if not (action is Dictionary):
			continue
		surface_text += JSON.stringify(action).to_lower()
		required_ids.erase(String(action.get("id", "")))
	if not required_ids.is_empty():
		_fail("Missing spell action ids: %s" % required_ids)
		return false
	for leak_token in ["debug", "score", "internal"]:
		if surface_text.contains(leak_token):
			_fail("Public spell action surface leaked %s: %s" % [leak_token, surface_text])
			return false
	return true

func _fail(message: String) -> void:
	var payload := {"ok": false, "report_id": REPORT_ID, "error": message}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(1)
