extends Node

const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const ScenarioFactoryScript = preload("res://scripts/core/ScenarioFactory.gd")
const ScenarioScriptRulesScript = preload("res://scripts/core/ScenarioScriptRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "REEDBARROW_FERRY_CHAPTER_TWO_SEQUENTIAL_VIABILITY_REPORT"
const SCENARIO_ID := "reedbarrow-ferry"
const LOCAL_ARMY_ID := "army_reedbarrow_ferry_watch"
const SHARED_ARMY_ID := "army_ashgrove_watch"
const NIGHTGLASS_ARMY_ID := "army_nightglass_redoubt_watch"
const REQUIRED_ENCOUNTERS := ["reedbarrow_levee_totemists", "barrow_pickets", "reedbarrow_chain"]
const CONTROL_OPENING_GUARDS := 9
const REINFORCEMENT_HOOK_ID := "levee_totemist_survivors_rally"
const SELECTED_REINFORCEMENT_GUARDS := 11
const VETERAN_RECRUIT_GUARDS := 1
const OTHER_PREPARED_COUNTS := {
	"unit_ember_archer": 5,
	"unit_citadel_pikeward": 1,
	"unit_mire_slinger": 7,
	"unit_blackbranch_cutthroat": 7,
	"unit_bog_brute": 3,
}
const LIVE_REEDBARROW_GARRISON := {
	"unit_bog_brute": 9,
	"unit_mire_slinger": 3,
	"unit_mireclaw_reedsnare_kin": 15,
}

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ContentService.clear_cache()
	var content_contract: Dictionary = _assert_content_contract()
	if _failed:
		return
	var control: Dictionary = _run_sequence(false)
	if _failed:
		return
	var selected: Dictionary = _run_sequence(true)
	if _failed:
		return
	if control.get("states", []) != ["victory", "victory", "victory", "defeat"]:
		_fail("Shared-army control did not reproduce the exact Reedbarrow defeat: %s" % JSON.stringify(control))
		return
	if control.get("post_guard_counts", []) != [10, 10, 9, 0]:
		_fail("Shared-army control changed its exact guard attrition: %s" % JSON.stringify(control))
		return
	if selected.get("states", []) != ["victory", "victory", "victory", "victory"]:
		_fail("Staged reinforcement did not complete the exact chapter-two battle sequence: %s" % JSON.stringify(selected))
		return
	if selected.get("post_guard_counts", []) != [21, 21, 20, 3]:
		_fail("Staged reinforcement changed its exact guard survivor contract: %s" % JSON.stringify(selected))
		return
	if selected.get("final_enemy_entry", {}) != LIVE_REEDBARROW_GARRISON:
		_fail("Staged sequence did not retain the exact live Reedbarrow force: %s" % JSON.stringify(selected))
		return
	if selected.get("reinforcement_fired_ids", []) != [REINFORCEMENT_HOOK_ID] or not bool(selected.get("army_mirrors_exact", false)):
		_fail("Reedbarrow staged reinforcement did not fire once with exact active-army mirrors: %s" % JSON.stringify(selected))
		return
	if _assert_content_contract() != content_contract:
		_fail("Sequential control mutated the authored content contract.")
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
	if String(scenario.get("player_army_id", "")) != SHARED_ARMY_ID:
		_fail("Reedbarrow Ferry does not use the shared opening army.")
		return {}
	var local_counts: Dictionary = _stack_counts(ContentService.get_army_group(LOCAL_ARMY_ID))
	var shared_counts: Dictionary = _stack_counts(ContentService.get_army_group(SHARED_ARMY_ID))
	var nightglass_counts: Dictionary = _stack_counts(ContentService.get_army_group(NIGHTGLASS_ARMY_ID))
	var expected_local := {"unit_river_guard": 20, "unit_ember_archer": 4, "unit_citadel_pikeward": 1}
	var expected_shared := {"unit_river_guard": 9, "unit_ember_archer": 4, "unit_citadel_pikeward": 1}
	var expected_nightglass := {"unit_river_guard": 32, "unit_ember_archer": 4, "unit_citadel_pikeward": 1}
	if local_counts != expected_local or shared_counts != expected_shared or nightglass_counts != expected_nightglass:
		_fail("Reedbarrow local/shared/Nightglass army contracts drifted: local=%s shared=%s nightglass=%s" % [JSON.stringify(local_counts), JSON.stringify(shared_counts), JSON.stringify(nightglass_counts)])
		return {}
	var reinforcement_hook := _script_hook(scenario, REINFORCEMENT_HOOK_ID)
	if not _reinforcement_hook_exact(reinforcement_hook, "reedbarrow_levee_totemists", SELECTED_REINFORCEMENT_GUARDS, "Levee wardens cut loose from the broken totems and join Caelen's field column for the ferry advance."):
		_fail("Reedbarrow first-victory reinforcement contract drifted: %s" % JSON.stringify(reinforcement_hook))
		return {}
	for chapter_id in ["stonewake-watch", SCENARIO_ID, "nightglass-redoubt"]:
		if String(ContentService.get_scenario(chapter_id).get("player_army_id", "")) != SHARED_ARMY_ID:
			_fail("Stonewake chapter %s no longer uses the shared opening army." % chapter_id)
			return {}
	return {
		"local_army_id": LOCAL_ARMY_ID,
		"local_counts": local_counts,
		"shared_army_id": SHARED_ARMY_ID,
		"shared_counts": shared_counts,
		"nightglass_screened_control_id": NIGHTGLASS_ARMY_ID,
		"nightglass_screened_control_counts": nightglass_counts,
		"reinforcement_hook": reinforcement_hook,
		"all_chapters_shared": true,
	}

func _run_sequence(use_authored_reinforcement: bool) -> Dictionary:
	var session: SessionStateStoreScript.SessionData = ScenarioFactoryScript.create_session(
		SCENARIO_ID,
		"normal",
		SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN
	)
	if not use_authored_reinforcement:
		_suppress_reinforcement_hook(session)
	var prepared_counts: Dictionary = OTHER_PREPARED_COUNTS.duplicate(true)
	prepared_counts["unit_river_guard"] = CONTROL_OPENING_GUARDS + VETERAN_RECRUIT_GUARDS
	_set_live_army(session, prepared_counts)
	_set_live_commander(session)
	var session_identity_before: Dictionary = {
		"scenario_id": session.scenario_id,
		"launch_mode": session.launch_mode,
		"difficulty": session.difficulty,
		"day": session.day,
	}
	var rows: Array = []
	var states: Array = []
	var post_guard_counts: Array = []
	for placement_id in REQUIRED_ENCOUNTERS:
		var encounter: Dictionary = _encounter(placement_id)
		session.battle = BattleRulesScript.create_battle_payload(session, encounter)
		var entry_counts: Dictionary = _battle_side_counts(session.battle, "player")
		var spell_result := {}
		if placement_id == "reedbarrow_chain":
			spell_result = BattleRulesScript.cast_player_spell(session, "spell_stone_veil")
			if not bool(spell_result.get("ok", false)):
				_fail("Routed Ferry Chain Stone Veil cast failed: %s" % JSON.stringify(spell_result))
				return {}
		var result: Dictionary = _resolve_like_live_validation(session)
		var state := String(result.get("state", ""))
		var survivors: Dictionary = _stack_counts(session.overworld.get("army", {}))
		var guard_count := int(survivors.get("unit_river_guard", 0))
		rows.append({
			"placement_id": placement_id,
			"entry": entry_counts,
			"spell_state": String(spell_result.get("state", "")),
			"state": state,
			"survivors": survivors,
		})
		states.append(state)
		post_guard_counts.append(guard_count)
		if state != "victory":
			return {"opening_guard_count": CONTROL_OPENING_GUARDS, "states": states, "post_guard_counts": post_guard_counts, "rows": rows}
	_set_reedbarrow_live_garrison(session)
	session.battle = BattleRulesScript.create_town_assault_payload(session, "reedbarrow_ferry")
	var town_entry: Dictionary = _battle_side_counts(session.battle, "player")
	var enemy_entry: Dictionary = _battle_side_counts(session.battle, "enemy")
	var final_spell: Dictionary = BattleRulesScript.cast_player_spell(session, "spell_stone_veil")
	if not bool(final_spell.get("ok", false)):
		_fail("Routed Reedbarrow Stone Veil cast failed: %s" % JSON.stringify(final_spell))
		return {}
	var town_result: Dictionary = _resolve_like_live_validation(session)
	var town_state := String(town_result.get("state", ""))
	var town_survivors: Dictionary = _stack_counts(session.overworld.get("army", {}))
	rows.append({
		"placement_id": "reedbarrow_ferry",
		"entry": town_entry,
		"enemy": enemy_entry,
		"spell_state": String(final_spell.get("state", "")),
		"state": town_state,
		"survivors": town_survivors,
	})
	states.append(town_state)
	post_guard_counts.append(int(town_survivors.get("unit_river_guard", 0)))
	var session_identity_after: Dictionary = {
		"scenario_id": session.scenario_id,
		"launch_mode": session.launch_mode,
		"difficulty": session.difficulty,
		"day": session.day,
	}
	if session_identity_after != session_identity_before:
		_fail("Sequential battle control changed session identity: before=%s after=%s" % [JSON.stringify(session_identity_before), JSON.stringify(session_identity_after)])
		return {}
	return {
		"opening_guard_count": CONTROL_OPENING_GUARDS,
		"prepared_guard_count": CONTROL_OPENING_GUARDS + VETERAN_RECRUIT_GUARDS,
		"reinforcement_guard_count": SELECTED_REINFORCEMENT_GUARDS if use_authored_reinforcement else 0,
		"reinforcement_fired_ids": [REINFORCEMENT_HOOK_ID] if use_authored_reinforcement and REINFORCEMENT_HOOK_ID in session.overworld.get("scenario_script_state", {}).get("fired_hook_ids", []) else [],
		"army_mirrors_exact": _army_mirrors_exact(session),
		"states": states,
		"post_guard_counts": post_guard_counts,
		"final_enemy_entry": enemy_entry,
		"session_identity_exact": true,
		"rows": rows,
	}

func _set_live_army(session: SessionStateStoreScript.SessionData, counts: Dictionary) -> void:
	var army: Dictionary = ContentService.get_army_group(SHARED_ARMY_ID).duplicate(true)
	army["stacks"] = [
		{"unit_id": "unit_river_guard", "count": int(counts.get("unit_river_guard", 0))},
		{"unit_id": "unit_ember_archer", "count": int(counts.get("unit_ember_archer", 0))},
		{"unit_id": "unit_citadel_pikeward", "count": int(counts.get("unit_citadel_pikeward", 0))},
		{"unit_id": "unit_mire_slinger", "count": int(counts.get("unit_mire_slinger", 0))},
		{"unit_id": "unit_blackbranch_cutthroat", "count": int(counts.get("unit_blackbranch_cutthroat", 0))},
		{"unit_id": "unit_bog_brute", "count": int(counts.get("unit_bog_brute", 0))},
	]
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

func _suppress_reinforcement_hook(session: SessionStateStoreScript.SessionData) -> void:
	ScenarioScriptRulesScript.normalize_script_state(session)
	var state: Dictionary = session.overworld.get("scenario_script_state", {})
	state["fired_hook_ids"] = [REINFORCEMENT_HOOK_ID]
	session.overworld["scenario_script_state"] = state

func _script_hook(scenario: Dictionary, hook_id: String) -> Dictionary:
	for value in scenario.get("script_hooks", []):
		if value is Dictionary and String(value.get("id", "")) == hook_id:
			return value.duplicate(true)
	return {}

func _reinforcement_hook_exact(hook: Dictionary, placement_id: String, guard_count: int, message: String) -> bool:
	var effects: Array = hook.get("effects", [])
	var units: Dictionary = effects[0].get("units", {}) if effects.size() == 2 and effects[0] is Dictionary else {}
	return hook.get("conditions", []) == [{"type": "encounter_resolved", "placement_id": placement_id}] \
		and effects.size() == 2 \
		and String(effects[0].get("type", "")) == "add_army_units" \
		and units.size() == 1 and int(units.get("unit_river_guard", 0)) == guard_count \
		and effects[1] is Dictionary and String(effects[1].get("type", "")) == "message" \
		and String(effects[1].get("text", "")) == message

func _army_mirrors_exact(session: SessionStateStoreScript.SessionData) -> bool:
	var army: Dictionary = session.overworld.get("army", {})
	if session.overworld.get("hero", {}).get("army", {}) != army:
		return false
	for value in session.overworld.get("player_heroes", []):
		if value is Dictionary and String(value.get("id", "")) == String(session.overworld.get("active_hero_id", "")):
			return value.get("army", {}) == army
	return false

func _set_live_commander(session: SessionStateStoreScript.SessionData) -> void:
	var active_hero: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	active_hero["level"] = 2
	active_hero["experience"] = 320
	active_hero["next_level_experience"] = 700
	active_hero["specialties"] = ["armsmaster", "borderwarden"]
	active_hero["pending_specialty_choices"] = []
	active_hero["command"] = {"attack": 2, "defense": 2, "power": 0, "knowledge": 1}
	active_hero["spellbook"] = {"known_spell_ids": ["spell_trailglyph", "spell_stone_veil", "spell_lantern_phalanx"], "mana": {"current": 12, "max": 12}}
	active_hero["artifacts"] = {"equipped": {"armor": "artifact_bastion_gorget", "banner": "", "boots": "", "trinket": "", "trinket_2": ""}, "inventory": []}
	session.overworld["hero"] = active_hero
	var player_heroes: Array = session.overworld.get("player_heroes", [])
	for index in range(player_heroes.size()):
		var hero: Dictionary = player_heroes[index] if player_heroes[index] is Dictionary else {}
		if String(hero.get("id", "")) == String(session.hero_id):
			for key in ["level", "experience", "next_level_experience", "specialties", "pending_specialty_choices", "command", "spellbook", "artifacts"]:
				hero[key] = active_hero[key].duplicate(true) if active_hero[key] is Array or active_hero[key] is Dictionary else active_hero[key]
			player_heroes[index] = hero
	session.overworld["player_heroes"] = player_heroes

func _set_reedbarrow_live_garrison(session: SessionStateStoreScript.SessionData) -> void:
	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		var town: Dictionary = towns[index] if towns[index] is Dictionary else {}
		if String(town.get("placement_id", "")) == "reedbarrow_ferry":
			town["garrison"] = [
				{"unit_id": "unit_bog_brute", "count": 9},
				{"unit_id": "unit_mire_slinger", "count": 3},
				{"unit_id": "unit_mireclaw_reedsnare_kin", "count": 15},
			]
			towns[index] = town
			break
	session.overworld["towns"] = towns

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
