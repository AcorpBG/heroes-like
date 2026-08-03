extends Node

const BattleAutoplayBalanceHarnessRulesScript = preload("res://scripts/core/BattleAutoplayBalanceHarnessRules.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "BATTLE_AUTOPLAY_TACTICAL_ORDER_REPORT"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := _adjacent_ranged_session()
	var initial_availability: Dictionary = BattleRulesScript.action_availability(session.battle)
	if not bool(initial_availability.get("shoot", false)) or not bool(initial_availability.get("strike", false)):
		_fail("Fixture must expose both shoot and strike before scored autoplay selection: %s" % JSON.stringify(initial_availability))
		return

	var decision := BattleAutoplayBalanceHarnessRulesScript.player_autoplay_decision_report(session, true)
	if String(decision.get("scoring_policy", "")) != "battle_ai_nonspell_tactical_order_v1":
		_fail("Autoplay decision did not use the shared tactical score policy: %s" % JSON.stringify(decision))
		return
	if String(decision.get("action", "")) != "strike":
		_fail("Adjacent ranged fixture should choose scored melee strike over legacy shoot-first order: %s" % JSON.stringify(decision))
		return
	if String(session.battle.get("selected_target_id", "")) != "enemy_front":
		_fail("Scored autoplay decision did not apply its target selection: %s" % JSON.stringify(session.battle))
		return
	var candidate_scores: Dictionary = decision.get("candidate_scores", {}) if decision.get("candidate_scores", {}) is Dictionary else {}
	if not candidate_scores.has("strike") or not candidate_scores.has("defend") or not candidate_scores.has("advance"):
		_fail("Autoplay decision is missing candidate score evidence: %s" % JSON.stringify(decision))
		return
	var enemy_engaged_case := _validate_enemy_engaged_melee_attack()
	if not bool(enemy_engaged_case.get("ok", false)):
		return
	var decisive_attack_case := _validate_decisive_attack_pressure()
	if not bool(decisive_attack_case.get("ok", false)):
		return
	var overkill_target_case := _validate_enemy_overkill_target_discipline()
	if not bool(overkill_target_case.get("ok", false)):
		return
	var immediate_threat_case := _validate_enemy_immediate_threat_targeting()
	if not bool(immediate_threat_case.get("ok", false)):
		return
	var commander_payload_case := _validate_tactical_order_argument_commander_payload()
	if not bool(commander_payload_case.get("ok", false)):
		return
	var battle_rules_payload_fallback_case := _validate_battle_rules_commander_payload_fallback()
	if not bool(battle_rules_payload_fallback_case.get("ok", false)):
		return
	var battle_ai_payload_fallback_case := _validate_battle_ai_commander_payload_fallback()
	if not bool(battle_ai_payload_fallback_case.get("ok", false)):
		return
	var spell_tactical_order_case := _validate_player_spell_tactical_order()
	if not bool(spell_tactical_order_case.get("ok", false)):
		return
	var spell_conservation_case := _validate_player_spell_conservation()
	if not bool(spell_conservation_case.get("ok", false)):
		return

	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"policy": "shared_battle_ai_tactical_scoring_for_balance_autoplay",
		"initial_availability": initial_availability,
		"decision": decision,
		"enemy_engaged_melee": enemy_engaged_case,
		"decisive_attack_pressure": decisive_attack_case,
		"enemy_overkill_target_discipline": overkill_target_case,
		"enemy_immediate_threat_targeting": immediate_threat_case,
		"argument_commander_payload": commander_payload_case,
		"battle_rules_commander_payload_fallback": battle_rules_payload_fallback_case,
		"battle_ai_commander_payload_fallback": battle_ai_payload_fallback_case,
		"player_spell_tactical_order": spell_tactical_order_case,
		"player_spell_conservation": spell_conservation_case,
		"selected_target_id": String(session.battle.get("selected_target_id", "")),
	}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _validate_enemy_engaged_melee_attack() -> Dictionary:
	var session := _engaged_enemy_melee_session()
	var active_stack := BattleRulesScript.get_active_stack(session.battle)
	var decision := BattleAiRules.choose_enemy_action(session.battle, active_stack, {})
	if String(decision.get("action", "")) != "strike":
		_fail("Engaged enemy melee stack should strike instead of bracing into no-progress defense: %s" % JSON.stringify(decision))
		return {}
	var candidate_scores: Dictionary = decision.get("candidate_scores", {}) if decision.get("candidate_scores", {}) is Dictionary else {}
	if not candidate_scores.has("defend") or not candidate_scores.has("strike"):
		_fail("Engaged melee decision is missing defend/strike candidate evidence: %s" % JSON.stringify(decision))
		return {}
	if float(candidate_scores.get("defend", 0.0)) <= float(candidate_scores.get("strike", 0.0)):
		_fail("Engaged melee fixture must prove strike beats a higher defend score only by no-progress guard: %s" % JSON.stringify(decision))
		return {}
	var tactical_order := BattleAiRules.choose_stack_tactical_order(session.battle, active_stack, "player")
	if String(tactical_order.get("action", "")) != "strike":
		_fail("Shared tactical order should also force engaged melee strike: %s" % JSON.stringify(tactical_order))
		return {}
	return {
		"ok": true,
		"live_action": String(decision.get("action", "")),
		"live_target_id": String(decision.get("target_battle_id", "")),
		"defend_score": float(candidate_scores.get("defend", 0.0)),
		"strike_score": float(candidate_scores.get("strike", 0.0)),
		"tactical_order_action": String(tactical_order.get("action", "")),
	}

