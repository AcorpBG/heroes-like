extends Node

const REPORT_ID := "MAGIC_AI_VALUATION_CASTING_HOOKS_REPORT"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var battle_case := _run_battle_ai_spell_case()
	if not bool(battle_case.get("ok", false)):
		_fail(String(battle_case.get("error", "Battle AI spell valuation case failed.")))
		return

	var adventure_case := _run_adventure_ai_spell_case()
	if not bool(adventure_case.get("ok", false)):
		_fail(String(adventure_case.get("error", "Adventure AI spell valuation case failed.")))
		return

	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"battle": battle_case,
		"adventure": adventure_case,
		"caveats": [
			"This report proves bounded AI spell valuation and the existing battle casting decision hook only. Enemy adventure spell execution remains valuation-only until a safe strategic map casting executor exists.",
		],
	}
	if not _assert_public_payload("final report", payload):
		return
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _run_battle_ai_spell_case() -> Dictionary:
	var enemy_hero := SpellRules.ensure_hero_spellbook(
		{
			"name": "Enemy Report Caster",
			"command": {"power": 2, "knowledge": 8},
			"spellbook": {
				"known_spell_ids": [
					"spell_cinder_burst",
					"spell_briar_bind",
					"spell_graft_mend",
					"spell_prism_bastion",
					"spell_lantern_phalanx",
				],
				"mana": {"current": 40, "max": 40},
			},
		}
	)
	var battle := {
		"round": 2,
		"distance": 0,
		"terrain": "mire",
		"tags": ["bog_channels", "ritual_pylon"],
		"stacks": [
			_stack("enemy_line", "enemy", "Enemy Line", 7, 10, 36, [
				SpellRules.build_battle_effect(
					"status_harried",
					"Harried",
					{"defense": -1, "cohesion": -2},
					2,
					{"round": 2},
					"test",
					"seed_harried"
				),
			]),
			_stack("player_fresh", "player", "Player Fresh", 8, 10, 80, []),
			_stack("player_wounded", "player", "Player Wounded", 8, 10, 31, []),
		],
	}
	var active := _stack_by_id(battle, "enemy_line")
	var report := BattleAiRules.battle_spell_choice_report(battle, active, enemy_hero)
	if not bool(report.get("ok", false)):
		return {"ok": false, "error": "Battle AI report failed: %s" % report}
	if not _assert_public_payload("battle AI report", report):
		return {"ok": false, "error": "Battle AI report leaked non-public fields."}
	for required_effect in ["damage_enemy", "control_enemy", "recover_ally", "cleanse_ally", "attack_buff"]:
		if int(report.get("effect_type_counts", {}).get(required_effect, 0)) <= 0:
			return {"ok": false, "error": "Battle AI report missed %s candidate coverage: %s" % [required_effect, report]}
	for required_hook in ["battle_damage", "enemy_status_control", "ally_health_recovery", "ally_status_cleanse", "ally_status_effect"]:
		if int(report.get("runtime_hook_counts", {}).get(required_hook, 0)) <= 0:
			return {"ok": false, "error": "Battle AI report missed %s hook coverage: %s" % [required_hook, report]}
	var selected: Dictionary = report.get("selected", {}) if report.get("selected", {}) is Dictionary else {}
	if String(selected.get("action", "")) != "cast_spell" or String(selected.get("spell_id", "")) == "":
		return {"ok": false, "error": "Battle AI report did not select a spell action: %s" % report}
	var live_action := BattleAiRules.choose_enemy_action(battle, active, enemy_hero)
	if String(live_action.get("action", "")) != "cast_spell":
		return {"ok": false, "error": "Live enemy choice did not use the bounded battle casting hook: %s" % live_action}
	if String(live_action.get("spell_id", "")) != String(selected.get("spell_id", "")):
		return {"ok": false, "error": "Public report and live choice selected different spells: report=%s live=%s" % [selected, live_action]}
	return {
		"ok": true,
		"report_status": String(report.get("report_status", "")),
		"candidate_count": int(report.get("candidate_count", 0)),
		"selected_spell_id": String(selected.get("spell_id", "")),
		"selected_effect_type": String(selected.get("effect_type", "")),
		"effect_type_counts": report.get("effect_type_counts", {}),
		"runtime_hook_counts": report.get("runtime_hook_counts", {}),
	}

func _run_adventure_ai_spell_case() -> Dictionary:
	var hero := SpellRules.ensure_hero_spellbook(
		{
			"id": "enemy_route_caster",
			"name": "Enemy Route Caster",
			"command": {"power": 1, "knowledge": 8},
			"spellbook": {
				"known_spell_ids": [
					"spell_waystride",
					"spell_trailglyph",
					"spell_beacon_path",
				],
				"mana": {"current": 40, "max": 40},
			},
		}
	)
	var movement := {"current": 2, "max": 10}
	var report := EnemyAdventureRules.adventure_spell_valuation_report(
		hero,
		movement,
		{
			"target_kind": "resource_site",
			"target_label": "Old Mill",
			"objective_steps_remaining": 7,
			"route_pressure": true,
		}
	)
	if not bool(report.get("ok", false)):
		return {"ok": false, "error": "Adventure AI report failed: %s" % report}
	if not _assert_public_payload("adventure AI report", report):
		return {"ok": false, "error": "Adventure AI report leaked non-public fields."}
	if int(report.get("candidate_count", 0)) != 3:
		return {"ok": false, "error": "Adventure AI report did not value all current movement spells: %s" % report}
	if int(report.get("runtime_hook_counts", {}).get("overworld_movement_restore", 0)) <= 0:
		return {"ok": false, "error": "Adventure AI report missed movement hook metadata: %s" % report}
	var selected: Dictionary = report.get("selected", {}) if report.get("selected", {}) is Dictionary else {}
	if String(selected.get("recommendation", "")) != "cast":
		return {"ok": false, "error": "Adventure AI did not recommend a movement spell when it reaches the target: %s" % report}
	if int(selected.get("movement_after", 0)) < 7:
		return {"ok": false, "error": "Adventure AI selected spell does not reach the target fixture: %s" % selected}
	return {
		"ok": true,
		"report_status": String(report.get("report_status", "")),
		"runtime_policy": String(report.get("runtime_policy", "")),
		"candidate_count": int(report.get("candidate_count", 0)),
		"selected_spell_id": String(selected.get("spell_id", "")),
		"selected_recommendation": String(selected.get("recommendation", "")),
		"runtime_hook_counts": report.get("runtime_hook_counts", {}),
	}

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
		"attack": 5,
		"defense": 4,
		"initiative": 5,
		"cohesion": 5,
		"momentum": 0,
		"ranged": false,
		"effects": effects,
	}

func _stack_by_id(battle: Dictionary, battle_id: String) -> Dictionary:
	for stack in battle.get("stacks", []):
		if stack is Dictionary and String(stack.get("battle_id", "")) == battle_id:
			return stack
	return {}

func _assert_public_payload(label: String, payload: Variant) -> bool:
	var surface_text := JSON.stringify(payload).to_lower()
	for leak_token in ["debug", "score", "internal"]:
		if surface_text.contains(leak_token):
			_fail("%s leaked %s: %s" % [label, leak_token, surface_text])
			return false
	return true

func _fail(message: String) -> void:
	var payload := {"ok": false, "report_id": REPORT_ID, "error": message}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(1)
