extends Node

const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const ScenarioFactoryScript = preload("res://scripts/core/ScenarioFactory.gd")
const ScenarioScriptRulesScript = preload("res://scripts/core/ScenarioScriptRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "REEDBARROW_FERRY_MURKWARD_VETERAN_GARRISON_REPORT"
const SCENARIO_ID := "reedbarrow-ferry"
const TOWN_ID := "murkward_bridgehead"
const HOOK_ID := "stonewake_veterans_arrive"
const CARRYOVER_FLAG := "carryover_willow_mill_secured"
const FIELD_ARMY_ID := "army_ashgrove_watch"
const SELECTED_GUARD_COUNT := 32
const LIVE_COMBAT_SEED := 2861950694
const LIVE_ENEMY_COUNTS := {
	"unit_blackbranch_cutthroat": 20,
	"unit_mire_slinger": 8,
	"unit_bog_brute": 4,
}

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ContentService.clear_cache()
	var content_contract: Dictionary = _assert_content_contract()
	if _failed:
		return
	var no_carryover: Dictionary = _run_hook_case(false)
	if _failed:
		return
	var carryover: Dictionary = _run_hook_case(true)
	if _failed:
		return
	var control: Dictionary = _run_live_town_defense(false)
	if _failed:
		return
	var selected: Dictionary = _run_live_town_defense(true)
	if _failed:
		return
	if String(control.get("state", "")) != "defeat" or String(control.get("town_owner", "")) != "enemy":
		_fail("The exact unreinforced Murkward control did not reproduce the live defeat: %s" % JSON.stringify(control))
		return
	if String(selected.get("state", "")) != "victory" or String(selected.get("town_owner", "")) != "player":
		_fail("The carryover-only veteran garrison did not preserve Murkward: %s" % JSON.stringify(selected))
		return
	if selected.get("survivors", {}) != {"unit_river_guard": 16}:
		_fail("The selected garrison changed its exact survivor contract: %s" % JSON.stringify(selected))
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"content": content_contract,
		"no_carryover": no_carryover,
		"carryover": carryover,
		"control": control,
		"selected": selected,
	})])
	get_tree().quit(0)

func _assert_content_contract() -> Dictionary:
	var scenario: Dictionary = ContentService.get_scenario(SCENARIO_ID)
	var hook: Dictionary = {}
	for value in scenario.get("script_hooks", []):
		if value is Dictionary and String(value.get("id", "")) == HOOK_ID:
			hook = value
			break
	if hook.is_empty():
		_fail("Reedbarrow Ferry is missing the Stonewake veteran hook.")
		return {}
	var effects: Array = hook.get("effects", [])
	var conditions: Array = hook.get("conditions", [])
	if int(hook.get("priority", 0)) != 120 or conditions.size() != 2 \
			or String(conditions[0].get("type", "")) != "day_at_least" or int(conditions[0].get("day", 0)) != 1 \
			or String(conditions[1].get("type", "")) != "flag_true" or String(conditions[1].get("flag", "")) != CARRYOVER_FLAG:
		_fail("The Stonewake veteran hook timing or carryover ownership drifted: %s" % JSON.stringify(hook.get("conditions", [])))
		return {}
	var resource_effect: Dictionary = effects[0] if effects.size() > 0 and effects[0] is Dictionary else {}
	var recruit_effect: Dictionary = effects[1] if effects.size() > 1 and effects[1] is Dictionary else {}
	var garrison_effect: Dictionary = effects[2] if effects.size() > 2 and effects[2] is Dictionary else {}
	if effects.size() != 4 \
			or String(resource_effect.get("type", "")) != "add_resources" or int(resource_effect.get("resources", {}).get("gold", 0)) != 200 or int(resource_effect.get("resources", {}).get("wood", 0)) != 1 \
			or String(recruit_effect.get("type", "")) != "town_add_recruits" or String(recruit_effect.get("placement_id", "")) != TOWN_ID or int(recruit_effect.get("recruits", {}).get("unit_river_guard", 0)) != 1 or int(recruit_effect.get("recruits", {}).get("unit_ember_archer", 0)) != 1 \
			or String(garrison_effect.get("type", "")) != "town_add_garrison" or String(garrison_effect.get("placement_id", "")) != TOWN_ID or int(garrison_effect.get("garrison", {}).get("unit_river_guard", 0)) != SELECTED_GUARD_COUNT or garrison_effect.get("garrison", {}).size() != 1:
		_fail("The Stonewake veteran hook effects drifted: %s" % JSON.stringify(effects))
		return {}
	var message: Dictionary = effects[3] if effects[3] is Dictionary else {}
	if String(message.get("type", "")) != "message" or "veteran file for the bridgehead" not in String(message.get("text", "")):
		_fail("The Stonewake veteran hook message no longer explains the bridgehead reinforcement.")
		return {}
	if String(scenario.get("player_army_id", "")) != FIELD_ARMY_ID:
		_fail("Reedbarrow Ferry changed its shared balanced opening army.")
		return {}
	return {"hook_id": HOOK_ID, "priority": 120, "conditions": hook.get("conditions", []), "effects": effects, "player_army_id": FIELD_ARMY_ID}