func _validate_decisive_attack_pressure() -> Dictionary:
	var decisive_session := _decisive_attack_session(false)
	var decisive_active := BattleRulesScript.get_active_stack(decisive_session.battle)
	var decisive_order := BattleAiRules.choose_stack_tactical_order(decisive_session.battle, decisive_active, "enemy")
	var decisive_scores: Dictionary = decisive_order.get("candidate_scores", {}) if decisive_order.get("candidate_scores", {}) is Dictionary else {}
	var decisive_defend_score := float(decisive_scores.get("defend", -9999.0))
	var decisive_strike_score := float(decisive_scores.get("strike", -9999.0))
	var decisive_acting_ratio := BattleAiRules._side_health_ratio(decisive_session.battle, "player")
	var decisive_target_ratio := BattleAiRules._side_health_ratio(decisive_session.battle, "enemy")
	if String(decisive_order.get("action", "")) != "strike":
		_fail("An engaged stack should press a close-scored strike against a critically depleted ranged side: %s" % JSON.stringify(decisive_order))
		return {}
	if decisive_acting_ratio < BattleAiRules.DECISIVE_ATTACK_ACTING_SIDE_HEALTH_RATIO_MIN or decisive_target_ratio > BattleAiRules.DECISIVE_ATTACK_TARGET_SIDE_HEALTH_RATIO_MAX:
		_fail("Decisive attack fixture does not exercise the bounded side-health window: acting=%s target=%s" % [decisive_acting_ratio, decisive_target_ratio])
		return {}
	if decisive_strike_score >= decisive_defend_score or decisive_defend_score - decisive_strike_score > BattleAiRules.DECISIVE_ATTACK_MAX_DEFEND_SCORE_GAP:
		_fail("Decisive attack fixture must exercise the bounded defend-score override: %s" % JSON.stringify(decisive_order))
		return {}

	var preserve_session := _decisive_attack_session(true)
	var preserve_active := BattleRulesScript.get_active_stack(preserve_session.battle)
	var preserve_order := BattleAiRules.choose_stack_tactical_order(preserve_session.battle, preserve_active, "enemy")
	var preserve_scores: Dictionary = preserve_order.get("candidate_scores", {}) if preserve_order.get("candidate_scores", {}) is Dictionary else {}
	var preserve_defend_score := float(preserve_scores.get("defend", -9999.0))
	var preserve_strike_score := float(preserve_scores.get("strike", -9999.0))
	var preserve_acting_ratio := BattleAiRules._side_health_ratio(preserve_session.battle, "player")
	if String(preserve_order.get("action", "")) != "defend":
		_fail("A materially superior defense must remain selected against a depleted side: %s" % JSON.stringify(preserve_order))
		return {}
	if preserve_acting_ratio < BattleAiRules.DECISIVE_ATTACK_ACTING_SIDE_HEALTH_RATIO_MIN:
		_fail("Superior-defense control must remain inside the decisive acting-side health window: %s" % preserve_acting_ratio)
		return {}
	if preserve_defend_score - preserve_strike_score <= BattleAiRules.DECISIVE_ATTACK_MAX_DEFEND_SCORE_GAP:
		_fail("Decisive attack control fixture does not clear the bounded override gap: %s" % JSON.stringify(preserve_order))
		return {}
	return {
		"ok": true,
		"decisive_action": String(decisive_order.get("action", "")),
		"decisive_defend_score": decisive_defend_score,
		"decisive_strike_score": decisive_strike_score,
		"decisive_acting_side_health_ratio": decisive_acting_ratio,
		"decisive_target_side_health_ratio": decisive_target_ratio,
		"preserve_action": String(preserve_order.get("action", "")),
		"preserve_defend_score": preserve_defend_score,
		"preserve_strike_score": preserve_strike_score,
		"preserve_acting_side_health_ratio": preserve_acting_ratio,
	}

func _validate_enemy_overkill_target_discipline() -> Dictionary:
	var session := _enemy_overkill_target_session()
	var active_stack := BattleRulesScript.get_active_stack(session.battle)
	var decision := BattleAiRules.choose_enemy_action(session.battle, active_stack, {})
	if String(decision.get("action", "")) != "shoot" or String(decision.get("target_battle_id", "")) != "player_dangerous_ranged":
		_fail("Enemy ranged stack should pressure the dangerous target instead of dumping overkill into a one-health decoy: %s" % JSON.stringify(decision))
		return {}
	var tactical_order := BattleAiRules.choose_stack_tactical_order(session.battle, active_stack, "player")
	if String(tactical_order.get("action", "")) != "shoot" or String(tactical_order.get("target_battle_id", "")) != "player_dangerous_ranged":
		_fail("Shared tactical order should use overkill-aware target selection: %s" % JSON.stringify(tactical_order))
		return {}
	var decoy := BattleRulesScript._get_stack_by_id(session.battle, "player_one_hp_decoy")
	var dangerous := BattleRulesScript._get_stack_by_id(session.battle, "player_dangerous_ranged")
	var decoy_estimate := BattleAiRules._estimate_damage(active_stack, decoy, session.battle, true)
	var dangerous_estimate := BattleAiRules._estimate_damage(active_stack, dangerous, session.battle, true)
	return {
		"ok": true,
		"live_action": String(decision.get("action", "")),
		"live_target_id": String(decision.get("target_battle_id", "")),
		"tactical_order_target_id": String(tactical_order.get("target_battle_id", "")),
		"decoy_total_health": int(decoy.get("total_health", 0)),
		"decoy_damage_estimate": decoy_estimate,
		"dangerous_total_health": int(dangerous.get("total_health", 0)),
		"dangerous_damage_estimate": dangerous_estimate,
	}

