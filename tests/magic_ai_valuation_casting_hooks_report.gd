extends Node

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

	var adventure_case := _run_adventure_ai_spell_case()
	if not bool(adventure_case.get("ok", false)):
		_fail(String(adventure_case.get("error", "Adventure AI spell valuation case failed.")))
		return

	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"battle": battle_case,
		"battle_resistance_targeting": resistance_case,
		"adventure": adventure_case,
		"caveats": [
			"This report proves bounded AI spell valuation, resistance-aware battle targeting, the existing battle casting decision hook, live enemy movement-spell execution, and live enemy scouting-spell execution for strategic raid movement.",
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
		"scouting_executor": scouting_executor_case,
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
