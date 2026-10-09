extends Node

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "MAGIC_AI_VALUATION_CASTING_HOOKS_REPORT"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var battle_case := _run_battle_ai_spell_case()
	if not bool(battle_case.get("ok", false)):
		_fail(String(battle_case.get("error", "Battle AI spell valuation case failed.")))
		return
	var resistance_case := _run_battle_ai_resistance_targeting_case()
	if not bool(resistance_case.get("ok", false)):
		_fail(String(resistance_case.get("error", "Battle AI resistance targeting case failed.")))
		return
	var damage_status_case := _run_battle_ai_damage_status_targeting_case()
	if not bool(damage_status_case.get("ok", false)):
		_fail(String(damage_status_case.get("error", "Battle AI damage status targeting case failed.")))
		return
	var commander_role_case := _run_battle_ai_commander_role_spell_case()
	if not bool(commander_role_case.get("ok", false)):
		_fail(String(commander_role_case.get("error", "Battle AI commander role spell case failed.")))
		return
	var live_template_cast_case := _run_battle_ai_live_template_spell_cast_case()
	if not bool(live_template_cast_case.get("ok", false)):
		_fail(String(live_template_cast_case.get("error", "Battle AI live template spell cast case failed.")))
		return
	var rich_payload_cast_case := _run_battle_ai_rich_payload_spellbook_cast_case()
	if not bool(rich_payload_cast_case.get("ok", false)):
		_fail(String(rich_payload_cast_case.get("error", "Battle AI rich payload spellbook cast case failed.")))
		return
	var normalized_payload_cast_case := _run_battle_ai_normalized_rich_payload_spellbook_case()
	if not bool(normalized_payload_cast_case.get("ok", false)):
		_fail(String(normalized_payload_cast_case.get("error", "Battle AI normalized rich payload spellbook case failed.")))
		return
	var cleanse_ward_case := _run_battle_ai_cleanse_active_ward_case()
	if not bool(cleanse_ward_case.get("ok", false)):
		_fail(String(cleanse_ward_case.get("error", "Battle AI cleanse active ward case failed.")))
		return
	var buff_target_case := _run_battle_ai_buff_best_ally_case()
	if not bool(buff_target_case.get("ok", false)):
		_fail(String(buff_target_case.get("error", "Battle AI buff target case failed.")))
		return
	var recovery_filter_case := _run_battle_ai_full_health_recovery_filter_case()
	if not bool(recovery_filter_case.get("ok", false)):
		_fail(String(recovery_filter_case.get("error", "Battle AI recovery target filter case failed.")))
		return
	var survivor_recovery_case := _run_battle_ai_injured_survivor_recovery_case()
	if not bool(survivor_recovery_case.get("ok", false)):
		_fail(String(survivor_recovery_case.get("error", "Battle AI survivor recovery case failed.")))
		return
	var spell_report_payload_case := _run_battle_ai_spell_report_payload_bridge_case()
	if not bool(spell_report_payload_case.get("ok", false)):
		_fail(String(spell_report_payload_case.get("error", "Battle AI spell report payload bridge case failed.")))
		return
	var lethal_priority_case := _run_battle_ai_lethal_attack_priority_case()
	if not bool(lethal_priority_case.get("ok", false)):
		_fail(String(lethal_priority_case.get("error", "Battle AI lethal priority case failed.")))
		return
	var lethal_spell_case := _run_battle_ai_lethal_spell_priority_case()
	if not bool(lethal_spell_case.get("ok", false)):
		_fail(String(lethal_spell_case.get("error", "Battle AI lethal spell priority case failed.")))
		return

	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"battle": battle_case,
		"battle_resistance_targeting": resistance_case,
		"battle_damage_status_targeting": damage_status_case,
		"battle_commander_role_spell": commander_role_case,
		"battle_live_template_spell_cast": live_template_cast_case,
		"battle_rich_payload_spellbook_cast": rich_payload_cast_case,
		"battle_normalized_rich_payload_spellbook": normalized_payload_cast_case,
		"battle_cleanse_active_ward": cleanse_ward_case,
		"battle_buff_best_ally": buff_target_case,
		"battle_full_health_recovery_filter": recovery_filter_case,
		"battle_injured_survivor_recovery": survivor_recovery_case,
		"battle_spell_report_payload_bridge": spell_report_payload_case,
		"battle_lethal_attack_priority": lethal_priority_case,
		"battle_lethal_spell_priority": lethal_spell_case,
		"caveats": [
			"This report proves bounded AI spell valuation, resistance-aware battle targeting, damage status-rider targeting, commander role-aware spell preference, live template-derived enemy battle spell execution, richer enemy payload spellbook merging for live battle casts, normalized rich enemy payload preservation across battle state refresh, urgent cleanse targeting through active ward modifiers, best-ally commander buff targeting, full-health and casualty-only recovery filtering, injured-survivor recovery targeting, argument-only commander payload parity for spell reports, lethal attack priority over non-lethal setup spells, lethal damage spell priority over non-lethal setup spells, and the existing battle casting decision hook. Computer heroes do not cast adventure spells on the map.",
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

func _run_battle_ai_resistance_targeting_case() -> Dictionary:
	var enemy_hero := SpellRules.ensure_hero_spellbook(
		{
			"name": "Enemy Resistance-Aware Caster",
			"command": {"power": 2, "knowledge": 8},
			"spellbook": {
				"known_spell_ids": ["spell_briar_bind"],
				"mana": {"current": 24, "max": 24},
			},
		}
	)
	var protected_effect := SpellRules.build_battle_effect(
		"status_staggered",
		"Staggered",
		{"attack": -1, "cohesion": -1},
		2,
		{"round": 2},
		"test",
		"seed_staggered"
	)
	var battle := {
		"round": 2,
		"distance": 2,
		"terrain": "plains",
		"tags": [],
		"stacks": [
			_stack("enemy_caster_line", "enemy", "Enemy Caster Line", 7, 10, 70, []),
			_stack("player_protected", "player", "Player Protected", 10, 10, 100, [protected_effect], {"control_resistance_pct": 80, "ranged": true, "shots_remaining": 6}),
			_stack("player_open", "player", "Player Open", 10, 10, 100, [], {"control_resistance_pct": 0, "ranged": true, "shots_remaining": 6}),
		],
	}
	var active := _stack_by_id(battle, "enemy_caster_line")
	var report := BattleAiRules.battle_spell_choice_report(battle, active, enemy_hero)
	if not bool(report.get("ok", false)):
		return {"ok": false, "error": "Resistance targeting report failed: %s" % report}
	var selected: Dictionary = report.get("selected", {}) if report.get("selected", {}) is Dictionary else {}
	if String(selected.get("target_battle_id", "")) != "player_open":
		return {"ok": false, "error": "Resistance-aware report should cast on actionable target, got %s candidates=%s" % [selected, report.get("candidates", [])]}
	var live_action := BattleAiRules.choose_enemy_action(battle, active, enemy_hero)
	if String(live_action.get("action", "")) != "cast_spell" or String(live_action.get("target_battle_id", "")) != "player_open":
		return {"ok": false, "error": "Resistance-aware live choice should cast on actionable target, got %s" % live_action}
	return {
		"ok": true,
		"selected_spell_id": String(selected.get("spell_id", "")),
		"selected_target_id": String(selected.get("target_battle_id", "")),
		"protected_target_resistance": 80,
		"protected_target_already_controlled": true,
		"live_action": String(live_action.get("action", "")),
	}

func _run_battle_ai_damage_status_targeting_case() -> Dictionary:
	var enemy_hero := SpellRules.ensure_hero_spellbook(
		{
			"name": "Enemy Damage-Rider Caster",
			"command": {"power": 2, "knowledge": 8},
			"spellbook": {
				"known_spell_ids": ["spell_obituary_mark"],
				"mana": {"current": 24, "max": 24},
			},
		}
	)
	var controlled_effect := SpellRules.build_battle_effect(
		"status_staggered",
		"Staggered",
		{"attack": -1},
		2,
		{"round": 2},
		"test",
		"seed_staggered"
	)
	var battle := {
		"round": 2,
		"distance": 2,
		"terrain": "plains",
		"tags": [],
		"stacks": [
			_stack("enemy_mark_caster", "enemy", "Enemy Mark Caster", 7, 10, 70, []),
			_stack("player_already_controlled", "player", "Player Already Controlled", 10, 10, 100, [controlled_effect]),
			_stack("player_fresh_mark_target", "player", "Player Fresh Mark Target", 10, 10, 100, []),
		],
	}
	var active := _stack_by_id(battle, "enemy_mark_caster")
	var report := BattleAiRules.battle_spell_choice_report(battle, active, enemy_hero)
	if not bool(report.get("ok", false)):
		return {"ok": false, "error": "Damage status targeting report failed: %s" % report}
	var selected: Dictionary = report.get("selected", {}) if report.get("selected", {}) is Dictionary else {}
	if String(selected.get("target_battle_id", "")) != "player_fresh_mark_target":
		return {"ok": false, "error": "Damage status-rider report should mark the fresh target, got %s candidates=%s" % [selected, report.get("candidates", [])]}
	var live_action := BattleAiRules.choose_enemy_action(battle, active, enemy_hero)
	if String(live_action.get("action", "")) != "cast_spell" or String(live_action.get("target_battle_id", "")) != "player_fresh_mark_target":
		return {"ok": false, "error": "Damage status-rider live choice should mark the fresh target, got %s" % live_action}
	return {
		"ok": true,
		"selected_spell_id": String(selected.get("spell_id", "")),
		"selected_target_id": String(selected.get("target_battle_id", "")),
		"avoided_target_id": "player_already_controlled",
		"avoided_target_already_controlled": true,
		"live_action": String(live_action.get("action", "")),
	}

func _run_battle_ai_commander_role_spell_case() -> Dictionary:
	var baseline_hero := SpellRules.ensure_hero_spellbook(
		{
			"name": "Enemy Generic Caster",
			"command_path": "might",
			"archetype": "generic",
			"command": {"power": 2, "knowledge": 8},
			"spellbook": {
				"known_spell_ids": ["spell_cinder_burst", "spell_briar_bind"],
				"mana": {"current": 24, "max": 24},
			},
		}
	)
	var hexcaller_hero := SpellRules.ensure_hero_spellbook(
		{
			"name": "Enemy Hexcaller Caster",
			"command_path": "magic",
			"archetype": "hexcaller",
			"command": {"power": 2, "knowledge": 8},
			"spellbook": {
				"known_spell_ids": ["spell_cinder_burst", "spell_briar_bind"],
				"mana": {"current": 24, "max": 24},
			},
		}
	)
	var minimal_template_hero := SpellRules.ensure_hero_spellbook(
		{
			"roster_hero_id": "hero_sable",
			"name": "Enemy Minimal Sable",
			"command": {"power": 2, "knowledge": 8},
			"spellbook": {
				"known_spell_ids": ["spell_cinder_burst", "spell_briar_bind"],
				"mana": {"current": 24, "max": 24},
			},
		}
	)
	var minimal_spellbook_template_hero := {
		"roster_hero_id": "hero_thornwake_veyra_seedseer",
	}
	var battle := {
		"round": 2,
		"distance": 2,
		"terrain": "plains",
		"tags": [],
		"stacks": [
			_stack("enemy_role_caster", "enemy", "Enemy Role Caster", 6, 10, 60, []),
			_stack("player_front", "player", "Player Front", 14, 12, 168, [], {
				"cohesion": 8,
				"ranged": true,
				"shots_remaining": 7,
			}),
		],
	}
	var active := _stack_by_id(battle, "enemy_role_caster")
	var baseline_report := BattleAiRules.battle_spell_choice_report(battle, active, baseline_hero)
	if not bool(baseline_report.get("ok", false)):
		return {"ok": false, "error": "Commander role baseline spell report failed: %s" % baseline_report}
	var hexcaller_report := BattleAiRules.battle_spell_choice_report(battle, active, hexcaller_hero)
	if not bool(hexcaller_report.get("ok", false)):
		return {"ok": false, "error": "Commander role hexcaller spell report failed: %s" % hexcaller_report}
	var minimal_template_report := BattleAiRules.battle_spell_choice_report(battle, active, minimal_template_hero)
	if not bool(minimal_template_report.get("ok", false)):
		return {"ok": false, "error": "Commander role template fallback spell report failed: %s" % minimal_template_report}
	var minimal_spellbook_report := BattleAiRules.battle_spell_choice_report(battle, active, minimal_spellbook_template_hero)
	if not bool(minimal_spellbook_report.get("ok", false)):
		return {"ok": false, "error": "Commander spellbook template fallback report failed: %s" % minimal_spellbook_report}
	var baseline_selected: Dictionary = baseline_report.get("selected", {}) if baseline_report.get("selected", {}) is Dictionary else {}
	var hexcaller_selected: Dictionary = hexcaller_report.get("selected", {}) if hexcaller_report.get("selected", {}) is Dictionary else {}
	var minimal_template_selected: Dictionary = minimal_template_report.get("selected", {}) if minimal_template_report.get("selected", {}) is Dictionary else {}
	var minimal_spellbook_selected: Dictionary = minimal_spellbook_report.get("selected", {}) if minimal_spellbook_report.get("selected", {}) is Dictionary else {}
	if String(hexcaller_selected.get("spell_id", "")) != "spell_briar_bind":
		return {"ok": false, "error": "Hexcaller commander should prefer the control spell, baseline=%s hexcaller=%s" % [baseline_report, hexcaller_report]}
	if String(minimal_template_selected.get("spell_id", "")) != "spell_briar_bind":
		return {"ok": false, "error": "Minimal Sable commander should inherit template role and prefer control spell, report=%s" % minimal_template_report}
	if String(minimal_spellbook_selected.get("spell_id", "")) != "spell_briar_bind":
		return {"ok": false, "error": "Minimal Veyra commander should inherit template spellbook and prefer control spell, report=%s" % minimal_spellbook_report}
	var live_action := BattleAiRules.choose_enemy_action(battle, active, hexcaller_hero)
	if String(live_action.get("action", "")) != "cast_spell" or String(live_action.get("spell_id", "")) != "spell_briar_bind":
		return {"ok": false, "error": "Hexcaller live choice should cast Briar Bind, got %s report=%s" % [live_action, hexcaller_report]}
	var minimal_live_action := BattleAiRules.choose_enemy_action(battle, active, minimal_template_hero)
	if String(minimal_live_action.get("action", "")) != "cast_spell" or String(minimal_live_action.get("spell_id", "")) != "spell_briar_bind":
		return {"ok": false, "error": "Minimal Sable live choice should cast Briar Bind through template role fallback, got %s report=%s" % [minimal_live_action, minimal_template_report]}
	var minimal_spellbook_live_action := BattleAiRules.choose_enemy_action(battle, active, minimal_spellbook_template_hero)
	if String(minimal_spellbook_live_action.get("action", "")) != "cast_spell" or String(minimal_spellbook_live_action.get("spell_id", "")) != "spell_briar_bind":
		return {"ok": false, "error": "Minimal Veyra live choice should cast Briar Bind through template spellbook fallback, got %s report=%s" % [minimal_spellbook_live_action, minimal_spellbook_report]}
	var battle_state := battle.duplicate(true)
	battle_state["enemy_hero"] = minimal_spellbook_template_hero.duplicate(true)
	var battle_state_spellbook_report := BattleAiRules.battle_spell_choice_report(battle_state, active, {})
	var battle_state_spellbook_selected: Dictionary = battle_state_spellbook_report.get("selected", {}) if battle_state_spellbook_report.get("selected", {}) is Dictionary else {}
	if String(battle_state_spellbook_selected.get("spell_id", "")) != "spell_briar_bind":
		return {"ok": false, "error": "Battle-state minimal Veyra should inherit template spellbook, report=%s" % battle_state_spellbook_report}
	var battle_state_spellbook_action := BattleAiRules.choose_enemy_action(battle_state, active, {})
	if String(battle_state_spellbook_action.get("action", "")) != "cast_spell" or String(battle_state_spellbook_action.get("spell_id", "")) != "spell_briar_bind":
		return {"ok": false, "error": "Battle-state minimal Veyra live choice should cast Briar Bind, got %s report=%s" % [battle_state_spellbook_action, battle_state_spellbook_report]}
	if minimal_spellbook_template_hero.has("spellbook") or battle_state.get("enemy_hero", {}).has("spellbook"):
		return {"ok": false, "error": "Minimal battle spellbook fallback mutated source commander state: argument=%s battle=%s" % [minimal_spellbook_template_hero, battle_state]}
	return {
		"ok": true,
		"baseline_selected_spell_id": String(baseline_selected.get("spell_id", "")),
		"hexcaller_selected_spell_id": String(hexcaller_selected.get("spell_id", "")),
		"template_fallback_selected_spell_id": String(minimal_template_selected.get("spell_id", "")),
		"template_spellbook_fallback_selected_spell_id": String(minimal_spellbook_selected.get("spell_id", "")),
		"hexcaller_effect_type": String(hexcaller_selected.get("effect_type", "")),
		"live_action": String(live_action.get("action", "")),
		"template_fallback_live_action": String(minimal_live_action.get("action", "")),
		"template_spellbook_fallback_live_action": String(minimal_spellbook_live_action.get("action", "")),
		"battle_state_template_spellbook_action": String(battle_state_spellbook_action.get("action", "")),
	}

func _run_battle_ai_live_template_spell_cast_case() -> Dictionary:
	var session := SessionStateStoreScript.SessionData.new(
		"battle-ai-live-template-spell-cast-report",
		"battle-ai-live-template-spell-cast-report",
		"hero_report",
		1,
		{},
		"normal",
		SessionStateStoreScript.LAUNCH_MODE_SKIRMISH
	)
	session.battle = {
		"round": 2,
		"distance": 2,
		"terrain": "forest",
		"tags": [],
		"battlefield_tags": [],
		"combat_seed": 44012,
		"stacks": [
			_stack("enemy_template_caster", "enemy", "Enemy Template Caster", 6, 10, 60, []),
			_stack("player_ranged_front", "player", "Player Ranged Front", 14, 12, 168, [], {
				"cohesion": 8,
				"ranged": true,
				"shots_remaining": 7,
			}),
		],
		"turn_order": ["enemy_template_caster", "player_ranged_front"],
		"turn_index": 0,
		"active_stack_id": "enemy_template_caster",
		"selected_target_id": "player_ranged_front",
		"recent_events": [],
		"retreat_allowed": true,
		"surrender_allowed": true,
		"enemy_hero": {"roster_hero_id": "hero_thornwake_veyra_seedseer"},
		"enemy_hero_payload": {},
		"player_commander_state": {},
		"field_objectives": [],
	}
	var active := BattleRules.get_active_stack(session.battle)
	var decision := BattleAiRules.choose_enemy_action(session.battle, active, {})
	if String(decision.get("action", "")) != "cast_spell" or String(decision.get("spell_id", "")) != "spell_briar_bind":
		return {"ok": false, "error": "Minimal Veyra live battle decision should cast Briar Bind before execution: %s" % decision}
	var result := BattleRules._cast_enemy_spell(session, active, decision)
	if not bool(result.get("ok", false)):
		return {"ok": false, "error": "Minimal Veyra live battle cast failed after template spell decision: result=%s decision=%s battle=%s" % [result, decision, session.battle]}
	var target_after := _stack_by_id(session.battle, "player_ranged_front")
	if not SpellRules.has_effect_id(target_after, session.battle, "status_rooted"):
		return {"ok": false, "error": "Minimal Veyra live battle cast did not apply Briar Bind to the target: %s" % target_after}
	var enemy_hero: Dictionary = session.battle.get("enemy_hero", {}) if session.battle.get("enemy_hero", {}) is Dictionary else {}
	var spellbook: Dictionary = enemy_hero.get("spellbook", {}) if enemy_hero.get("spellbook", {}) is Dictionary else {}
	var known_spell_ids: Array = spellbook.get("known_spell_ids", []) if spellbook.get("known_spell_ids", []) is Array else []
	if "spell_briar_bind" not in known_spell_ids:
		return {"ok": false, "error": "Minimal Veyra live battle cast did not persist inherited spellbook: %s" % enemy_hero}
	var mana: Dictionary = spellbook.get("mana", {}) if spellbook.get("mana", {}) is Dictionary else {}
	if int(mana.get("current", 0)) >= int(mana.get("max", 0)):
		return {"ok": false, "error": "Minimal Veyra live battle cast did not spend template-derived mana: %s" % mana}
	return {
		"ok": true,
		"decision_spell_id": String(decision.get("spell_id", "")),
		"result_state": String(result.get("state", "")),
		"target_effect_applied": SpellRules.has_effect_id(target_after, session.battle, "status_rooted"),
		"known_spell_count": known_spell_ids.size(),
		"mana_after": int(mana.get("current", 0)),
	}

func _run_battle_ai_rich_payload_spellbook_cast_case() -> Dictionary:
	var session := SessionStateStoreScript.SessionData.new(
		"battle-ai-rich-payload-spellbook-cast-report",
		"battle-ai-rich-payload-spellbook-cast-report",
		"hero_report",
		1,
		{},
		"normal",
		SessionStateStoreScript.LAUNCH_MODE_SKIRMISH
	)
	session.battle = {
		"round": 2,
		"distance": 2,
		"terrain": "forest",
		"tags": [],
		"battlefield_tags": [],
		"combat_seed": 44014,
		"stacks": [
			_stack("enemy_payload_caster", "enemy", "Enemy Payload Caster", 6, 10, 60, []),
			_stack("player_payload_fragile", "player", "Player Payload Fragile", 60, 10, 600, [], {
				"ranged": true,
				"shots_remaining": 5,
			}),
		],
		"turn_order": ["enemy_payload_caster", "player_payload_fragile"],
		"turn_index": 0,
		"active_stack_id": "enemy_payload_caster",
		"selected_target_id": "player_payload_fragile",
		"recent_events": [],
		"retreat_allowed": true,
		"surrender_allowed": true,
		"enemy_hero": {
			"roster_hero_id": "hero_thornwake_veyra_seedseer",
			"spellbook": {
				"known_spell_ids": [],
				"mana": {"current": 40, "max": 40},
			},
		},
		"enemy_hero_payload": {
			"roster_hero_id": "hero_thornwake_veyra_seedseer",
			"name": "Veyra Seedseer",
			"faction_id": "faction_thornwake",
			"command_path": "magic",
			"archetype": "rootoracle",
			"command": {"power": 8, "knowledge": 8},
			"battle_traits": ["bogwise", "ambusher"],
			"spellbook": {
				"known_spell_ids": ["spell_root_loam_thorn_10"],
				"mana": {"current": 40, "max": 40},
			},
		},
		"player_commander_state": {},
		"field_objectives": [],
	}
	var active := BattleRules.get_active_stack(session.battle)
	var report := BattleAiRules.battle_spell_choice_report(session.battle, active, {})
	if not bool(report.get("ok", false)):
		return {"ok": false, "error": "Rich payload spellbook report failed: %s" % report}
	var selected: Dictionary = report.get("selected", {}) if report.get("selected", {}) is Dictionary else {}
	if String(selected.get("spell_id", "")) != "spell_root_loam_thorn_10":
		return {"ok": false, "error": "Rich payload report should select learned Loam Thorn, got %s candidates=%s" % [selected, report.get("candidates", [])]}
	var decision := BattleAiRules.choose_enemy_action(session.battle, active, {})
	if String(decision.get("action", "")) != "cast_spell" or String(decision.get("spell_id", "")) != "spell_root_loam_thorn_10":
		return {"ok": false, "error": "Rich payload live decision should cast learned Loam Thorn, got %s report=%s" % [decision, report]}
	var result := BattleRules._cast_enemy_spell(session, active, decision)
	if not bool(result.get("ok", false)):
		return {"ok": false, "error": "Rich payload live battle cast failed: result=%s decision=%s battle=%s" % [result, decision, session.battle]}
	var target_after := _stack_by_id(session.battle, "player_payload_fragile")
	if int(target_after.get("total_health", 0)) >= 600:
		return {"ok": false, "error": "Rich payload Loam Thorn should damage the target, got %s" % target_after}
	var enemy_hero: Dictionary = session.battle.get("enemy_hero", {}) if session.battle.get("enemy_hero", {}) is Dictionary else {}
	var spellbook: Dictionary = enemy_hero.get("spellbook", {}) if enemy_hero.get("spellbook", {}) is Dictionary else {}
	var known_spell_ids: Array = spellbook.get("known_spell_ids", []) if spellbook.get("known_spell_ids", []) is Array else []
	if "spell_root_loam_thorn_10" not in known_spell_ids:
		return {"ok": false, "error": "Rich payload live battle cast did not persist learned payload spellbook: %s" % enemy_hero}
	var mana: Dictionary = spellbook.get("mana", {}) if spellbook.get("mana", {}) is Dictionary else {}
	if int(mana.get("current", 0)) >= 40:
		return {"ok": false, "error": "Rich payload live battle cast did not spend live enemy mana: %s" % mana}
	return {
		"ok": true,
		"selected_spell_id": String(selected.get("spell_id", "")),
		"decision_spell_id": String(decision.get("spell_id", "")),
		"result_state": String(result.get("state", "")),
		"target_remaining_health": int(target_after.get("total_health", 0)),
		"known_spell_count": known_spell_ids.size(),
		"mana_after": int(mana.get("current", 0)),
	}

func _run_battle_ai_normalized_rich_payload_spellbook_case() -> Dictionary:
	var session := SessionStateStoreScript.SessionData.new(
		"battle-ai-normalized-rich-payload-spellbook-report",
		"battle-ai-normalized-rich-payload-spellbook-report",
		"hero_report",
		1,
		{},
		"normal",
		SessionStateStoreScript.LAUNCH_MODE_SKIRMISH
	)
	session.battle = {
		"round": 2,
		"max_rounds": 99,
		"distance": 2,
		"terrain": "forest",
		"tags": [],
		"battlefield_tags": [],
		"combat_seed": 44015,
		"stacks": [
			_stack("enemy_normalized_payload_caster", "enemy", "Enemy Normalized Payload Caster", 6, 10, 60, [], {
				"unit_id": "unit_mire_slinger",
			}),
			_stack("player_normalized_payload_target", "player", "Player Normalized Payload Target", 60, 10, 600, [], {
				"unit_id": "unit_ember_archer",
				"ranged": true,
				"shots_remaining": 5,
			}),
		],
		"turn_order": ["enemy_normalized_payload_caster", "player_normalized_payload_target"],
		"turn_index": 0,
		"active_stack_id": "enemy_normalized_payload_caster",
		"selected_target_id": "player_normalized_payload_target",
		"recent_events": [],
		"retreat_allowed": true,
		"surrender_allowed": true,
		"enemy_hero": {
			"roster_hero_id": "hero_thornwake_veyra_seedseer",
		},
		"enemy_hero_payload": {
			"roster_hero_id": "hero_thornwake_veyra_seedseer",
			"name": "Veyra Seedseer",
			"faction_id": "faction_thornwake",
			"command_path": "magic",
			"archetype": "rootoracle",
			"command": {"power": 8, "knowledge": 8},
			"battle_traits": ["bogwise", "ambusher"],
			"spellbook": {
				"known_spell_ids": ["spell_root_loam_thorn_10"],
				"mana": {"current": 40, "max": 40},
			},
		},
		"player_commander_state": {},
		"field_objectives": [],
	}
	if not BattleRules.normalize_battle_state(session):
		return {"ok": false, "error": "Battle normalization unexpectedly failed."}
	var normalized_payload: Dictionary = session.battle.get("enemy_hero_payload", {}) if session.battle.get("enemy_hero_payload", {}) is Dictionary else {}
	var normalized_spellbook: Dictionary = normalized_payload.get("spellbook", {}) if normalized_payload.get("spellbook", {}) is Dictionary else {}
	var normalized_known: Array = normalized_spellbook.get("known_spell_ids", []) if normalized_spellbook.get("known_spell_ids", []) is Array else []
	if "spell_root_loam_thorn_10" not in normalized_known:
		return {"ok": false, "error": "Battle normalization dropped the rich enemy payload spellbook: %s" % normalized_payload}
	var active := BattleRules.get_active_stack(session.battle)
	var decision := BattleAiRules.choose_enemy_action(session.battle, active, {})
	if String(decision.get("action", "")) != "cast_spell" or String(decision.get("spell_id", "")) != "spell_root_loam_thorn_10":
		return {"ok": false, "error": "Normalized rich payload decision should cast learned Loam Thorn, got %s payload=%s" % [decision, normalized_payload]}
	var result := BattleRules._cast_enemy_spell(session, active, decision)
	if not bool(result.get("ok", false)):
		return {"ok": false, "error": "Normalized rich payload live cast failed: result=%s decision=%s battle=%s" % [result, decision, session.battle]}
	var enemy_hero: Dictionary = session.battle.get("enemy_hero", {}) if session.battle.get("enemy_hero", {}) is Dictionary else {}
	var enemy_spellbook: Dictionary = enemy_hero.get("spellbook", {}) if enemy_hero.get("spellbook", {}) is Dictionary else {}
	var enemy_known: Array = enemy_spellbook.get("known_spell_ids", []) if enemy_spellbook.get("known_spell_ids", []) is Array else []
	if "spell_root_loam_thorn_10" not in enemy_known:
		return {"ok": false, "error": "Normalized rich payload live cast did not persist learned spell into enemy hero: %s" % enemy_hero}
	var mana: Dictionary = enemy_spellbook.get("mana", {}) if enemy_spellbook.get("mana", {}) is Dictionary else {}
	if int(mana.get("current", 0)) >= 40:
		return {"ok": false, "error": "Normalized rich payload live cast did not spend payload mana: %s" % mana}
	return {
		"ok": true,
		"normalized_known_spell_count": normalized_known.size(),
		"decision_spell_id": String(decision.get("spell_id", "")),
		"result_state": String(result.get("state", "")),
		"known_spell_count": enemy_known.size(),
		"mana_after": int(mana.get("current", 0)),
	}

func _run_battle_ai_cleanse_active_ward_case() -> Dictionary:
	var enemy_hero := SpellRules.ensure_hero_spellbook(
		{
			"name": "Enemy Cleanse Caster",
			"command": {"power": 2, "knowledge": 8},
			"spellbook": {
				"known_spell_ids": ["spell_prism_bastion"],
				"mana": {"current": 24, "max": 24},
			},
		}
	)
	var active_ward := SpellRules.build_battle_effect(
		"status_existing_prism_ward",
		"Existing Prism Ward",
		{"defense": 2, "cohesion": 1},
		2,
		{"round": 2},
		"test",
		"seed_existing_ward"
	)
	var staggered_effect := SpellRules.build_battle_effect(
		"status_staggered",
		"Staggered",
		{"attack": -1, "cohesion": -1},
		2,
		{"round": 2},
		"test",
		"seed_staggered"
	)
	var rooted_effect := SpellRules.build_battle_effect(
		"status_rooted",
		"Rooted",
		{"initiative": -2, "cohesion": -1},
		2,
		{"round": 2},
		"test",
		"seed_rooted"
	)
	var battle := {
		"round": 2,
		"distance": 1,
		"terrain": "plains",
		"tags": [],
		"stacks": [
			_stack("enemy_cleanse_caster", "enemy", "Enemy Cleanse Caster", 7, 10, 70, []),
			_stack("enemy_warded_staggered", "enemy", "Enemy Warded Staggered", 8, 10, 80, [active_ward, staggered_effect, rooted_effect]),
			_stack("player_pressure", "player", "Player Pressure", 8, 10, 80, []),
		],
	}
	var active := _stack_by_id(battle, "enemy_cleanse_caster")
	if not SpellRules.has_effect_id(_stack_by_id(battle, "enemy_warded_staggered"), battle, "status_rooted"):
		return {"ok": false, "error": "Cleanse active-ward fixture must carry Rooted pressure"}
	var report := BattleAiRules.battle_spell_choice_report(battle, active, enemy_hero)
	if not bool(report.get("ok", false)):
		return {"ok": false, "error": "Cleanse active-ward report failed: %s" % report}
	var selected: Dictionary = report.get("selected", {}) if report.get("selected", {}) is Dictionary else {}
	if String(selected.get("target_battle_id", "")) != "enemy_warded_staggered":
		return {"ok": false, "error": "Cleanse active-ward report should target debuffed warded ally, got %s candidates=%s" % [selected, report.get("candidates", [])]}
	var live_action := BattleAiRules.choose_enemy_action(battle, active, enemy_hero)
	if String(live_action.get("action", "")) != "cast_spell" or String(live_action.get("target_battle_id", "")) != "enemy_warded_staggered":
		return {"ok": false, "error": "Cleanse active-ward live choice should cleanse debuffed warded ally, got %s" % live_action}
	return {
		"ok": true,
		"selected_spell_id": String(selected.get("spell_id", "")),
		"selected_target_id": String(selected.get("target_battle_id", "")),
		"target_had_active_ward_modifiers": true,
		"target_had_cleanseable_status": true,
		"target_had_rooted_status": true,
		"live_action": String(live_action.get("action", "")),
	}

func _run_battle_ai_buff_best_ally_case() -> Dictionary:
	var enemy_hero := SpellRules.ensure_hero_spellbook(
		{
			"name": "Enemy Buff Caster",
			"command": {"power": 2, "knowledge": 8},
			"spellbook": {
				"known_spell_ids": ["spell_lantern_phalanx"],
				"mana": {"current": 24, "max": 24},
			},
		}
	)
	var battle := {
		"round": 2,
		"distance": 2,
		"terrain": "plains",
		"tags": ["elevated_fire", "battery_nest"],
		"stacks": [
			_stack("enemy_low_active", "enemy", "Enemy Low Active", 4, 10, 40, [], {"tier": 1, "min_damage": 1, "max_damage": 2}),
			_stack("enemy_high_value_ranged", "enemy", "Enemy High Value Ranged", 12, 10, 120, [], {
				"tier": 5,
				"min_damage": 8,
				"max_damage": 12,
				"ranged": true,
				"shots_remaining": 8,
			}),
			_stack("player_pressure", "player", "Player Pressure", 8, 10, 80, []),
		],
	}
	var active := _stack_by_id(battle, "enemy_low_active")
	var report := BattleAiRules.battle_spell_choice_report(battle, active, enemy_hero)
	if not bool(report.get("ok", false)):
		return {"ok": false, "error": "Buff best-ally report failed: %s" % report}
	var selected: Dictionary = report.get("selected", {}) if report.get("selected", {}) is Dictionary else {}
	if String(selected.get("target_battle_id", "")) != "enemy_high_value_ranged":
		return {"ok": false, "error": "Buff best-ally report should target high-value ranged ally, got %s candidates=%s" % [selected, report.get("candidates", [])]}
	var live_action := BattleAiRules.choose_enemy_action(battle, active, enemy_hero)
	if String(live_action.get("action", "")) != "cast_spell" or String(live_action.get("target_battle_id", "")) != "enemy_high_value_ranged":
		return {"ok": false, "error": "Buff best-ally live choice should buff high-value ranged ally, got %s" % live_action}
	return {
		"ok": true,
		"selected_spell_id": String(selected.get("spell_id", "")),
		"selected_target_id": String(selected.get("target_battle_id", "")),
		"active_stack_id": "enemy_low_active",
		"target_was_active_stack": false,
		"live_action": String(live_action.get("action", "")),
	}

func _run_battle_ai_full_health_recovery_filter_case() -> Dictionary:
	var enemy_hero := SpellRules.ensure_hero_spellbook(
		{
			"name": "Enemy Recovery Caster",
			"command": {"power": 2, "knowledge": 8},
			"spellbook": {
				"known_spell_ids": ["spell_graft_mend"],
				"mana": {"current": 24, "max": 24},
			},
		}
	)
	var battle := {
		"round": 2,
		"distance": 2,
		"terrain": "plains",
		"tags": [],
		"stacks": [
			_stack("enemy_recovery_archer", "enemy", "Enemy Recovery Archer", 7, 10, 70, [], {
				"ranged": true,
				"shots_remaining": 5,
				"tier": 3,
				"min_damage": 4,
				"max_damage": 6,
			}),
			_stack("enemy_full_health_line", "enemy", "Enemy Full Health Line", 8, 10, 80, []),
			_stack("enemy_casualty_only_line", "enemy", "Enemy Casualty-Only Line", 8, 10, 60, []),
			_stack("player_pressure", "player", "Player Pressure", 8, 10, 80, []),
		],
	}
	var active := _stack_by_id(battle, "enemy_recovery_archer")
	var report := BattleAiRules.battle_spell_choice_report(battle, active, enemy_hero)
	if not bool(report.get("ok", false)):
		return {"ok": false, "error": "Recovery filter report failed: %s" % report}
	if int(report.get("candidate_count", 0)) != 0:
		return {"ok": false, "error": "Recovery filter should expose no spell candidates for full-health allies, got %s" % report}
	var live_action := BattleAiRules.choose_enemy_action(battle, active, enemy_hero)
	if String(live_action.get("action", "")) == "cast_spell":
		return {"ok": false, "error": "Recovery filter live choice should not cast recovery on full-health allies, got %s" % live_action}
	return {
		"ok": true,
		"candidate_count": int(report.get("candidate_count", 0)),
		"live_action": String(live_action.get("action", "")),
		"full_health_target_filtered": true,
		"casualty_only_target_filtered": true,
	}

func _run_battle_ai_injured_survivor_recovery_case() -> Dictionary:
	var enemy_hero := SpellRules.ensure_hero_spellbook(
		{
			"name": "Enemy Survivor Recovery Caster",
			"command": {"power": 2, "knowledge": 8},
			"spellbook": {
				"known_spell_ids": ["spell_graft_mend"],
				"mana": {"current": 24, "max": 24},
			},
		}
	)
	var battle := {
		"round": 2,
		"distance": 2,
		"terrain": "plains",
		"tags": [],
		"stacks": [
			_stack("enemy_recovery_archer", "enemy", "Enemy Recovery Archer", 7, 10, 70, [], {
				"ranged": true,
				"shots_remaining": 5,
				"tier": 1,
				"min_damage": 1,
				"max_damage": 2,
			}),
			_stack("enemy_injured_survivor", "enemy", "Enemy Injured Survivor", 8, 10, 51, [], {
				"tier": 7,
				"min_damage": 14,
				"max_damage": 20,
			}),
			_stack("player_pressure", "player", "Player Pressure", 8, 10, 80, []),
		],
	}
	var active := _stack_by_id(battle, "enemy_recovery_archer")
	var report := BattleAiRules.battle_spell_choice_report(battle, active, enemy_hero)
	if not bool(report.get("ok", false)):
		return {"ok": false, "error": "Survivor recovery report failed: %s" % report}
	var selected: Dictionary = report.get("selected", {}) if report.get("selected", {}) is Dictionary else {}
	if String(selected.get("spell_id", "")) != "spell_graft_mend" or String(selected.get("target_battle_id", "")) != "enemy_injured_survivor":
		return {"ok": false, "error": "Survivor recovery should select the injured living creature, got selected=%s candidates=%s" % [selected, report.get("candidates", [])]}
	var live_action := BattleAiRules.choose_enemy_action(battle, active, enemy_hero)
	if String(live_action.get("action", "")) != "cast_spell" or String(live_action.get("target_battle_id", "")) != "enemy_injured_survivor":
		return {"ok": false, "error": "Survivor recovery live choice should cast on the injured living creature, got %s" % live_action}
	return {
		"ok": true,
		"recoverable_health": SpellRules.battle_spell_recoverable_health(_stack_by_id(battle, "enemy_injured_survivor")),
		"selected_spell_id": String(selected.get("spell_id", "")),
		"selected_target_id": String(selected.get("target_battle_id", "")),
		"live_action": String(live_action.get("action", "")),
	}

func _run_battle_ai_spell_report_payload_bridge_case() -> Dictionary:
	var linekeeper_hero := SpellRules.ensure_hero_spellbook(
		{
			"name": "Enemy Linekeeper Caster",
			"command_path": "might",
			"battle_traits": ["linekeeper"],
			"command": {"power": 2, "knowledge": 8},
			"spellbook": {
				"known_spell_ids": ["spell_bulwark_litany"],
				"mana": {"current": 24, "max": 24},
			},
		}
	)
	var battle := {
		"round": 2,
		"distance": 2,
		"terrain": "plains",
		"tags": [],
		"stacks": [
			_stack("enemy_linekeeper_active", "enemy", "Enemy Linekeeper Active", 6, 10, 60, [], {
				"tier": 3,
				"min_damage": 8,
				"max_damage": 8,
			}),
			_stack("player_pressure", "player", "Player Pressure", 8, 10, 80, []),
		],
	}
	var active := _stack_by_id(battle, "enemy_linekeeper_active")
	var unbridged_report := BattleAiRules.battle_spell_choice_report(battle, active, SpellRules.ensure_hero_spellbook({
		"name": "Enemy Untraited Caster",
		"command": {"power": 2, "knowledge": 8},
		"spellbook": {
			"known_spell_ids": ["spell_bulwark_litany"],
			"mana": {"current": 24, "max": 24},
		},
	}))
	var bridged_report := BattleAiRules.battle_spell_choice_report(battle, active, linekeeper_hero)
	if not bool(bridged_report.get("ok", false)):
		return {"ok": false, "error": "Spell report payload bridge report failed: %s" % bridged_report}
	var unbridged_selected: Dictionary = unbridged_report.get("selected", {}) if unbridged_report.get("selected", {}) is Dictionary else {}
	var bridged_selected: Dictionary = bridged_report.get("selected", {}) if bridged_report.get("selected", {}) is Dictionary else {}
	if String(unbridged_report.get("commander_payload_source", "")) != "argument" or String(bridged_report.get("commander_payload_source", "")) != "argument":
		return {"ok": false, "error": "Spell report payload bridge did not record argument payload source: unbridged=%s bridged=%s" % [unbridged_report, bridged_report]}
	var live_action := BattleAiRules.choose_enemy_action(battle, active, linekeeper_hero)
	if String(live_action.get("action", "")) != "cast_spell" or String(live_action.get("spell_id", "")) != "spell_bulwark_litany":
		return {"ok": false, "error": "Spell report payload bridge live choice should stay aligned with report, got %s report=%s" % [live_action, bridged_report]}
	var battle_state := battle.duplicate(true)
	battle_state["enemy_hero"] = linekeeper_hero.duplicate(true)
	var battle_state_report := BattleAiRules.battle_spell_choice_report(battle_state, active, {})
	if not bool(battle_state_report.get("ok", false)):
		return {"ok": false, "error": "Battle-state enemy hero fallback report failed: %s" % battle_state_report}
	var battle_state_selected: Dictionary = battle_state_report.get("selected", {}) if battle_state_report.get("selected", {}) is Dictionary else {}
	if String(battle_state_report.get("commander_payload_source", "")) != "battle":
		return {"ok": false, "error": "Battle-state enemy hero fallback did not record battle payload source: %s" % battle_state_report}
	if String(battle_state_selected.get("spell_id", "")) != "spell_bulwark_litany":
		return {"ok": false, "error": "Battle-state enemy hero fallback report lost the spellbook: %s" % battle_state_report}
	var battle_state_action := BattleAiRules.choose_enemy_action(battle_state, active, {})
	if String(battle_state_action.get("action", "")) != "cast_spell" or String(battle_state_action.get("spell_id", "")) != "spell_bulwark_litany":
		return {"ok": false, "error": "Battle-state enemy hero fallback live choice should cast the battle hero spell, got %s report=%s" % [battle_state_action, battle_state_report]}
	if battle_state.has("enemy_hero_payload"):
		return {"ok": false, "error": "Battle-state enemy hero fallback mutated the source battle: %s" % battle_state}
	if battle.has("enemy_hero_payload"):
		return {"ok": false, "error": "Spell report payload bridge mutated the source battle: %s" % battle}
	return {
		"ok": true,
		"selected_spell_id": String(bridged_selected.get("spell_id", "")),
		"commander_payload_source": String(bridged_report.get("commander_payload_source", "")),
		"battle_state_payload_source": String(battle_state_report.get("commander_payload_source", "")),
		"battle_state_selected_spell_id": String(battle_state_selected.get("spell_id", "")),
		"battle_state_live_action": String(battle_state_action.get("action", "")),
		"selected_value_band": String(bridged_selected.get("value_band", "")),
		"live_action": String(live_action.get("action", "")),
		"source_battle_mutated": battle.has("enemy_hero_payload"),
		"battle_state_source_mutated": battle_state.has("enemy_hero_payload"),
	}

func _run_battle_ai_lethal_attack_priority_case() -> Dictionary:
	var enemy_hero := SpellRules.ensure_hero_spellbook(
		{
			"name": "Enemy Lethal Priority Caster",
			"command": {"power": 2, "knowledge": 8},
			"spellbook": {
				"known_spell_ids": ["spell_lantern_phalanx"],
				"mana": {"current": 24, "max": 24},
			},
		}
	)
	var battle := {
		"round": 2,
		"distance": 2,
		"terrain": "plains",
		"tags": ["elevated_fire", "battery_nest"],
		"stacks": [
			_stack("enemy_lethal_archer", "enemy", "Enemy Lethal Archer", 4, 10, 40, [], {
				"tier": 2,
				"min_damage": 4,
				"max_damage": 4,
				"ranged": true,
				"shots_remaining": 4,
				"hex": {"q": 2, "r": 3},
			}),
			_stack("enemy_high_value_ranged", "enemy", "Enemy High Value Ranged", 14, 10, 140, [], {
				"tier": 5,
				"min_damage": 8,
				"max_damage": 12,
				"ranged": true,
				"shots_remaining": 8,
				"hex": {"q": 1, "r": 1},
			}),
			_stack("player_fragile", "player", "Player Fragile", 1, 12, 12, [], {
				"tier": 1,
				"hex": {"q": 8, "r": 3},
			}),
		],
	}
	var active := _stack_by_id(battle, "enemy_lethal_archer")
	var spell_report := BattleAiRules.battle_spell_choice_report(battle, active, enemy_hero)
	if not bool(spell_report.get("ok", false)):
		return {"ok": false, "error": "Lethal priority spell report failed: %s" % spell_report}
	var spell_selected: Dictionary = spell_report.get("selected", {}) if spell_report.get("selected", {}) is Dictionary else {}
	if String(spell_selected.get("spell_id", "")) != "spell_lantern_phalanx":
		return {"ok": false, "error": "Lethal priority fixture should expose a non-lethal setup spell candidate, got %s" % spell_report}
	var live_action := BattleAiRules.choose_enemy_action(battle, active, enemy_hero)
	if String(live_action.get("action", "")) != "shoot" or String(live_action.get("target_battle_id", "")) != "player_fragile":
		return {"ok": false, "error": "Live enemy choice should take guaranteed lethal shot instead of setup spell, got %s spell_report=%s" % [live_action, spell_report]}
	var candidate_evidence: Dictionary = live_action.get("candidate_scores", {}) if live_action.get("candidate_scores", {}) is Dictionary else {}
	if not candidate_evidence.has("cast_spell"):
		return {"ok": false, "error": "Lethal priority fixture did not keep setup spell candidate evidence: %s" % live_action}
	return {
		"ok": true,
		"selected_spell_id": String(spell_selected.get("spell_id", "")),
		"spell_target_id": String(spell_selected.get("target_battle_id", "")),
		"live_action": String(live_action.get("action", "")),
		"live_target_id": String(live_action.get("target_battle_id", "")),
		"setup_spell_candidate_present": true,
	}

func _run_battle_ai_lethal_spell_priority_case() -> Dictionary:
	var enemy_hero := SpellRules.ensure_hero_spellbook(
		{
			"name": "Enemy Lethal Spell Caster",
			"command": {"power": 2, "knowledge": 8},
			"spellbook": {
				"known_spell_ids": ["spell_cinder_burst", "spell_lantern_phalanx"],
				"mana": {"current": 24, "max": 24},
			},
		}
	)
	var battle := {
		"round": 2,
		"distance": 2,
		"terrain": "plains",
		"tags": ["elevated_fire", "battery_nest"],
		"stacks": [
			_stack("enemy_spell_caster", "enemy", "Enemy Spell Caster", 2, 10, 20, [], {
				"tier": 1,
				"min_damage": 1,
				"max_damage": 1,
				"hex": {"q": 2, "r": 3},
			}),
			_stack("enemy_high_value_ranged", "enemy", "Enemy High Value Ranged", 14, 10, 140, [], {
				"tier": 5,
				"min_damage": 8,
				"max_damage": 12,
				"ranged": true,
				"shots_remaining": 8,
				"hex": {"q": 1, "r": 1},
			}),
			_stack("player_spell_fragile", "player", "Player Spell Fragile", 2, 10, 18, [], {
				"tier": 1,
				"hex": {"q": 8, "r": 3},
			}),
		],
	}
	var active := _stack_by_id(battle, "enemy_spell_caster")
	var report := BattleAiRules.battle_spell_choice_report(battle, active, enemy_hero)
	if not bool(report.get("ok", false)):
		return {"ok": false, "error": "Lethal spell priority report failed: %s" % report}
	var selected: Dictionary = report.get("selected", {}) if report.get("selected", {}) is Dictionary else {}
	if String(selected.get("spell_id", "")) != "spell_cinder_burst" or String(selected.get("target_battle_id", "")) != "player_spell_fragile":
		return {"ok": false, "error": "Lethal spell priority should select lethal Cinder Burst over setup buff, got %s candidates=%s" % [selected, report.get("candidates", [])]}
	var live_action := BattleAiRules.choose_enemy_action(battle, active, enemy_hero)
	if String(live_action.get("action", "")) != "cast_spell" or String(live_action.get("spell_id", "")) != "spell_cinder_burst":
		return {"ok": false, "error": "Live enemy choice should cast lethal Cinder Burst, got %s" % live_action}
	return {
		"ok": true,
		"selected_spell_id": String(selected.get("spell_id", "")),
		"selected_target_id": String(selected.get("target_battle_id", "")),
		"setup_spell_available": true,
		"live_action": String(live_action.get("action", "")),
	}

func _stack(
	battle_id: String,
	side: String,
	name: String,
	count: int,
	unit_hp: int,
	total_health: int,
	effects: Array,
	extra: Dictionary = {}
) -> Dictionary:
	var stack := {
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
	for key in extra.keys():
		stack[key] = extra[key]
	return stack

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