func _validate_enemy_immediate_threat_targeting() -> Dictionary:
	var session := _enemy_immediate_threat_target_session()
	var active_stack := BattleRulesScript.get_active_stack(session.battle)
	var decision := BattleAiRules.choose_enemy_action(session.battle, active_stack, {})
	if String(decision.get("action", "")) != "shoot" or String(decision.get("target_battle_id", "")) != "player_immediate_killer":
		_fail("Enemy ranged stack should suppress immediate lethal pressure instead of chasing a weaker wounded decoy: %s" % JSON.stringify(decision))
		return {}
	var tactical_order := BattleAiRules.choose_stack_tactical_order(session.battle, active_stack, "player")
	if String(tactical_order.get("action", "")) != "shoot" or String(tactical_order.get("target_battle_id", "")) != "player_immediate_killer":
		_fail("Shared tactical order should use immediate-threat target selection: %s" % JSON.stringify(tactical_order))
		return {}
	var wounded := BattleRulesScript._get_stack_by_id(session.battle, "player_wounded_decoy")
	var killer := BattleRulesScript._get_stack_by_id(session.battle, "player_immediate_killer")
	var wounded_threat := BattleAiRules._target_immediate_threat_score(active_stack, wounded, session.battle)
	var killer_threat := BattleAiRules._target_immediate_threat_score(active_stack, killer, session.battle)
	if killer_threat <= wounded_threat:
		_fail("Immediate threat fixture did not expose higher threat on killer: wounded=%s killer=%s" % [wounded_threat, killer_threat])
		return {}
	return {
		"ok": true,
		"live_action": String(decision.get("action", "")),
		"live_target_id": String(decision.get("target_battle_id", "")),
		"tactical_order_target_id": String(tactical_order.get("target_battle_id", "")),
		"wounded_threat_score": wounded_threat,
		"killer_threat_score": killer_threat,
		"wounded_attack_score": BattleAiRules._attack_score(active_stack, wounded, session.battle, true),
		"killer_attack_score": BattleAiRules._attack_score(active_stack, killer, session.battle, true),
	}

