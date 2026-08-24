extends Node

const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const ScenarioFactoryScript = preload("res://scripts/core/ScenarioFactory.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "STONEWAKE_WATCH_CHAPTER_ONE_SEQUENTIAL_VIABILITY_REPORT"
const SCENARIO_ID := "stonewake-watch"
const LOCAL_ARMY_ID := "army_stonewake_basin_watch"
const SHARED_ARMY_ID := "army_ashgrove_watch"
const REQUIRED_ENCOUNTERS := ["stonewake_reed_totemists", "willow_mill", "sluice_band"]
const CONTROL_OPENING_GUARDS := 9
const SELECTED_OPENING_GUARDS := 25
const TOWN_RECRUIT_GUARDS := 11

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ContentService.clear_cache()
	var content_contract := _assert_content_contract()
	if _failed:
		return
	var control := _run_sequence(CONTROL_OPENING_GUARDS)
	if _failed:
		return
	var selected := _run_sequence(SELECTED_OPENING_GUARDS)
	if _failed:
		return
	if control.get("states", []) != ["victory", "victory", "defeat"]:
		_fail("Shared-army control did not reproduce the exact Sluice defeat: %s" % JSON.stringify(control))
		return
	if selected.get("states", []) != ["victory", "victory", "victory", "victory"]:
		_fail("Scenario-local army did not complete the exact encounter and town sequence: %s" % JSON.stringify(selected))
		return
	if selected.get("post_battle_guard_counts", []) != [36, 30, 21, 21]:
		_fail("Scenario-local sequence changed its exact survivor contract: %s" % JSON.stringify(selected))
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"content": content_contract,
		"control": control,
		"selected": selected,
	})])
	get_tree().quit(0)

func _assert_content_contract() -> Dictionary:
	var scenario: Dictionary = ContentService.get_scenario(SCENARIO_ID)
	if String(scenario.get("player_army_id", "")) != LOCAL_ARMY_ID:
		_fail("Stonewake Watch does not use its scenario-local army.")
		return {}
	var local_counts := _stack_counts(ContentService.get_army_group(LOCAL_ARMY_ID))
	var shared_counts := _stack_counts(ContentService.get_army_group(SHARED_ARMY_ID))
	var expected_local := {"unit_river_guard": 25, "unit_ember_archer": 4, "unit_citadel_pikeward": 1}
	var expected_shared := {"unit_river_guard": 9, "unit_ember_archer": 4, "unit_citadel_pikeward": 1}
	if local_counts != expected_local or shared_counts != expected_shared:
		_fail("Stonewake local/shared army contracts drifted: local=%s shared=%s" % [JSON.stringify(local_counts), JSON.stringify(shared_counts)])
		return {}
	for later_id in ["reedbarrow-ferry", "nightglass-redoubt"]:
		if String(ContentService.get_scenario(later_id).get("player_army_id", "")) != SHARED_ARMY_ID:
			_fail("Later Stonewake chapter %s no longer uses the shared army." % later_id)
			return {}
	return {"local_army_id": LOCAL_ARMY_ID, "local_counts": local_counts, "shared_army_id": SHARED_ARMY_ID, "shared_counts": shared_counts, "later_chapters_shared": true}

func _run_sequence(opening_guard_count: int) -> Dictionary:
	var session: SessionStateStoreScript.SessionData = ScenarioFactoryScript.create_session(
		SCENARIO_ID,
		"normal",
		SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN
	)
	var prepared_army := ContentService.get_army_group(LOCAL_ARMY_ID)
	prepared_army["stacks"] = prepared_army.get("stacks", []).duplicate(true)
	for stack in prepared_army.get("stacks", []):
		if stack is Dictionary and String(stack.get("unit_id", "")) == "unit_river_guard":
			stack["count"] = opening_guard_count + TOWN_RECRUIT_GUARDS
	_set_live_army(session, prepared_army)
	var rows := []
	var states := []
	var post_counts := []
	for placement_id in REQUIRED_ENCOUNTERS:
		var encounter := _encounter(placement_id)
		session.battle = BattleRulesScript.create_battle_payload(session, encounter)
		var entry_counts := _battle_side_counts(session.battle, "player")
		var result := _resolve_like_live_validation(session)
		var state := String(result.get("state", ""))
		var guard_count := int(_stack_counts(session.overworld.get("army", {})).get("unit_river_guard", 0))
		rows.append({"placement_id": placement_id, "entry_counts": entry_counts, "state": state, "guard_count": guard_count})
		states.append(state)
		post_counts.append(guard_count)
		if state != "victory":
			break
	if states.size() == REQUIRED_ENCOUNTERS.size() and states[-1] == "victory":
		_equip_bastion_gorget(session)
		session.battle = BattleRulesScript.create_town_assault_payload(session, "murkward_ford")
		var town_entry := _battle_side_counts(session.battle, "player")
		var town_result := _resolve_like_live_validation(session)
		var town_state := String(town_result.get("state", ""))
		var town_guards := int(_stack_counts(session.overworld.get("army", {})).get("unit_river_guard", 0))
		rows.append({"placement_id": "murkward_ford", "entry_counts": town_entry, "state": town_state, "guard_count": town_guards})
		states.append(town_state)
		post_counts.append(town_guards)
	return {"opening_guard_count": opening_guard_count, "prepared_guard_count": opening_guard_count + TOWN_RECRUIT_GUARDS, "states": states, "post_battle_guard_counts": post_counts, "rows": rows}

func _set_live_army(session: SessionStateStoreScript.SessionData, army: Dictionary) -> void:
	session.overworld["army"] = army.duplicate(true)
	var active_hero: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	active_hero["army"] = army.duplicate(true)
	session.overworld["hero"] = active_hero
	var player_heroes: Array = session.overworld.get("player_heroes", [])
	for index in range(player_heroes.size()):
		var hero: Dictionary = player_heroes[index] if player_heroes[index] is Dictionary else {}
		if String(hero.get("id", "")) == String(session.hero_id):
			hero["army"] = army.duplicate(true)
			player_heroes[index] = hero
	session.overworld["player_heroes"] = player_heroes

func _equip_bastion_gorget(session: SessionStateStoreScript.SessionData) -> void:
	var active_hero: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	var artifacts: Dictionary = active_hero.get("artifacts", {}) if active_hero.get("artifacts", {}) is Dictionary else {}
	var equipped: Dictionary = artifacts.get("equipped", {}) if artifacts.get("equipped", {}) is Dictionary else {}
	equipped["armor"] = "artifact_bastion_gorget"
	artifacts["equipped"] = equipped
	active_hero["artifacts"] = artifacts
	session.overworld["hero"] = active_hero
	var player_heroes: Array = session.overworld.get("player_heroes", [])
	for index in range(player_heroes.size()):
		var hero: Dictionary = player_heroes[index] if player_heroes[index] is Dictionary else {}
		if String(hero.get("id", "")) == String(session.hero_id):
			hero["artifacts"] = artifacts.duplicate(true)
			player_heroes[index] = hero
	session.overworld["player_heroes"] = player_heroes

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

func _encounter(placement_id: String) -> Dictionary:
	for value in ContentService.get_scenario(SCENARIO_ID).get("encounters", []):
		if value is Dictionary and String(value.get("placement_id", "")) == placement_id:
			return value.duplicate(true)
	return {}

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