func _run_hook_case(with_carryover: bool) -> Dictionary:
	var session: SessionStateStoreScript.SessionData = ScenarioFactoryScript.create_session(
		SCENARIO_ID,
		"normal",
		SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN
	)
	var town_before: Dictionary = _town(session)
	var resources_before: Dictionary = session.overworld.get("resources", {}).duplicate(true)
	var recruits_before: Dictionary = town_before.get("available_recruits", {}).duplicate(true)
	if with_carryover:
		session.flags[CARRYOVER_FLAG] = true
	var hook_result: Dictionary = ScenarioScriptRulesScript.process_hooks(session)
	var town_after: Dictionary = _town(session)
	var fired_ids: Array = hook_result.get("fired_ids", [])
	var garrison_counts: Dictionary = _stack_counts({"stacks": town_after.get("garrison", [])})
	var recruit_counts: Dictionary = town_after.get("available_recruits", {}).duplicate(true)
	if with_carryover:
		if HOOK_ID not in fired_ids:
			_fail("The carryover flag did not fire the Stonewake veteran hook.")
			return {}
		if garrison_counts != {"unit_blackbranch_cutthroat": 5, "unit_mire_slinger": 3, "unit_river_guard": 32}:
			_fail("The carryover hook did not produce the exact Murkward garrison: %s" % JSON.stringify(garrison_counts))
			return {}
		var resources_after: Dictionary = session.overworld.get("resources", {})
		if int(resources_after.get("gold", 0)) != int(resources_before.get("gold", 0)) + 200 or int(resources_after.get("wood", 0)) != int(resources_before.get("wood", 0)) + 1:
			_fail("The veteran hook changed its existing resource support.")
			return {}
		if int(recruit_counts.get("unit_river_guard", 0)) != int(recruits_before.get("unit_river_guard", 0)) + 1 or int(recruit_counts.get("unit_ember_archer", 0)) != int(recruits_before.get("unit_ember_archer", 0)) + 1:
			_fail("The veteran hook changed its existing recruit support.")
			return {}
		var second_result: Dictionary = ScenarioScriptRulesScript.process_hooks(session)
		if HOOK_ID in second_result.get("fired_ids", []) or _stack_counts({"stacks": _town(session).get("garrison", [])}) != garrison_counts:
			_fail("The once-only veteran garrison was applied more than once.")
			return {}
	else:
		if HOOK_ID in fired_ids or town_after != town_before or session.overworld.get("resources", {}) != resources_before:
			_fail("The veteran support changed Murkward without chapter-one carryover.")
			return {}
		if garrison_counts != {"unit_blackbranch_cutthroat": 5, "unit_mire_slinger": 3}:
			_fail("The no-carryover Murkward control drifted: %s" % JSON.stringify(garrison_counts))
			return {}
	return {"with_carryover": with_carryover, "fired": HOOK_ID in fired_ids, "garrison": garrison_counts, "recruits": recruit_counts}