func _validate_tactical_order_argument_commander_payload() -> Dictionary:
	var session := _engaged_enemy_melee_session()
	var active_stack := BattleRulesScript.get_active_stack(session.battle)
	var baseline := BattleAiRules.choose_stack_tactical_order(session.battle, active_stack, "player")
	var commander := {
		"hero_id": "test_vanguard_commander",
		"archetype": "marshal",
		"command_path": "might",
		"battle_traits": ["vanguard"],
		"command": {"attack": 0, "defense": 0, "power": 0, "knowledge": 0},
	}
	var bridged := BattleAiRules.choose_stack_tactical_order(session.battle, active_stack, "player", commander)
	var baseline_scores: Dictionary = baseline.get("candidate_scores", {}) if baseline.get("candidate_scores", {}) is Dictionary else {}
	var bridged_scores: Dictionary = bridged.get("candidate_scores", {}) if bridged.get("candidate_scores", {}) is Dictionary else {}
	if String(bridged.get("commander_payload_source", "")) != "argument":
		_fail("Tactical order did not report argument commander payload source: %s" % JSON.stringify(bridged))
		return {}
	if not baseline_scores.has("strike") or not bridged_scores.has("strike"):
		_fail("Tactical order payload bridge case is missing strike score evidence: baseline=%s bridged=%s" % [JSON.stringify(baseline), JSON.stringify(bridged)])
		return {}
	if float(bridged_scores.get("strike", 0.0)) <= float(baseline_scores.get("strike", 0.0)):
		_fail("Vanguard argument commander payload did not improve non-spell strike scoring: baseline=%s bridged=%s" % [JSON.stringify(baseline), JSON.stringify(bridged)])
		return {}
	var enemy_battle_state := session.battle.duplicate(true)
	enemy_battle_state["enemy_hero"] = commander.duplicate(true)
	var enemy_state_fallback := BattleAiRules.choose_stack_tactical_order(enemy_battle_state, active_stack, "player")
	var enemy_state_scores: Dictionary = enemy_state_fallback.get("candidate_scores", {}) if enemy_state_fallback.get("candidate_scores", {}) is Dictionary else {}
	if String(enemy_state_fallback.get("commander_payload_source", "")) != "battle":
		_fail("Enemy battle-state commander fallback did not report battle payload source: %s" % JSON.stringify(enemy_state_fallback))
		return {}
	if float(enemy_state_scores.get("strike", 0.0)) <= float(baseline_scores.get("strike", 0.0)):
		_fail("Enemy battle-state vanguard commander did not improve non-spell strike scoring: baseline=%s fallback=%s" % [JSON.stringify(baseline), JSON.stringify(enemy_state_fallback)])
		return {}
	if enemy_battle_state.has("enemy_hero_payload"):
		_fail("Enemy battle-state commander fallback mutated source battle state: %s" % JSON.stringify(enemy_battle_state))
		return {}
	var player_session := _adjacent_ranged_session()
	player_session.battle["battlefield_tags"] = ["elevated_fire"]
	var player_active := BattleRulesScript.get_active_stack(player_session.battle)
	var player_baseline := BattleAiRules.choose_stack_tactical_order(player_session.battle, player_active, "enemy")
	var player_commander := {
		"hero_id": "test_player_vanguard_commander",
		"archetype": "marshal",
		"command_path": "might",
		"battle_traits": ["vanguard"],
		"command": {"attack": 0, "defense": 0, "power": 0, "knowledge": 0},
	}
	var player_battle_state := player_session.battle.duplicate(true)
	player_battle_state["player_commander_state"] = player_commander.duplicate(true)
	var player_state_fallback := BattleAiRules.choose_stack_tactical_order(player_battle_state, player_active, "enemy")
	var player_baseline_scores: Dictionary = player_baseline.get("candidate_scores", {}) if player_baseline.get("candidate_scores", {}) is Dictionary else {}
	var player_state_scores: Dictionary = player_state_fallback.get("candidate_scores", {}) if player_state_fallback.get("candidate_scores", {}) is Dictionary else {}
	var player_action_key := String(player_state_fallback.get("action", ""))
	if String(player_state_fallback.get("commander_payload_source", "")) != "battle":
		_fail("Player battle-state commander fallback did not report battle payload source: %s" % JSON.stringify(player_state_fallback))
		return {}
	if player_action_key == "" or not player_baseline_scores.has(player_action_key) or not player_state_scores.has(player_action_key):
		_fail("Player battle-state commander fallback did not expose comparable action score evidence: baseline=%s fallback=%s" % [JSON.stringify(player_baseline), JSON.stringify(player_state_fallback)])
		return {}
	if float(player_state_scores.get(player_action_key, 0.0)) <= float(player_baseline_scores.get(player_action_key, 0.0)):
		_fail("Player battle-state vanguard commander did not improve non-spell action scoring: baseline=%s fallback=%s" % [JSON.stringify(player_baseline), JSON.stringify(player_state_fallback)])
		return {}
	if player_battle_state.has("player_hero"):
		_fail("Player battle-state commander fallback mutated source battle state: %s" % JSON.stringify(player_battle_state))
		return {}
	var minimal_template_state := session.battle.duplicate(true)
	minimal_template_state["enemy_hero"] = {"roster_hero_id": "hero_lyra"}
	var template_fallback := BattleAiRules.choose_stack_tactical_order(minimal_template_state, active_stack, "player")
	var template_scores: Dictionary = template_fallback.get("candidate_scores", {}) if template_fallback.get("candidate_scores", {}) is Dictionary else {}
	if String(template_fallback.get("commander_payload_source", "")) != "battle":
		_fail("Minimal template commander fallback did not report battle payload source: %s" % JSON.stringify(template_fallback))
		return {}
	if not template_scores.has("strike"):
		_fail("Minimal template commander fallback is missing strike score evidence: %s" % JSON.stringify(template_fallback))
		return {}
	if float(template_scores.get("strike", 0.0)) <= float(baseline_scores.get("strike", 0.0)):
		_fail("Minimal Lyra commander should inherit template vanguard scoring: baseline=%s template=%s" % [JSON.stringify(baseline), JSON.stringify(template_fallback)])
		return {}
	var minimal_existing_payload_state := session.battle.duplicate(true)
	minimal_existing_payload_state["enemy_hero_payload"] = {"hero_id": "hero_lyra"}
	var existing_payload_fallback := BattleAiRules.choose_stack_tactical_order(minimal_existing_payload_state, active_stack, "player")
	var existing_payload_scores: Dictionary = existing_payload_fallback.get("candidate_scores", {}) if existing_payload_fallback.get("candidate_scores", {}) is Dictionary else {}
	if float(existing_payload_scores.get("strike", 0.0)) <= float(baseline_scores.get("strike", 0.0)):
		_fail("Existing minimal enemy_hero_payload should inherit template vanguard scoring: baseline=%s fallback=%s" % [JSON.stringify(baseline), JSON.stringify(existing_payload_fallback)])
		return {}
	if minimal_existing_payload_state.get("enemy_hero_payload", {}).has("battle_traits"):
		_fail("Existing minimal payload template fallback mutated source battle state: %s" % JSON.stringify(minimal_existing_payload_state))
		return {}
	var rich_battle_payload_state := session.battle.duplicate(true)
	rich_battle_payload_state["enemy_hero_payload"] = {
		"hero_id": "argument_battle_merge_commander",
		"battle_traits": ["vanguard"],
		"command": {"attack": 3, "defense": 0, "power": 0, "knowledge": 0},
	}
	var minimal_argument := {"hero_id": "argument_battle_merge_commander"}
	var argument_battle_merge := BattleAiRules.choose_stack_tactical_order(
		rich_battle_payload_state,
		active_stack,
		"player",
		minimal_argument
	)
	var argument_battle_scores: Dictionary = argument_battle_merge.get("candidate_scores", {}) if argument_battle_merge.get("candidate_scores", {}) is Dictionary else {}
	if String(argument_battle_merge.get("commander_payload_source", "")) != "battle":
		_fail("Argument plus battle payload merge should report battle payload source when battle metadata participates: %s" % JSON.stringify(argument_battle_merge))
		return {}
	if not argument_battle_scores.has("strike") or float(argument_battle_scores.get("strike", 0.0)) <= float(baseline_scores.get("strike", 0.0)):
		_fail("Minimal argument commander should inherit compatible rich battle payload vanguard scoring: baseline=%s merge=%s" % [JSON.stringify(baseline), JSON.stringify(argument_battle_merge)])
		return {}
	if rich_battle_payload_state.get("enemy_hero_payload", {}).get("command", {}).has("initiative"):
		_fail("Argument plus battle payload merge mutated source battle payload: %s" % JSON.stringify(rich_battle_payload_state))
		return {}
	if session.battle.has("enemy_hero_payload") or session.battle.has("player_hero"):
		_fail("Argument commander payload bridge mutated source battle state: %s" % JSON.stringify(session.battle))
		return {}
	return {
		"ok": true,
		"baseline_source": String(baseline.get("commander_payload_source", "")),
		"bridged_source": String(bridged.get("commander_payload_source", "")),
		"baseline_strike_score": float(baseline_scores.get("strike", 0.0)),
		"bridged_strike_score": float(bridged_scores.get("strike", 0.0)),
		"enemy_battle_state_source": String(enemy_state_fallback.get("commander_payload_source", "")),
		"enemy_battle_state_strike_score": float(enemy_state_scores.get("strike", 0.0)),
		"player_battle_state_source": String(player_state_fallback.get("commander_payload_source", "")),
		"player_battle_state_action": player_action_key,
		"player_battle_state_action_score": float(player_state_scores.get(player_action_key, 0.0)),
		"template_fallback_source": String(template_fallback.get("commander_payload_source", "")),
		"template_fallback_strike_score": float(template_scores.get("strike", 0.0)),
		"existing_payload_template_fallback_strike_score": float(existing_payload_scores.get("strike", 0.0)),
		"argument_battle_merge_source": String(argument_battle_merge.get("commander_payload_source", "")),
		"argument_battle_merge_strike_score": float(argument_battle_scores.get("strike", 0.0)),
		"source_battle_mutated": session.battle.has("enemy_hero_payload") or session.battle.has("player_hero"),
		"enemy_battle_state_mutated": enemy_battle_state.has("enemy_hero_payload"),
		"player_battle_state_mutated": player_battle_state.has("player_hero"),
	}

