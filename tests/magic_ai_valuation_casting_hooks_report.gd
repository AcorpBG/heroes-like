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

	var adventure_case := _run_adventure_ai_spell_case()
	if not bool(adventure_case.get("ok", false)):
		_fail(String(adventure_case.get("error", "Adventure AI spell valuation case failed.")))
		return
	var adventure_tiebreak_case := _run_adventure_ai_spell_tiebreak_case()
	if not bool(adventure_tiebreak_case.get("ok", false)):
		_fail(String(adventure_tiebreak_case.get("error", "Adventure AI spell tiebreak case failed.")))
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
		"adventure": adventure_case,
		"adventure_spell_tiebreak": adventure_tiebreak_case,
		"caveats": [
			"This report proves bounded AI spell valuation, resistance-aware battle targeting, damage status-rider targeting, commander role-aware spell preference, live template-derived enemy battle spell execution, richer enemy payload spellbook merging for live battle casts, normalized rich enemy payload preservation across battle state refresh, urgent cleanse targeting through active ward modifiers, best-ally commander buff targeting, full-health and casualty-only recovery filtering, injured-survivor recovery targeting, argument-only commander payload parity for spell reports, lethal attack priority over non-lethal setup spells, lethal damage spell priority over non-lethal setup spells, the existing battle casting decision hook, same-band adventure spell tiebreaks, live enemy movement-spell execution, and live enemy scouting-spell execution for strategic raid movement.",
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
			_stack("player_payload_fragile", "player", "Player Payload Fragile", 22, 10, 220, [], {
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
	if int(target_after.get("total_health", 0)) >= 220:
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
			_stack("player_normalized_payload_target", "player", "Player Normalized Payload Target", 22, 10, 220, [], {
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
				"known_spell_ids": ["spell_lantern_phalanx"],
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
			"known_spell_ids": ["spell_lantern_phalanx"],
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
	if String(live_action.get("action", "")) != "cast_spell" or String(live_action.get("spell_id", "")) != "spell_lantern_phalanx":
		return {"ok": false, "error": "Spell report payload bridge live choice should stay aligned with report, got %s report=%s" % [live_action, bridged_report]}
	var battle_state := battle.duplicate(true)
	battle_state["enemy_hero"] = linekeeper_hero.duplicate(true)
	var battle_state_report := BattleAiRules.battle_spell_choice_report(battle_state, active, {})
	if not bool(battle_state_report.get("ok", false)):
		return {"ok": false, "error": "Battle-state enemy hero fallback report failed: %s" % battle_state_report}
	var battle_state_selected: Dictionary = battle_state_report.get("selected", {}) if battle_state_report.get("selected", {}) is Dictionary else {}
	if String(battle_state_report.get("commander_payload_source", "")) != "battle":
		return {"ok": false, "error": "Battle-state enemy hero fallback did not record battle payload source: %s" % battle_state_report}
	if String(battle_state_selected.get("spell_id", "")) != "spell_lantern_phalanx":
		return {"ok": false, "error": "Battle-state enemy hero fallback report lost the spellbook: %s" % battle_state_report}
	var battle_state_action := BattleAiRules.choose_enemy_action(battle_state, active, {})
	if String(battle_state_action.get("action", "")) != "cast_spell" or String(battle_state_action.get("spell_id", "")) != "spell_lantern_phalanx":
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
	var executor_case := _run_adventure_executor_case()
	if not bool(executor_case.get("ok", false)):
		return executor_case
	var minimal_executor_case := _run_adventure_minimal_template_executor_case()
	if not bool(minimal_executor_case.get("ok", false)):
		return minimal_executor_case
	var scouting_executor_case := _run_adventure_scouting_executor_case()
	if not bool(scouting_executor_case.get("ok", false)):
		return scouting_executor_case
	return {
		"ok": true,
		"report_status": String(report.get("report_status", "")),
		"runtime_policy": String(report.get("runtime_policy", "")),
		"candidate_count": int(report.get("candidate_count", 0)),
		"selected_spell_id": String(selected.get("spell_id", "")),
		"selected_recommendation": String(selected.get("recommendation", "")),
		"runtime_hook_counts": report.get("runtime_hook_counts", {}),
		"executor": executor_case,
		"minimal_template_executor": minimal_executor_case,
		"scouting_executor": scouting_executor_case,
	}

func _run_adventure_ai_spell_tiebreak_case() -> Dictionary:
	var movement_hero := SpellRules.ensure_hero_spellbook(
		{
			"id": "enemy_route_tiebreak_caster",
			"name": "Enemy Route Tiebreak Caster",
			"command": {"power": 1, "knowledge": 8},
			"spellbook": {
				"known_spell_ids": [
					"spell_waystride",
					"spell_beacon_path",
				],
				"mana": {"current": 40, "max": 40},
			},
		}
	)
	var movement_report := EnemyAdventureRules.adventure_spell_valuation_report(
		movement_hero,
		{"current": 1, "max": 10},
		{
			"target_kind": "resource_site",
			"target_label": "Distant Mill",
			"objective_steps_remaining": 20,
			"route_pressure": true,
		}
	)
	if not bool(movement_report.get("ok", false)):
		return {"ok": false, "error": "Movement tiebreak report failed: %s" % movement_report}
	var movement_selected: Dictionary = movement_report.get("selected", {}) if movement_report.get("selected", {}) is Dictionary else {}
	if String(movement_selected.get("spell_id", "")) != "spell_beacon_path":
		return {"ok": false, "error": "Movement tiebreak should select higher movement_after spell_beacon_path, got %s candidates=%s" % [movement_selected, movement_report.get("candidates", [])]}

	var scouting_hero := SpellRules.ensure_hero_spellbook(
		{
			"id": "enemy_scout_tiebreak_caster",
			"name": "Enemy Scout Tiebreak Caster",
			"command": {"power": 1, "knowledge": 8},
			"spellbook": {
				"known_spell_ids": [
					"spell_survey_chain",
					"spell_mire_flood_fenlight_12",
				],
				"mana": {"current": 40, "max": 40},
			},
		}
	)
	var scouting_report := EnemyAdventureRules.adventure_spell_valuation_report(
		scouting_hero,
		{"current": 1, "max": 1},
		{
			"target_kind": "scouting",
			"target_label": "nearby targets",
			"scouting_pressure": true,
			"hidden_site_reveal": true,
			"unscouted_target_count": 2,
		}
	)
	if not bool(scouting_report.get("ok", false)):
		return {"ok": false, "error": "Scouting tiebreak report failed: %s" % scouting_report}
	var scouting_selected: Dictionary = scouting_report.get("selected", {}) if scouting_report.get("selected", {}) is Dictionary else {}
	if String(scouting_selected.get("spell_id", "")) != "spell_mire_flood_fenlight_12":
		return {"ok": false, "error": "Scouting tiebreak should select larger reveal spell_mire_flood_fenlight_12, got %s candidates=%s" % [scouting_selected, scouting_report.get("candidates", [])]}

	return {
		"ok": true,
		"movement_selected_spell_id": String(movement_selected.get("spell_id", "")),
		"movement_before": int(movement_selected.get("movement_before", 0)),
		"movement_after": int(movement_selected.get("movement_after", 0)),
		"movement_value_band": String(movement_selected.get("value_band", "")),
		"scouting_selected_spell_id": String(scouting_selected.get("spell_id", "")),
		"scouting_reveal_radius": int(scouting_selected.get("reveal_radius", 0)),
		"scouting_value_band": String(scouting_selected.get("value_band", "")),
	}

func _run_adventure_executor_case() -> Dictionary:
	var session = ScenarioFactory.create_session(
		"river-pass",
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	OverworldRules.normalize_overworld_state(session)
	OverworldRules.refresh_fog_of_war(session)
	EnemyTurnRules.normalize_enemy_states(session)
	session.overworld["player_heroes"] = []
	session.overworld["hero"] = {}
	var faction_id := "faction_mireclaw"
	var config := _enemy_config(session, faction_id)
	var commander := SpellRules.ensure_hero_spellbook(
		{
			"id": "enemy_commander:faction_mireclaw:hero_tarn",
			"roster_hero_id": "hero_tarn",
			"faction_id": faction_id,
			"name": "Tarn Mireglass",
			"command": {"power": 1, "knowledge": 8},
			"spellbook": {
				"known_spell_ids": ["spell_trailglyph"],
				"mana": {"current": 12, "max": 12},
			},
		}
	)
	var raid := EnemyAdventureRules.ensure_raid_army(
		{
			"placement_id": "adventure_spell_executor_raid",
			"encounter_id": "encounter_mire_raid",
			"x": 4,
			"y": 0,
			"difficulty": "pressure",
			"combat_seed": 44004,
			"spawned_by_faction_id": faction_id,
			"days_active": 0,
			"arrived": false,
			"goal_distance": 9999,
			"target_kind": "resource",
			"target_placement_id": "midway_shrine",
			"target_label": "Midway Shrine",
			"target_x": 4,
			"target_y": 2,
			"enemy_army": {
				"id": "adventure_spell_executor_raid",
				"name": "Executor Spell Raid",
				"stacks": [{"unit_id": "unit_blackbranch_cutthroat", "count": 12}],
			},
			"enemy_commander_state": commander,
		},
		session
	)
	session.overworld["encounters"] = [raid]
	var result := EnemyAdventureRules.advance_raids(session, config, faction_id, _enemy_state(session, faction_id))
	var after_raid := _encounter(session, "adventure_spell_executor_raid")
	if after_raid.is_empty():
		return {"ok": false, "error": "Adventure spell executor raid disappeared."}
	if int(after_raid.get("x", 0)) != 4 or int(after_raid.get("y", 0)) != 2:
		return {"ok": false, "error": "Adventure spell executor did not move the raid to the resource target: %s" % after_raid}
	if String(after_raid.get("last_adventure_spell_id", "")) != "spell_trailglyph":
		return {"ok": false, "error": "Adventure spell executor did not record the cast spell: %s" % after_raid}
	var mana: Dictionary = after_raid.get("enemy_commander_state", {}).get("spellbook", {}).get("mana", {})
	if int(mana.get("current", 0)) >= 12:
		return {"ok": false, "error": "Adventure spell executor did not spend commander mana: %s" % mana}
	var roster_entry := _enemy_roster_entry(session, faction_id, "hero_tarn")
	if roster_entry.is_empty():
		return {"ok": false, "error": "Adventure spell executor did not keep Tarn in commander roster."}
	if String(roster_entry.get("status", "")) != "active" or String(roster_entry.get("active_placement_id", "")) != "adventure_spell_executor_raid":
		return {"ok": false, "error": "Adventure spell executor did not preserve active roster assignment: %s" % roster_entry}
	var roster_commander: Dictionary = roster_entry.get("commander_state", {}) if roster_entry.get("commander_state", {}) is Dictionary else {}
	var roster_spellbook: Dictionary = roster_commander.get("spellbook", {}) if roster_commander.get("spellbook", {}) is Dictionary else {}
	var roster_mana: Dictionary = roster_spellbook.get("mana", {}) if roster_spellbook.get("mana", {}) is Dictionary else {}
	if int(roster_mana.get("current", -1)) != int(mana.get("current", -2)):
		return {"ok": false, "error": "Adventure spell executor did not sync spent mana to commander roster: raid=%s roster=%s" % [mana, roster_mana]}
	var event_types := _event_types(result.get("events", []))
	if "ai_adventure_spell_cast" not in event_types:
		return {"ok": false, "error": "Adventure spell executor did not emit ai_adventure_spell_cast: %s" % result}
	var public_log := EnemyAdventureRules.ai_public_event_log_boundary_report(result.get("events", []), 8)
	if not bool(public_log.get("ok", false)):
		return {"ok": false, "error": "Adventure spell public event boundary failed: %s" % public_log}
	if not _assert_public_payload("adventure spell executor public events", public_log.get("public_events", [])):
		return {"ok": false, "error": "Adventure spell executor public events leaked non-public fields."}
	return {
		"ok": true,
		"spell_id": String(after_raid.get("last_adventure_spell_id", "")),
		"movement_steps": int(after_raid.get("last_adventure_spell_movement_steps", 0)),
		"final_x": int(after_raid.get("x", 0)),
		"final_y": int(after_raid.get("y", 0)),
		"mana_after": int(mana.get("current", 0)),
		"roster_mana_after": int(roster_mana.get("current", 0)),
		"event_types": event_types,
	}

func _run_adventure_minimal_template_executor_case() -> Dictionary:
	var session = ScenarioFactory.create_session(
		"river-pass",
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	OverworldRules.normalize_overworld_state(session)
	OverworldRules.refresh_fog_of_war(session)
	EnemyTurnRules.normalize_enemy_states(session)
	session.overworld["player_heroes"] = []
	session.overworld["hero"] = {}
	var faction_id := "faction_mireclaw"
	var config := _enemy_config(session, faction_id)
	var minimal_commander := {
		"roster_hero_id": "hero_tarn",
		"faction_id": faction_id,
	}
	var movement_report := EnemyAdventureRules.adventure_spell_valuation_report(
		minimal_commander,
		{"current": 2, "max": 10},
		{
			"target_kind": "resource",
			"target_label": "Midway Shrine",
			"objective_steps_remaining": 5,
			"route_pressure": true,
		}
	)
	if not bool(movement_report.get("ok", false)):
		return {"ok": false, "error": "Minimal adventure spell valuation report failed: %s" % movement_report}
	var selected: Dictionary = movement_report.get("selected", {}) if movement_report.get("selected", {}) is Dictionary else {}
	if String(selected.get("spell_id", "")) != "spell_trailglyph":
		return {"ok": false, "error": "Minimal Tarn should inherit Trailglyph from template, got %s report=%s" % [selected, movement_report]}
	var raid := EnemyAdventureRules.ensure_raid_army(
		{
			"placement_id": "adventure_spell_minimal_template_raid",
			"encounter_id": "encounter_mire_raid",
			"x": 4,
			"y": 0,
			"difficulty": "pressure",
			"combat_seed": 44006,
			"spawned_by_faction_id": faction_id,
			"days_active": 0,
			"arrived": false,
			"goal_distance": 9999,
			"target_kind": "resource",
			"target_placement_id": "midway_shrine",
			"target_label": "Midway Shrine",
			"target_x": 4,
			"target_y": 2,
			"enemy_army": {
				"id": "adventure_spell_minimal_template_raid",
				"name": "Minimal Template Spell Raid",
				"stacks": [{"unit_id": "unit_blackbranch_cutthroat", "count": 12}],
			},
			"enemy_commander_state": minimal_commander,
		},
		session
	)
	session.overworld["encounters"] = [raid]
	var result := EnemyAdventureRules.advance_raids(session, config, faction_id, _enemy_state(session, faction_id))
	var after_raid := _encounter(session, "adventure_spell_minimal_template_raid")
	if after_raid.is_empty():
		return {"ok": false, "error": "Minimal adventure spell executor raid disappeared."}
	if int(after_raid.get("x", 0)) != 4 or int(after_raid.get("y", 0)) != 2:
		return {"ok": false, "error": "Minimal adventure spell executor did not move to target: %s" % after_raid}
	if String(after_raid.get("last_adventure_spell_id", "")) != "spell_trailglyph":
		return {"ok": false, "error": "Minimal adventure spell executor did not cast inherited Trailglyph: %s" % after_raid}
	var commander_state: Dictionary = after_raid.get("enemy_commander_state", {}) if after_raid.get("enemy_commander_state", {}) is Dictionary else {}
	var spellbook: Dictionary = commander_state.get("spellbook", {}) if commander_state.get("spellbook", {}) is Dictionary else {}
	var known_spell_ids: Array = spellbook.get("known_spell_ids", []) if spellbook.get("known_spell_ids", []) is Array else []
	if "spell_trailglyph" not in known_spell_ids:
		return {"ok": false, "error": "Minimal adventure spell executor did not persist inherited spellbook after cast: %s" % commander_state}
	var mana: Dictionary = spellbook.get("mana", {}) if spellbook.get("mana", {}) is Dictionary else {}
	if int(mana.get("current", 0)) >= int(mana.get("max", 0)):
		return {"ok": false, "error": "Minimal adventure spell executor did not spend template-derived mana: %s" % mana}
	var roster_entry := _enemy_roster_entry(session, faction_id, "hero_tarn")
	var roster_commander: Dictionary = roster_entry.get("commander_state", {}) if roster_entry.get("commander_state", {}) is Dictionary else {}
	var roster_spellbook: Dictionary = roster_commander.get("spellbook", {}) if roster_commander.get("spellbook", {}) is Dictionary else {}
	var roster_mana: Dictionary = roster_spellbook.get("mana", {}) if roster_spellbook.get("mana", {}) is Dictionary else {}
	if int(roster_mana.get("current", -1)) != int(mana.get("current", -2)):
		return {"ok": false, "error": "Minimal adventure spell executor did not sync template-derived mana to commander roster: raid=%s roster=%s" % [mana, roster_mana]}
	var event_types := _event_types(result.get("events", []))
	if "ai_adventure_spell_cast" not in event_types:
		return {"ok": false, "error": "Minimal adventure spell executor did not emit ai_adventure_spell_cast: %s" % result}
	return {
		"ok": true,
		"selected_spell_id": String(selected.get("spell_id", "")),
		"spell_id": String(after_raid.get("last_adventure_spell_id", "")),
		"movement_steps": int(after_raid.get("last_adventure_spell_movement_steps", 0)),
		"mana_after": int(mana.get("current", 0)),
		"roster_mana_after": int(roster_mana.get("current", 0)),
		"known_spell_count": known_spell_ids.size(),
		"event_types": event_types,
	}

func _run_adventure_scouting_executor_case() -> Dictionary:
	var session = ScenarioFactory.create_session(
		"river-pass",
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	OverworldRules.normalize_overworld_state(session)
	OverworldRules.refresh_fog_of_war(session)
	EnemyTurnRules.normalize_enemy_states(session)
	var faction_id := "faction_mireclaw"
	var config := _enemy_config(session, faction_id)
	session.overworld["towns"] = []
	session.overworld["artifact_nodes"] = []
	session.overworld["resource_nodes"] = [
		{"placement_id": "midway_shrine", "site_id": "site_riverwatch_free_company_yard", "x": 4, "y": 2, "collected_by_faction_id": "player"},
		{"placement_id": "southern_ore", "site_id": "site_ore_crates", "x": 8, "y": 4},
	]
	var commander := SpellRules.ensure_hero_spellbook(
		{
			"id": "enemy_commander:faction_mireclaw:hero_tarn",
			"roster_hero_id": "hero_tarn",
			"faction_id": faction_id,
			"name": "Tarn Mireglass",
			"command": {"power": 1, "knowledge": 8},
			"spellbook": {
				"known_spell_ids": ["spell_survey_chain"],
				"mana": {"current": 16, "max": 16},
			},
		}
	)
	var raid := EnemyAdventureRules.ensure_raid_army(
		{
			"placement_id": "adventure_spell_scouting_raid",
			"encounter_id": "encounter_mire_raid",
			"x": 4,
			"y": 0,
			"difficulty": "pressure",
			"combat_seed": 44005,
			"spawned_by_faction_id": faction_id,
			"days_active": 0,
			"arrived": false,
			"goal_distance": 9999,
			"enemy_army": {
				"id": "adventure_spell_scouting_raid",
				"name": "Scouting Spell Raid",
				"stacks": [{"unit_id": "unit_blackbranch_cutthroat", "count": 12}],
			},
			"enemy_commander_state": commander,
		},
		session
	)
	session.overworld["encounters"] = [raid]
	var result := EnemyAdventureRules.advance_raids(session, config, faction_id, _enemy_state(session, faction_id))
	var after_raid := _encounter(session, "adventure_spell_scouting_raid")
	if after_raid.is_empty():
		return {"ok": false, "error": "Adventure scouting spell raid disappeared."}
	if String(after_raid.get("last_adventure_scout_spell_id", "")) != "spell_survey_chain":
		return {"ok": false, "error": "Adventure scouting executor did not record Survey Chain: %s" % after_raid}
	if int(after_raid.get("last_adventure_scouted_target_count", 0)) <= 0:
		return {"ok": false, "error": "Adventure scouting executor did not record any scouted targets: %s" % after_raid}
	var mana: Dictionary = after_raid.get("enemy_commander_state", {}).get("spellbook", {}).get("mana", {})
	if int(mana.get("current", 0)) >= 16:
		return {"ok": false, "error": "Adventure scouting executor did not spend commander mana: %s" % mana}
	var roster_entry := _enemy_roster_entry(session, faction_id, "hero_tarn")
	if roster_entry.is_empty():
		return {"ok": false, "error": "Adventure scouting executor did not keep Tarn in commander roster."}
	if String(roster_entry.get("status", "")) != "active" or String(roster_entry.get("active_placement_id", "")) != "adventure_spell_scouting_raid":
		return {"ok": false, "error": "Adventure scouting executor did not preserve active roster assignment: %s" % roster_entry}
	var roster_commander: Dictionary = roster_entry.get("commander_state", {}) if roster_entry.get("commander_state", {}) is Dictionary else {}
	var roster_spellbook: Dictionary = roster_commander.get("spellbook", {}) if roster_commander.get("spellbook", {}) is Dictionary else {}
	var roster_mana: Dictionary = roster_spellbook.get("mana", {}) if roster_spellbook.get("mana", {}) is Dictionary else {}
	if int(roster_mana.get("current", -1)) != int(mana.get("current", -2)):
		return {"ok": false, "error": "Adventure scouting executor did not sync spent mana to commander roster: raid=%s roster=%s" % [mana, roster_mana]}
	var memory := _enemy_known_world_memory(session, faction_id)
	var scouted_target_ids := _scouted_target_ids(memory)
	if "resource:midway_shrine" not in scouted_target_ids:
		return {"ok": false, "error": "Adventure scouting memory did not record midway_shrine: %s" % memory}
	if String(after_raid.get("target_placement_id", "")) != "midway_shrine":
		return {"ok": false, "error": "Adventure scouting did not bias target selection toward the revealed shrine: %s" % after_raid}
	if "enemy_scouting" not in after_raid.get("target_reason_codes", []):
		return {"ok": false, "error": "Adventure scouting target did not carry enemy_scouting reason code: %s" % after_raid}
	var event_types := _event_types(result.get("events", []))
	if "ai_adventure_spell_cast" not in event_types:
		return {"ok": false, "error": "Adventure scouting executor did not emit ai_adventure_spell_cast: %s" % result}
	var public_log := EnemyAdventureRules.ai_public_event_log_boundary_report(result.get("events", []), 8)
	if not bool(public_log.get("ok", false)):
		return {"ok": false, "error": "Adventure scouting public event boundary failed: %s" % public_log}
	if not _assert_public_payload("adventure scouting public events", public_log.get("public_events", [])):
		return {"ok": false, "error": "Adventure scouting public events leaked non-public fields."}
	return {
		"ok": true,
		"spell_id": String(after_raid.get("last_adventure_scout_spell_id", "")),
		"scouted_target_count": int(after_raid.get("last_adventure_scouted_target_count", 0)),
		"selected_target_id": String(after_raid.get("target_placement_id", "")),
		"mana_after": int(mana.get("current", 0)),
		"roster_mana_after": int(roster_mana.get("current", 0)),
		"memory_target_ids": scouted_target_ids,
		"event_types": event_types,
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

func _enemy_config(session, faction_id: String) -> Dictionary:
	var scenario := ContentService.get_scenario(String(session.scenario_id))
	for config in scenario.get("enemy_factions", []):
		if config is Dictionary and String(config.get("faction_id", "")) == faction_id:
			return config
	return {"faction_id": faction_id, "label": faction_id}

func _enemy_state(session, faction_id: String) -> Dictionary:
	for state in session.overworld.get("enemy_states", []):
		if state is Dictionary and String(state.get("faction_id", "")) == faction_id:
			return state
	return {"faction_id": faction_id}

func _enemy_roster_entry(session, faction_id: String, roster_hero_id: String) -> Dictionary:
	for state in session.overworld.get("enemy_states", []):
		if not (state is Dictionary) or String(state.get("faction_id", "")) != faction_id:
			continue
		for entry in state.get("commander_roster", []):
			if entry is Dictionary and String(entry.get("roster_hero_id", "")) == roster_hero_id:
				return entry
	return {}

func _encounter(session, placement_id: String) -> Dictionary:
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary and String(encounter.get("placement_id", "")) == placement_id:
			return encounter
	return {}

func _enemy_known_world_memory(session, faction_id: String) -> Dictionary:
	for state in session.overworld.get("enemy_states", []):
		if state is Dictionary and String(state.get("faction_id", "")) == faction_id:
			return state.get("known_world_memory", {}) if state.get("known_world_memory", {}) is Dictionary else {}
	return {}

func _scouted_target_ids(memory: Dictionary) -> Array:
	var ids := []
	for record in memory.get("scouted_targets", []):
		if not (record is Dictionary):
			continue
		var key := "%s:%s" % [String(record.get("target_kind", "")), String(record.get("target_id", ""))]
		if key != ":" and key not in ids:
			ids.append(key)
	ids.sort()
	return ids

func _event_types(events: Variant) -> Array:
	var types := []
	if not (events is Array):
		return types
	for event in events:
		if event is Dictionary:
			var event_type := String(event.get("event_type", ""))
			if event_type != "" and event_type not in types:
				types.append(event_type)
	types.sort()
	return types

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