func _run_live_town_defense(with_carryover: bool) -> Dictionary:
	var session: SessionStateStoreScript.SessionData = ScenarioFactoryScript.create_session(
		SCENARIO_ID,
		"normal",
		SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN
	)
	if with_carryover:
		session.flags[CARRYOVER_FLAG] = true
		var hook_result: Dictionary = ScenarioScriptRulesScript.process_hooks(session)
		if HOOK_ID not in hook_result.get("fired_ids", []):
			_fail("The battle fixture did not receive its carryover garrison.")
			return {}
	_move_active_hero_away(session)
	var placement: Dictionary = _live_raid_placement()
	session.battle = BattleRulesScript.create_battle_payload(session, placement)
	var entry_counts: Dictionary = _battle_side_counts(session.battle, "player")
	var enemy_counts: Dictionary = _battle_side_counts(session.battle, "enemy")
	if enemy_counts != LIVE_ENEMY_COUNTS:
		_fail("The exact live Vaska raid force drifted: %s" % JSON.stringify(enemy_counts))
		return {}
	var result: Dictionary = _resolve_like_live_validation(session)
	return {
		"with_carryover": with_carryover,
		"combat_seed": LIVE_COMBAT_SEED,
		"enemy_commander_id": "hero_vaska",
		"entry_counts": entry_counts,
		"enemy_counts": enemy_counts,
		"state": String(result.get("state", "")),
		"steps": int(result.get("steps", 0)),
		"town_owner": String(_town(session).get("owner", "")),
		"survivors": _stack_counts({"stacks": _town(session).get("garrison", [])}),
	}

func _live_raid_placement() -> Dictionary:
	return {
		"placement_id": "faction_mireclaw_raid_1",
		"encounter_id": "encounter_ford_reavers",
		"difficulty": "pressure",
		"combat_seed": LIVE_COMBAT_SEED,
		"spawned_by_faction_id": "faction_mireclaw",
		"target_kind": "town",
		"target_placement_id": TOWN_ID,
		"target_label": "Murkward Ford",
		"enemy_army": {
			"id": "army_ford_reavers",
			"name": "Ford Reavers",
			"stacks": [
				{"unit_id": "unit_blackbranch_cutthroat", "count": 20},
				{"unit_id": "unit_mire_slinger", "count": 8},
				{"unit_id": "unit_bog_brute", "count": 4},
			],
		},
		"enemy_commander_state": {
			"id": "enemy_commander:faction_mireclaw:hero_vaska",
			"roster_hero_id": "hero_vaska",
			"name": "Vaska Reedmaw",
			"faction_id": "faction_mireclaw",
			"archetype": "raider",
			"level": 2,
			"experience": 260,
			"command": {"attack": 3, "defense": 0, "knowledge": 1, "power": 1},
			"specialties": ["drillmaster", "drillmaster"],
			"battle_traits": ["vanguard", "linekeeper"],
			"artifacts": {"equipped": {"armor": "", "banner": "artifact_warcrest_pennon", "boots": "", "trinket": "", "trinket_2": ""}, "inventory": []},
			"spellbook": {"known_spell_ids": ["spell_relay_drum", "spell_cinder_burst", "spell_stone_veil", "spell_bloodwake_drum"], "mana": {"current": 12, "max": 12}},
		},
		"battle_context": {
			"type": "town_defense",
			"town_placement_id": TOWN_ID,
			"trigger_faction_id": "faction_mireclaw",
			"source_raid_id": "faction_mireclaw_raid_1",
			"defender_owner": "player",
		},
	}