func _validate_battle_rules_commander_payload_fallback() -> Dictionary:
	var player_session := _adjacent_ranged_session()
	var player_attacker := BattleRulesScript.get_active_stack(player_session.battle)
	var player_target := BattleRulesScript._get_stack_by_id(player_session.battle, "enemy_front")
	var player_base_preview := BattleRulesScript._damage_range_preview(player_attacker, player_target, player_session.battle, true)
	var player_fallback_battle := player_session.battle.duplicate(true)
	player_fallback_battle.erase("player_hero")
	player_fallback_battle["player_commander_state"] = {
		"hero_id": "player_preview_commander",
		"command": {"attack": 6, "defense": 0, "power": 0, "knowledge": 0},
	}
	var player_fallback_preview := BattleRulesScript._damage_range_preview(
		player_attacker,
		player_target,
		player_fallback_battle,
		true
	)
	if int(player_fallback_preview.get("min_damage", 0)) <= int(player_base_preview.get("min_damage", 0)):
		_fail("Player damage preview did not use player_commander_state fallback: base=%s fallback=%s" % [JSON.stringify(player_base_preview), JSON.stringify(player_fallback_preview)])
		return {}

	var enemy_session := _engaged_enemy_melee_session()
	var enemy_attacker := BattleRulesScript.get_active_stack(enemy_session.battle)
	var enemy_target := BattleRulesScript._get_stack_by_id(enemy_session.battle, "player_wall")
	var enemy_base_preview := BattleRulesScript._damage_range_preview(enemy_attacker, enemy_target, enemy_session.battle, false)
	var enemy_fallback_battle := enemy_session.battle.duplicate(true)
	enemy_fallback_battle.erase("enemy_hero_payload")
	enemy_fallback_battle["enemy_hero"] = {
		"hero_id": "enemy_preview_commander",
		"command": {"attack": 6, "defense": 0, "power": 0, "knowledge": 0},
	}
	var enemy_fallback_preview := BattleRulesScript._damage_range_preview(
		enemy_attacker,
		enemy_target,
		enemy_fallback_battle,
		false
	)
	if int(enemy_fallback_preview.get("min_damage", 0)) <= int(enemy_base_preview.get("min_damage", 0)):
		_fail("Enemy damage preview did not use enemy_hero fallback: base=%s fallback=%s" % [JSON.stringify(enemy_base_preview), JSON.stringify(enemy_fallback_preview)])
		return {}
	return {
		"ok": true,
		"player_base_min_damage": int(player_base_preview.get("min_damage", 0)),
		"player_fallback_min_damage": int(player_fallback_preview.get("min_damage", 0)),
		"enemy_base_min_damage": int(enemy_base_preview.get("min_damage", 0)),
		"enemy_fallback_min_damage": int(enemy_fallback_preview.get("min_damage", 0)),
	}

func _validate_battle_ai_commander_payload_fallback() -> Dictionary:
	var player_session := _adjacent_ranged_session()
	var player_attacker := BattleRulesScript.get_active_stack(player_session.battle)
	var player_target := BattleRulesScript._get_stack_by_id(player_session.battle, "enemy_front")
	var player_base_estimate := BattleAiRules._estimate_damage(player_attacker, player_target, player_session.battle, true)
	var player_fallback_battle := player_session.battle.duplicate(true)
	player_fallback_battle.erase("player_hero")
	player_fallback_battle["player_commander_state"] = {
		"hero_id": "player_ai_estimate_commander",
		"command": {"attack": 6, "defense": 0, "power": 0, "knowledge": 0},
	}
	var player_fallback_estimate := BattleAiRules._estimate_damage(player_attacker, player_target, player_fallback_battle, true)
	if player_fallback_estimate <= player_base_estimate:
		_fail("Battle AI player estimate did not use player_commander_state fallback: base=%d fallback=%d" % [player_base_estimate, player_fallback_estimate])
		return {}

	var enemy_session := _engaged_enemy_melee_session()
	var enemy_attacker := BattleRulesScript.get_active_stack(enemy_session.battle)
	var enemy_target := BattleRulesScript._get_stack_by_id(enemy_session.battle, "player_wall")
	var enemy_base_estimate := BattleAiRules._estimate_damage(enemy_attacker, enemy_target, enemy_session.battle, false)
	var enemy_fallback_battle := enemy_session.battle.duplicate(true)
	enemy_fallback_battle.erase("enemy_hero_payload")
	enemy_fallback_battle["enemy_hero"] = {
		"hero_id": "enemy_ai_estimate_commander",
		"command": {"attack": 6, "defense": 0, "power": 0, "knowledge": 0},
	}
	var enemy_fallback_estimate := BattleAiRules._estimate_damage(enemy_attacker, enemy_target, enemy_fallback_battle, false)
	if enemy_fallback_estimate <= enemy_base_estimate:
		_fail("Battle AI enemy estimate did not use enemy_hero fallback: base=%d fallback=%d" % [enemy_base_estimate, enemy_fallback_estimate])
		return {}
	return {
		"ok": true,
		"player_base_estimate": player_base_estimate,
		"player_fallback_estimate": player_fallback_estimate,
		"enemy_base_estimate": enemy_base_estimate,
		"enemy_fallback_estimate": enemy_fallback_estimate,
	}

func _validate_player_spell_tactical_order() -> Dictionary:
	var session := _player_spell_tactical_order_session()
	var active_stack := BattleRulesScript.get_active_stack(session.battle)
	var commander: Dictionary = session.battle.get("player_commander_state", {})
	var tactical_order := BattleAiRules.choose_stack_tactical_order(session.battle, active_stack, "enemy", commander)
	if String(tactical_order.get("action", "")) != "cast_spell" or String(tactical_order.get("spell_id", "")) != "spell_cinder_burst":
		_fail("Shared tactical order should choose the legal high-value player spell: %s" % JSON.stringify(tactical_order))
		return {}
	if String(tactical_order.get("scoring_policy", "")) != "battle_ai_spell_tactical_order_v1":
		_fail("Spell tactical order did not report the spell-aware scoring policy: %s" % JSON.stringify(tactical_order))
		return {}
	var candidate_scores: Dictionary = tactical_order.get("candidate_scores", {}) if tactical_order.get("candidate_scores", {}) is Dictionary else {}
	if not candidate_scores.has("cast_spell") or float(candidate_scores.get("cast_spell", 0.0)) <= float(candidate_scores.get("advance", 0.0)):
		_fail("Spell tactical order lacks decisive spell score evidence: %s" % JSON.stringify(tactical_order))
		return {}
	var decision := BattleAutoplayBalanceHarnessRulesScript.player_autoplay_decision_report(session, true)
	if String(decision.get("action", "")) != "cast_spell" or String(decision.get("spell_id", "")) != "spell_cinder_burst":
		_fail("Player autoplay should preserve the scored spell order: %s" % JSON.stringify(decision))
		return {}
	if String(session.battle.get("selected_target_id", "")) != "enemy_spell_target":
		_fail("Player autoplay did not select the spell target before execution: %s" % JSON.stringify(session.battle))
		return {}
	var before_target := BattleRulesScript._get_stack_by_id(session.battle, "enemy_spell_target")
	var before_health := int(before_target.get("total_health", 0))
	var result := BattleRulesScript.cast_player_spell(session, String(decision.get("spell_id", "")))
	if not bool(result.get("ok", false)):
		_fail("Player autoplay spell order failed live cast execution: result=%s decision=%s" % [JSON.stringify(result), JSON.stringify(decision)])
		return {}
	var after_target := BattleRulesScript._get_stack_by_id(session.battle, "enemy_spell_target")
	if int(after_target.get("total_health", 0)) >= before_health:
		_fail("Player autoplay spell execution did not damage the target: before=%d after=%s" % [before_health, JSON.stringify(after_target)])
		return {}
	return {
		"ok": true,
		"action": String(decision.get("action", "")),
		"spell_id": String(decision.get("spell_id", "")),
		"target_battle_id": String(decision.get("target_battle_id", "")),
		"scoring_policy": String(tactical_order.get("scoring_policy", "")),
		"cast_spell_score": float(candidate_scores.get("cast_spell", 0.0)),
		"advance_score": float(candidate_scores.get("advance", 0.0)),
		"target_health_before": before_health,
		"target_health_after": int(after_target.get("total_health", 0)),
	}

func _validate_player_spell_conservation() -> Dictionary:
	var session := _player_spell_conservation_session()
	var active_stack := BattleRulesScript.get_active_stack(session.battle)
	var commander: Dictionary = session.battle.get("player_commander_state", {})
	var tactical_order := BattleAiRules.choose_stack_tactical_order(session.battle, active_stack, "enemy", commander)
	var candidate_scores: Dictionary = tactical_order.get("candidate_scores", {}) if tactical_order.get("candidate_scores", {}) is Dictionary else {}
	if not candidate_scores.has("cast_spell"):
		_fail("Spell conservation fixture should keep spell score evidence even when conserving mana: %s" % JSON.stringify(tactical_order))
		return {}
	if String(tactical_order.get("action", "")) == "cast_spell":
		_fail("Low-pressure spell conservation fixture should shoot instead of spending mana on a marginal buff: %s" % JSON.stringify(tactical_order))
		return {}
	if String(tactical_order.get("action", "")) != "shoot":
		_fail("Low-pressure spell conservation fixture should preserve the strong ranged order: %s" % JSON.stringify(tactical_order))
		return {}
	return {
		"ok": true,
		"action": String(tactical_order.get("action", "")),
		"scoring_policy": String(tactical_order.get("scoring_policy", "")),
		"shoot_score": float(candidate_scores.get("shoot", 0.0)),
		"cast_spell_score": float(candidate_scores.get("cast_spell", 0.0)),
	}