func _resolve_like_live_validation(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var last_state := "continue"
	for step in range(1, 257):
		if session.battle.is_empty():
			return {"state": last_state, "steps": step - 1}
		var active_stack: Dictionary = BattleRulesScript.get_active_stack(session.battle)
		if active_stack.is_empty() or String(active_stack.get("side", "")) != "player":
			var ready_result: Dictionary = BattleRulesScript.resolve_if_battle_ready(session)
			last_state = String(ready_result.get("state", "continue"))
			if last_state in ["victory", "defeat", "retreat", "surrender", "stalemate", "hero_defeat", "town_lost"]:
				return {"state": last_state, "steps": step}
			continue
		_align_target(session)
		var action_id := _preferred_action(session)
		if action_id == "":
			return {"state": "invalid", "steps": step}
		var action_result: Dictionary = BattleRulesScript.perform_player_action(session, action_id)
		last_state = String(action_result.get("state", "continue"))
		if last_state in ["victory", "defeat", "retreat", "surrender", "stalemate", "hero_defeat", "town_lost"]:
			return {"state": last_state, "steps": step}
	return {"state": "stalled", "steps": 256}

func _align_target(session: SessionStateStoreScript.SessionData) -> void:
	var legal_ids: Array = BattleRulesScript.legal_attack_target_ids_for_active_stack(session.battle)
	var target_id := String(legal_ids[0]) if not legal_ids.is_empty() else String(BattleRulesScript._priority_enemy_stack_for_briefing(session.battle).get("battle_id", ""))
	for _attempt in range(8):
		if String(BattleRulesScript.get_selected_target(session.battle).get("battle_id", "")) == target_id:
			return
		BattleRulesScript.cycle_target(session, 1)

func _preferred_action(session: SessionStateStoreScript.SessionData) -> String:
	var surface: Dictionary = BattleRulesScript.get_action_surface(session)
	for action_id in ["shoot", "strike", "advance", "defend"]:
		var action: Dictionary = surface.get(action_id, {}) if surface.get(action_id, {}) is Dictionary else {}
		if not bool(action.get("disabled", true)):
			return action_id
	return ""

func _town(session: SessionStateStoreScript.SessionData) -> Dictionary:
	for value in session.overworld.get("towns", []):
		if value is Dictionary and String(value.get("placement_id", "")) == TOWN_ID:
			return value.duplicate(true)
	return {}

func _move_active_hero_away(session: SessionStateStoreScript.SessionData) -> void:
	var active_hero: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	active_hero["position"] = {"x": 5, "y": 3}
	session.overworld["hero"] = active_hero
	session.overworld["hero_position"] = {"x": 5, "y": 3}
	var player_heroes: Array = session.overworld.get("player_heroes", [])
	for index in range(player_heroes.size()):
		var hero: Dictionary = player_heroes[index] if player_heroes[index] is Dictionary else {}
		if String(hero.get("id", "")) == String(session.hero_id):
			hero["position"] = {"x": 5, "y": 3}
			player_heroes[index] = hero
	session.overworld["player_heroes"] = player_heroes

func _stack_counts(army_value: Variant) -> Dictionary:
	var result := {}
	var army: Dictionary = army_value if army_value is Dictionary else {}
	for value in army.get("stacks", []):
		if value is Dictionary and int(value.get("count", 0)) > 0:
			result[String(value.get("unit_id", ""))] = int(value.get("count", 0))
	return result

func _battle_side_counts(battle: Dictionary, side: String) -> Dictionary:
	var result := {}
	for value in battle.get("stacks", []):
		if value is Dictionary and String(value.get("side", "")) == side:
			result[String(value.get("unit_id", ""))] = int(ceil(float(value.get("total_health", 0)) / max(1.0, float(value.get("unit_hp", 1)))))
	return result

func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error(message)
	get_tree().quit(1)