func _adjacent_ranged_session() -> SessionStateStoreScript.SessionData:
	var session := SessionStateStoreScript.SessionData.new(
		"battle-autoplay-tactical-order-report",
		"battle-autoplay-tactical-order-report",
		"hero_report",
		1,
		{},
		"normal",
		SessionStateStoreScript.LAUNCH_MODE_SKIRMISH
	)
	session.battle = {
		"round": 2,
		"max_rounds": 99,
		"distance": 0,
		"terrain": "plains",
		"battlefield_tags": [],
		"combat_seed": 12345,
		"stacks": [
			_stack("player_archer", "player", "player_archer", true, 6, 6, 36, 2, 4, 4, 2, 7, 3, 3),
			_stack("enemy_front", "enemy", "enemy_front", false, 4, 5, 18, 1, 2, 2, 1, 5, 4, 3),
		],
		"turn_order": ["player_archer"],
		"turn_index": 0,
		"active_stack_id": "player_archer",
		"selected_target_id": "enemy_front",
		"recent_events": [],
		"retreat_allowed": true,
		"surrender_allowed": true,
		"player_commander_state": {},
		"enemy_hero": {},
		"field_objectives": [],
	}
	return session

func _player_spell_tactical_order_session() -> SessionStateStoreScript.SessionData:
	var session := SessionStateStoreScript.SessionData.new(
		"battle-ai-shared-spell-tactical-order-report",
		"battle-ai-shared-spell-tactical-order-report",
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
		"terrain": "plains",
		"battlefield_tags": [],
		"combat_seed": 112233,
		"resistance_seed": "shared_spell_tactical_order",
		"stacks": [
			_stack("player_apprentice", "player", "player_apprentice", false, 4, 8, 32, 1, 1, 1, 1, 4, 3, 3),
			_stack("enemy_spell_target", "enemy", "enemy_spell_target", true, 8, 8, 64, 4, 5, 4, 2, 5, 8, 3),
		],
		"turn_order": ["player_apprentice"],
		"turn_index": 0,
		"active_stack_id": "player_apprentice",
		"selected_target_id": "enemy_spell_target",
		"recent_events": [],
		"retreat_allowed": true,
		"surrender_allowed": true,
		"player_commander_state": {
			"hero_id": "player_spell_tactical_order_commander",
			"name": "Player Spell Tactical Order Commander",
			"archetype": "artillerist",
			"command_path": "magic",
			"command": {"attack": 0, "defense": 0, "power": 3, "knowledge": 8},
			"spellbook": {
				"known_spell_ids": ["spell_cinder_burst"],
				"mana": {"current": 20, "max": 20}
			}
		},
		"enemy_hero": {},
		"field_objectives": [],
	}
	return session

func _player_spell_conservation_session() -> SessionStateStoreScript.SessionData:
	var session := SessionStateStoreScript.SessionData.new(
		"battle-ai-spell-conservation-tactical-order-report",
		"battle-ai-spell-conservation-tactical-order-report",
		"hero_report",
		1,
		{},
		"normal",
		SessionStateStoreScript.LAUNCH_MODE_SKIRMISH
	)
	session.battle = {
		"round": 1,
		"max_rounds": 99,
		"distance": 2,
		"terrain": "plains",
		"battlefield_tags": ["open_lane"],
		"combat_seed": 445566,
		"stacks": [
			_stack("player_marksman", "player", "player_marksman", true, 10, 10, 100, 8, 9, 6, 4, 8, 3, 3),
			_stack("enemy_low_pressure", "enemy", "enemy_low_pressure", false, 4, 8, 32, 1, 1, 1, 1, 7, 8, 3),
		],
		"turn_order": ["player_marksman"],
		"turn_index": 0,
		"active_stack_id": "player_marksman",
		"selected_target_id": "enemy_low_pressure",
		"recent_events": [],
		"retreat_allowed": true,
		"surrender_allowed": true,
		"player_commander_state": {
			"hero_id": "player_spell_conservation_commander",
			"name": "Player Spell Conservation Commander",
			"archetype": "marshal",
			"command_path": "might",
			"command": {"attack": 0, "defense": 0, "power": 1, "knowledge": 8},
			"spellbook": {
				"known_spell_ids": ["spell_stone_veil"],
				"mana": {"current": 20, "max": 20}
			}
		},
		"enemy_hero": {},
		"field_objectives": [],
	}
	return session

func _engaged_enemy_melee_session() -> SessionStateStoreScript.SessionData:
	var session := SessionStateStoreScript.SessionData.new(
		"battle-ai-engaged-melee-attack-report",
		"battle-ai-engaged-melee-attack-report",
		"hero_report",
		1,
		{},
		"normal",
		SessionStateStoreScript.LAUNCH_MODE_SKIRMISH
	)
	session.battle = {
		"round": 2,
		"max_rounds": 99,
		"distance": 0,
		"terrain": "plains",
		"battlefield_tags": [],
		"combat_seed": 67890,
		"stacks": [
			_stack("enemy_guard", "enemy", "enemy_guard", false, 10, 10, 20, 1, 1, 2, 5, 2, 4, 3, ["brace"]),
			_stack("player_wall", "player", "player_wall", false, 20, 20, 400, 1, 1, 1, 8, 7, 5, 3),
		],
		"turn_order": ["enemy_guard"],
		"turn_index": 0,
		"active_stack_id": "enemy_guard",
		"selected_target_id": "player_wall",
		"recent_events": [],
		"retreat_allowed": true,
		"surrender_allowed": true,
		"player_commander_state": {},
		"enemy_hero": {},
		"field_objectives": [],
	}
	return session

func _decisive_attack_session(preserve_defense: bool) -> SessionStateStoreScript.SessionData:
	var session := SessionStateStoreScript.SessionData.new(
		"battle-ai-decisive-attack-report",
		"battle-ai-decisive-attack-report",
		"hero_report",
		1,
		{},
		"normal",
		SessionStateStoreScript.LAUNCH_MODE_SKIRMISH
	)
	var active_health := 27
	var active_max_damage := 1 if preserve_defense else 3
	session.battle = {
		"round": 5,
		"max_rounds": 99,
		"distance": 0,
		"terrain": "plains",
		"battlefield_tags": [],
		"combat_seed": 97531,
		"stacks": [
			_stack("player_closer", "player", "player_closer", false, 6, 9, active_health, 1, active_max_damage, 4, 5, 0, 3, 3, ["brace"]),
			_stack("enemy_depleted_ranged", "enemy", "enemy_depleted_ranged", true, 8, 6, 18, 1, 3, 3, 3, 8, 4, 3),
		],
		"turn_order": ["player_closer"],
		"turn_index": 0,
		"active_stack_id": "player_closer",
		"selected_target_id": "enemy_depleted_ranged",
		"recent_events": [],
		"retreat_allowed": true,
		"surrender_allowed": true,
		"player_commander_state": {},
		"enemy_hero": {},
		"field_objectives": [],
	}
	return session

func _enemy_overkill_target_session() -> SessionStateStoreScript.SessionData:
	var session := SessionStateStoreScript.SessionData.new(
		"battle-ai-overkill-target-discipline-report",
		"battle-ai-overkill-target-discipline-report",
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
		"terrain": "plains",
		"battlefield_tags": ["open_lane"],
		"combat_seed": 24680,
		"stacks": [
			_stack("enemy_marksmen", "enemy", "enemy_marksmen", true, 12, 10, 120, 9, 9, 8, 4, 7, 3, 3),
			_stack("player_one_hp_decoy", "player", "player_one_hp_decoy", false, 1, 1, 1, 1, 1, 1, 1, 5, 8, 3),
			_stack("player_dangerous_ranged", "player", "player_dangerous_ranged", true, 12, 10, 120, 7, 9, 6, 4, 7, 8, 4),
		],
		"turn_order": ["enemy_marksmen"],
		"turn_index": 0,
		"active_stack_id": "enemy_marksmen",
		"selected_target_id": "player_dangerous_ranged",
		"recent_events": [],
		"retreat_allowed": true,
		"surrender_allowed": true,
		"player_commander_state": {},
		"enemy_hero": {},
		"field_objectives": [],
	}
	return session

func _enemy_immediate_threat_target_session() -> SessionStateStoreScript.SessionData:
	var session := SessionStateStoreScript.SessionData.new(
		"battle-ai-immediate-threat-targeting-report",
		"battle-ai-immediate-threat-targeting-report",
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
		"terrain": "plains",
		"battlefield_tags": ["open_lane"],
		"combat_seed": 13579,
		"stacks": [
			_stack("enemy_skirmishers", "enemy", "enemy_skirmishers", true, 4, 10, 40, 2, 2, 4, 4, 7, 3, 3),
			_stack("player_wounded_decoy", "player", "player_wounded_decoy", false, 2, 10, 12, 1, 1, 1, 1, 4, 8, 3),
			_stack("player_immediate_killer", "player", "player_immediate_killer", true, 12, 10, 120, 7, 7, 8, 4, 7, 8, 4),
		],
		"turn_order": ["enemy_skirmishers"],
		"turn_index": 0,
		"active_stack_id": "enemy_skirmishers",
		"selected_target_id": "player_immediate_killer",
		"recent_events": [],
		"retreat_allowed": true,
		"surrender_allowed": true,
		"player_commander_state": {},
		"enemy_hero": {},
		"field_objectives": [],
	}
	return session

func _stack(
	unit_id: String,
	side: String,
	battle_id: String,
	ranged: bool,
	count: int,
	unit_hp: int,
	total_health: int,
	min_damage: int,
	max_damage: int,
	attack: int,
	defense: int,
	cohesion: int,
	q: int,
	r: int,
	abilities: Array = []
) -> Dictionary:
	return {
		"unit_id": unit_id,
		"name": battle_id,
		"side": side,
		"battle_id": battle_id,
		"count": count,
		"base_count": count,
		"unit_hp": unit_hp,
		"total_health": total_health,
		"min_damage": min_damage,
		"max_damage": max_damage,
		"attack": attack,
		"defense": defense,
		"initiative": 5,
		"cohesion": cohesion,
		"momentum": 0,
		"ranged": ranged,
		"shots_remaining": 4 if ranged else 0,
		"retaliations_left": 1,
		"abilities": abilities,
		"hex": {"q": q, "r": r},
	}

func _fail(message: String) -> void:
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message})])
	get_tree().quit(1)
