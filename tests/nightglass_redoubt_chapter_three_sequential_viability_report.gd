extends Node

const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const ScenarioFactoryScript = preload("res://scripts/core/ScenarioFactory.gd")
const ScenarioScriptRulesScript = preload("res://scripts/core/ScenarioScriptRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "NIGHTGLASS_REDOUBT_CHAPTER_THREE_SEQUENTIAL_VIABILITY_REPORT"
const SCENARIO_ID := "nightglass-redoubt"
const LOCAL_ARMY_ID := "army_nightglass_redoubt_watch"
const SHARED_ARMY_ID := "army_ashgrove_watch"
const REEDBARROW_ARMY_ID := "army_reedbarrow_ferry_watch"
const CONTROL_OPENING_GUARDS := 9
const REINFORCEMENT_HOOK_ID := "bone_ferry_survivors_rally"
const REJECTED_REINFORCEMENT_GUARDS := 20
const SELECTED_REINFORCEMENT_GUARDS := 23
const FERRY_RECRUIT_GUARDS := 2
const SESSION_SAMPLE_COUNT := 1024
const OBSERVED_SESSION_IDS := ["362289", "362692"]
const REQUIRED_ENCOUNTERS := ["nightglass_bone_ferry_watch", "nightglass_drum_circle", "mirror_causeway"]
const PREPARED_OTHER_COUNTS := {
	"unit_ember_archer": 5,
	"unit_citadel_pikeward": 1,
	"unit_bog_brute": 5,
	"unit_blackbranch_cutthroat": 6,
	"unit_mire_slinger": 1,
}
const LIVE_NIGHTGLASS_GARRISON := {
	"unit_bog_brute": 10,
	"unit_blackbranch_cutthroat": 11,
	"unit_gorefen_ripper": 1,
}
const EXPECTED_ENEMY_ENTRIES := [
	{"unit_gorefen_ripper": 3, "unit_blackbranch_cutthroat": 6, "unit_mire_slinger": 4},
	{"unit_bog_brute": 3, "unit_blackbranch_cutthroat": 4, "unit_mire_slinger": 3, "unit_gorefen_ripper": 1},
	{"unit_gorefen_ripper": 3, "unit_blackbranch_cutthroat": 6, "unit_mire_slinger": 4},
	{"unit_gorefen_ripper": 3, "unit_blackbranch_cutthroat": 6, "unit_mire_slinger": 4},
	LIVE_NIGHTGLASS_GARRISON,
]

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ContentService.clear_cache()
	var content_contract: Dictionary = _assert_content_contract()
	if _failed:
		return
	var control: Dictionary = _run_required_prefix(0, false)
	if _failed:
		return
	var rejected_prefix: Dictionary = _run_required_prefix(REJECTED_REINFORCEMENT_GUARDS, false)
	if _failed:
		return
	var selected_prefix: Dictionary = _run_required_prefix(SELECTED_REINFORCEMENT_GUARDS, true)
	if _failed:
		return
	if control.get("states", []) != ["victory", "victory", "defeat"]:
		_fail("Shared-army control did not reproduce the exact Mirror Causeway defeat: %s" % JSON.stringify(control))
		return
	if control.get("guard_counts", []) != [11, 11, 0]:
		_fail("Shared-army control changed its exact guard attrition: %s" % JSON.stringify(control))
		return
	if rejected_prefix.get("states", []) != ["victory", "victory", "victory"] or rejected_prefix.get("guard_counts", []) != [31, 31, 31]:
		_fail("Rejected 20-guard reinforcement control changed its exact required-encounter prefix: %s" % JSON.stringify(rejected_prefix))
		return
	if selected_prefix.get("states", []) != ["victory", "victory", "victory"] or selected_prefix.get("guard_counts", []) != [34, 34, 34]:
		_fail("Selected 23-guard staged reinforcement changed its exact required-encounter prefix: %s" % JSON.stringify(selected_prefix))
		return
	var expected_selected_prefix_armies := [
		{"unit_river_guard": 34, "unit_ember_archer": 4, "unit_citadel_pikeward": 1, "unit_bog_brute": 5},
		{"unit_river_guard": 34, "unit_ember_archer": 1, "unit_bog_brute": 5},
		{"unit_river_guard": 34},
	]
	if selected_prefix.get("army_counts", []) != expected_selected_prefix_armies:
		_fail("Selected Nightglass prefix survivor arrays drifted: %s" % JSON.stringify(selected_prefix))
		return
	if selected_prefix.get("enemy_entries", []) != EXPECTED_ENEMY_ENTRIES.slice(0, 3):
		_fail("Selected Nightglass prefix changed an enemy entry force: %s" % JSON.stringify(selected_prefix))
		return
	if selected_prefix.get("hero_states", []) != _expected_selected_prefix_hero_states():
		_fail("Selected Nightglass prefix commander/spell progression drifted: %s" % JSON.stringify(selected_prefix))
		return
	if selected_prefix.get("reinforcement_fired_ids", []) != [REINFORCEMENT_HOOK_ID] or not bool(selected_prefix.get("army_mirrors_exact", false)):
		_fail("Nightglass staged reinforcement did not fire once with exact active-army mirrors: %s" % JSON.stringify(selected_prefix))
		return
	var rejected_observed := {}
	for session_id_value in OBSERVED_SESSION_IDS:
		rejected_observed[String(session_id_value)] = _run_session_tail(rejected_prefix.get("session", {}), String(session_id_value))
	if rejected_observed.get("362289", {}).get("final_state", "") != "defeat" or int(rejected_observed.get("362289", {}).get("post_interrupt_guards", -1)) != 20:
		_fail("Rejected opening did not reproduce live session 362289's 20-guard post-intercept town defeat: %s" % JSON.stringify(rejected_observed))
		return
	if rejected_observed.get("362692", {}).get("final_state", "") != "defeat" or int(rejected_observed.get("362692", {}).get("post_interrupt_guards", -1)) != 19:
		_fail("Rejected opening did not reproduce live session 362692's 19-guard post-intercept town defeat: %s" % JSON.stringify(rejected_observed))
		return
	var selected_matrix: Dictionary = _run_selected_seed_matrix(selected_prefix.get("session", {}))
	if int(selected_matrix.get("evaluated_count", 0)) != SESSION_SAMPLE_COUNT + OBSERVED_SESSION_IDS.size() or int(selected_matrix.get("failure_count", -1)) != 0:
		_fail("Selected Nightglass opening did not win the full session-derived raid-seed matrix: %s" % JSON.stringify(selected_matrix))
		return
	if int(selected_matrix.get("minimum_post_interrupt_guards", -1)) != 21 or int(selected_matrix.get("minimum_final_guards", -1)) != 1:
		_fail("Selected seed matrix changed its exact fail-closed survivor floor: %s" % JSON.stringify(selected_matrix))
		return
	var worst: Dictionary = selected_matrix.get("worst", {})
	if String(worst.get("session_id", "")) != "376090" or int(worst.get("combat_seed", 0)) != 1590943562 or int(worst.get("post_interrupt_guards", 0)) != 21 or int(worst.get("final_guards", 0)) != 1:
		_fail("Selected seed matrix changed its exact worst screened control: %s" % JSON.stringify(selected_matrix))
		return
	if not bool(control.get("session_identity_exact", false)) or not bool(rejected_prefix.get("session_identity_exact", false)) or not bool(selected_prefix.get("session_identity_exact", false)) or not bool(selected_matrix.get("session_identity_exact", false)):
		_fail("Sequential or matrix control changed session identity authority.")
		return
	if _assert_content_contract() != content_contract:
		_fail("Sequential controls mutated authored content.")
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"content": content_contract,
		"control": control,
		"rejected_observed": rejected_observed,
		"selected_prefix": selected_prefix,
		"selected_matrix": selected_matrix,
	})])
	get_tree().quit(0)

func _assert_content_contract() -> Dictionary:
	var scenario: Dictionary = ContentService.get_scenario(SCENARIO_ID)
	if String(scenario.get("player_army_id", "")) != SHARED_ARMY_ID:
		_fail("Nightglass Redoubt does not use the shared opening army.")
		return {}
	var local_counts: Dictionary = _stack_counts(ContentService.get_army_group(LOCAL_ARMY_ID))
	var shared_counts: Dictionary = _stack_counts(ContentService.get_army_group(SHARED_ARMY_ID))
	var reedbarrow_counts: Dictionary = _stack_counts(ContentService.get_army_group(REEDBARROW_ARMY_ID))
	var expected_local := {"unit_river_guard": 32, "unit_ember_archer": 4, "unit_citadel_pikeward": 1}
	var expected_shared := {"unit_river_guard": 9, "unit_ember_archer": 4, "unit_citadel_pikeward": 1}
	var expected_reedbarrow := {"unit_river_guard": 20, "unit_ember_archer": 4, "unit_citadel_pikeward": 1}
	if local_counts != expected_local or shared_counts != expected_shared or reedbarrow_counts != expected_reedbarrow:
		_fail("Nightglass/local/shared army contracts drifted: local=%s shared=%s reedbarrow=%s" % [JSON.stringify(local_counts), JSON.stringify(shared_counts), JSON.stringify(reedbarrow_counts)])
		return {}
	var ferry_recruits := {}
	for hook_value in scenario.get("script_hooks", []):
		if hook_value is Dictionary and String(hook_value.get("id", "")) == "ferry_veterans_hold_fast":
			for effect_value in hook_value.get("effects", []):
				if effect_value is Dictionary and String(effect_value.get("type", "")) == "town_add_recruits":
					var raw_recruits: Dictionary = effect_value.get("recruits", {})
					ferry_recruits = {
						"unit_river_guard": int(raw_recruits.get("unit_river_guard", 0)),
						"unit_ember_archer": int(raw_recruits.get("unit_ember_archer", 0)),
					}
	if ferry_recruits != {"unit_river_guard": 2, "unit_ember_archer": 1}:
		_fail("Nightglass ferry veteran recruit contract drifted: %s" % JSON.stringify(ferry_recruits))
		return {}
	var reinforcement_hook := _script_hook(scenario, REINFORCEMENT_HOOK_ID)
	if not _reinforcement_hook_exact(reinforcement_hook, "nightglass_bone_ferry_watch", SELECTED_REINFORCEMENT_GUARDS, "Freed ferry crews and marsh wardens form behind Caelen once the Bone Ferry screen breaks, ready for the causeway."):
		_fail("Nightglass first-victory reinforcement contract drifted: %s" % JSON.stringify(reinforcement_hook))
		return {}
	for chapter_id in ["stonewake-watch", "reedbarrow-ferry", SCENARIO_ID]:
		if String(ContentService.get_scenario(chapter_id).get("player_army_id", "")) != SHARED_ARMY_ID:
			_fail("Stonewake chapter %s no longer uses the shared opening army." % chapter_id)
			return {}
	return {
		"screened_local_control_id": LOCAL_ARMY_ID,
		"screened_local_control_counts": local_counts,
		"shared_counts": shared_counts,
		"reedbarrow_counts": reedbarrow_counts,
		"ferry_recruits": ferry_recruits,
		"reinforcement_hook": reinforcement_hook,
		"all_chapters_shared": true,
	}

func _run_required_prefix(reinforcement_guards: int, use_authored_reinforcement: bool) -> Dictionary:
	var session: SessionStateStoreScript.SessionData = ScenarioFactoryScript.create_session(
		SCENARIO_ID,
		"normal",
		SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN
	)
	if not use_authored_reinforcement:
		_suppress_reinforcement_hook(session)
	_set_prepared_army(session, CONTROL_OPENING_GUARDS + FERRY_RECRUIT_GUARDS, SHARED_ARMY_ID)
	_set_live_commander(session)
	var identity_before := {
		"scenario_id": session.scenario_id,
		"launch_mode": session.launch_mode,
		"difficulty": session.difficulty,
	}
	var states: Array = []
	var guard_counts: Array = []
	var army_counts: Array = []
	var enemy_entries: Array = []
	var hero_states: Array = []
	for encounter_index in range(REQUIRED_ENCOUNTERS.size()):
		var placement_id: String = REQUIRED_ENCOUNTERS[encounter_index]
		if placement_id == "mirror_causeway":
			session.day = 2
			_restore_mana(session)
		var encounter: Dictionary = _encounter(placement_id)
		session.battle = BattleRulesScript.create_battle_payload(session, encounter)
		enemy_entries.append(_battle_side_counts(session.battle, "enemy"))
		_advance_to_player(session)
		_align_target(session)
		var spell_result: Dictionary = BattleRulesScript.cast_player_spell(session, "spell_stone_veil")
		if not bool(spell_result.get("ok", false)):
			_fail("Routed Stone Veil failed at %s: %s" % [placement_id, JSON.stringify(spell_result)])
			return {}
		var result: Dictionary = _resolve_like_live_validation(session)
		var state := String(result.get("state", ""))
		if state == "victory" and encounter_index == 0 and not use_authored_reinforcement and reinforcement_guards > 0:
			ScenarioScriptRulesScript._add_army_units(session, {"unit_river_guard": reinforcement_guards})
		var survivors: Dictionary = _stack_counts(session.overworld.get("army", {}))
		states.append(state)
		guard_counts.append(int(survivors.get("unit_river_guard", 0)))
		army_counts.append(survivors)
		hero_states.append(_hero_state(session))
		if state != "victory":
			break
	var identity_after := {
		"scenario_id": session.scenario_id,
		"launch_mode": session.launch_mode,
		"difficulty": session.difficulty,
	}
	return {
		"opening_guards": CONTROL_OPENING_GUARDS,
		"prepared_guards": CONTROL_OPENING_GUARDS + FERRY_RECRUIT_GUARDS,
		"reinforcement_guards": reinforcement_guards,
		"army_id": SHARED_ARMY_ID,
		"reinforcement_fired_ids": [REINFORCEMENT_HOOK_ID] if use_authored_reinforcement and REINFORCEMENT_HOOK_ID in session.overworld.get("scenario_script_state", {}).get("fired_hook_ids", []) else [],
		"army_mirrors_exact": _army_mirrors_exact(session),
		"states": states,
		"guard_counts": guard_counts,
		"army_counts": army_counts,
		"enemy_entries": enemy_entries,
		"hero_states": hero_states,
		"session": session.to_dict(),
		"session_identity_exact": identity_before == identity_after,
	}

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

func _run_session_tail(prefix_payload: Dictionary, session_id: String) -> Dictionary:
	var session := SessionStateStoreScript.SessionData.new()
	session.from_dict(prefix_payload)
	session.session_id = session_id
	var identity_before := {
		"scenario_id": session.scenario_id,
		"launch_mode": session.launch_mode,
		"difficulty": session.difficulty,
		"session_id": session.session_id,
	}
	var combat_seed := hash("%s:%d:%s" % [session.session_id, session.day, "faction_mireclaw_raid_1"])
	var route_interrupt: Dictionary = _route_interrupt_encounter(combat_seed)
	_install_route_interrupt(session, route_interrupt)
	session.battle = BattleRulesScript.create_battle_payload(session, route_interrupt)
	var route_enemy_entry: Dictionary = _battle_side_counts(session.battle, "enemy")
	_advance_to_player(session)
	_align_target(session)
	var interrupt_spell_target := String(BattleRulesScript.get_selected_target(session.battle).get("battle_id", ""))
	var interrupt_spell: Dictionary = BattleRulesScript.cast_player_spell(session, "spell_stone_veil")
	if not bool(interrupt_spell.get("ok", false)):
		return {"session_id": session_id, "combat_seed": combat_seed, "pass": false, "state": "interrupt_spell_failed"}
	var interrupt_result: Dictionary = _resolve_like_live_validation(session)
	var interrupt_state := String(interrupt_result.get("state", ""))
	var interrupt_survivors: Dictionary = _stack_counts(session.overworld.get("army", {}))
	var post_interrupt_guards := int(interrupt_survivors.get("unit_river_guard", 0))
	if interrupt_state != "victory":
		return {
			"session_id": session_id,
			"combat_seed": combat_seed,
			"interrupt_state": interrupt_state,
			"interrupt_spell_target": interrupt_spell_target,
			"interrupt_actions": interrupt_result.get("actions", []),
			"post_interrupt_guards": post_interrupt_guards,
			"final_state": "not_run",
			"final_guards": 0,
			"enemy_entries_exact": route_enemy_entry == EXPECTED_ENEMY_ENTRIES[3],
			"session_identity_exact": _tail_identity(session) == identity_before,
			"pass": false,
		}
	_set_nightglass_garrison(session)
	session.battle = BattleRulesScript.create_town_assault_payload(session, "nightglass_redoubt")
	var town_seed := int(session.battle.get("combat_seed", 0))
	var town_enemy_entry: Dictionary = _battle_side_counts(session.battle, "enemy")
	_advance_to_player(session)
	_align_target(session)
	var town_spell: Dictionary = BattleRulesScript.cast_player_spell(session, "spell_stone_veil")
	if not bool(town_spell.get("ok", false)):
		return {"session_id": session_id, "combat_seed": combat_seed, "town_seed": town_seed, "pass": false, "state": "town_spell_failed"}
	var town_result: Dictionary = _resolve_like_live_validation(session)
	var final_state := String(town_result.get("state", ""))
	var final_survivors: Dictionary = _stack_counts(session.overworld.get("army", {}))
	var identity_exact := _tail_identity(session) == identity_before
	var enemy_entries_exact := route_enemy_entry == EXPECTED_ENEMY_ENTRIES[3] and town_enemy_entry == EXPECTED_ENEMY_ENTRIES[4]
	return {
		"session_id": session_id,
		"combat_seed": combat_seed,
		"town_seed": town_seed,
		"interrupt_state": interrupt_state,
		"interrupt_spell_target": interrupt_spell_target,
		"interrupt_actions": interrupt_result.get("actions", []),
		"post_interrupt_guards": post_interrupt_guards,
		"post_interrupt_army": interrupt_survivors,
		"final_state": final_state,
		"final_guards": int(final_survivors.get("unit_river_guard", 0)),
		"final_army": final_survivors,
		"enemy_entries_exact": enemy_entries_exact,
		"session_identity_exact": identity_exact,
		"pass": interrupt_state == "victory" and final_state == "victory" and enemy_entries_exact and identity_exact,
	}

func _run_selected_seed_matrix(prefix_payload: Dictionary) -> Dictionary:
	var session_ids: Array = OBSERVED_SESSION_IDS.duplicate()
	for index in range(SESSION_SAMPLE_COUNT):
		var candidate_id := str((index * 104729 + 7919) % 10000000)
		if not session_ids.has(candidate_id):
			session_ids.append(candidate_id)
	var failures: Array = []
	var failure_count := 0
	var observed := {}
	var minimum_post_interrupt_guards := 9999
	var minimum_final_guards := 9999
	var worst := {}
	var session_identity_exact := true
	for session_id_value in session_ids:
		var row: Dictionary = _run_session_tail(prefix_payload, String(session_id_value))
		var post_interrupt_guards := int(row.get("post_interrupt_guards", 0))
		var final_guards := int(row.get("final_guards", 0))
		if post_interrupt_guards < minimum_post_interrupt_guards or (post_interrupt_guards == minimum_post_interrupt_guards and final_guards < minimum_final_guards):
			minimum_post_interrupt_guards = post_interrupt_guards
			minimum_final_guards = final_guards
			worst = row.duplicate(true)
		if String(session_id_value) in OBSERVED_SESSION_IDS:
			observed[String(session_id_value)] = row.duplicate(true)
		if not bool(row.get("pass", false)):
			failure_count += 1
			if failures.size() < 8:
				failures.append(row.duplicate(true))
		session_identity_exact = session_identity_exact and bool(row.get("session_identity_exact", false))
	return {
		"evaluated_count": session_ids.size(),
		"failure_count": failure_count,
		"failures": failures,
		"minimum_post_interrupt_guards": minimum_post_interrupt_guards,
		"minimum_final_guards": minimum_final_guards,
		"worst": worst,
		"observed": observed,
		"session_identity_exact": session_identity_exact,
	}

func _tail_identity(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return {
		"scenario_id": session.scenario_id,
		"launch_mode": session.launch_mode,
		"difficulty": session.difficulty,
		"session_id": session.session_id,
	}

func _expected_selected_prefix_hero_states() -> Array:
	return [
		{"level": 3, "experience": 1020, "next_level_experience": 1250, "command": {"attack": 2, "defense": 3, "power": 0, "knowledge": 1}, "pending": [], "mana": 9},
		{"level": 4, "experience": 1420, "next_level_experience": 1900, "command": {"attack": 3, "defense": 3, "power": 0, "knowledge": 1}, "pending": [{"level": 4, "options": ["borderwarden", "ledgerkeeper", "mustercaptain"]}], "mana": 6},
		{"level": 4, "experience": 1420, "next_level_experience": 1900, "command": {"attack": 3, "defense": 3, "power": 0, "knowledge": 1}, "pending": [{"level": 4, "options": ["borderwarden", "ledgerkeeper", "mustercaptain"]}], "mana": 9},
	]

func _set_prepared_army(session: SessionStateStoreScript.SessionData, guard_count: int, army_id: String) -> void:
	var army := {
		"id": army_id,
		"name": "Ashgrove Watch" if army_id == SHARED_ARMY_ID else "Nightglass Redoubt Watch",
		"faction_id": "faction_embercourt",
		"stacks": [
			{"unit_id": "unit_river_guard", "count": guard_count},
			{"unit_id": "unit_ember_archer", "count": int(PREPARED_OTHER_COUNTS["unit_ember_archer"])},
			{"unit_id": "unit_citadel_pikeward", "count": int(PREPARED_OTHER_COUNTS["unit_citadel_pikeward"])},
			{"unit_id": "unit_bog_brute", "count": int(PREPARED_OTHER_COUNTS["unit_bog_brute"])},
			{"unit_id": "unit_blackbranch_cutthroat", "count": int(PREPARED_OTHER_COUNTS["unit_blackbranch_cutthroat"])},
			{"unit_id": "unit_mire_slinger", "count": int(PREPARED_OTHER_COUNTS["unit_mire_slinger"])},
		],
	}
	_set_army_everywhere(session, army)

func _set_army_everywhere(session: SessionStateStoreScript.SessionData, army: Dictionary) -> void:
	session.overworld["army"] = army.duplicate(true)
	var hero: Dictionary = session.overworld.get("hero", {})
	hero["army"] = army.duplicate(true)
	session.overworld["hero"] = hero
	var heroes: Array = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		var candidate: Dictionary = heroes[index]
		if String(candidate.get("id", "")) == session.hero_id:
			candidate["army"] = army.duplicate(true)
			heroes[index] = candidate
	session.overworld["player_heroes"] = heroes

func _set_live_commander(session: SessionStateStoreScript.SessionData) -> void:
	var hero: Dictionary = session.overworld.get("hero", {})
	hero["level"] = 3
	hero["experience"] = 770
	hero["next_level_experience"] = 1250
	hero["specialties"] = ["borderwarden", "armsmaster", "armsmaster"]
	hero["specialty_focus_ids"] = ["borderwarden", "ledgerkeeper", "armsmaster"]
	hero["pending_specialty_choices"] = []
	hero["command"] = {"attack": 2, "defense": 3, "power": 0, "knowledge": 1}
	hero["spellbook"] = {"known_spell_ids": ["spell_trailglyph", "spell_stone_veil", "spell_lantern_phalanx"], "mana": {"current": 12, "max": 12}}
	hero["artifacts"] = {"equipped": {"armor": "artifact_bastion_gorget", "banner": "", "boots": "", "trinket": "", "trinket_2": ""}, "inventory": []}
	session.overworld["hero"] = hero
	var heroes: Array = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		var candidate: Dictionary = heroes[index]
		if String(candidate.get("id", "")) == session.hero_id:
			for key in ["level", "experience", "next_level_experience", "specialties", "specialty_focus_ids", "pending_specialty_choices", "command", "spellbook", "artifacts"]:
				candidate[key] = hero[key].duplicate(true) if hero[key] is Array or hero[key] is Dictionary else hero[key]
			heroes[index] = candidate
	session.overworld["player_heroes"] = heroes

func _restore_mana(session: SessionStateStoreScript.SessionData) -> void:
	var hero: Dictionary = session.overworld.get("hero", {})
	var spellbook: Dictionary = hero.get("spellbook", {})
	spellbook["mana"] = {"current": 12, "max": 12}
	hero["spellbook"] = spellbook
	session.overworld["hero"] = hero
	var heroes: Array = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		var candidate: Dictionary = heroes[index]
		if String(candidate.get("id", "")) == session.hero_id:
			candidate["spellbook"] = spellbook.duplicate(true)
			heroes[index] = candidate
	session.overworld["player_heroes"] = heroes

func _set_nightglass_garrison(session: SessionStateStoreScript.SessionData) -> void:
	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		var town: Dictionary = towns[index]
		if String(town.get("placement_id", "")) == "nightglass_redoubt":
			town["garrison"] = [
				{"unit_id": "unit_bog_brute", "count": 10},
				{"unit_id": "unit_blackbranch_cutthroat", "count": 11},
				{"unit_id": "unit_gorefen_ripper", "count": 1},
			]
			towns[index] = town
	session.overworld["towns"] = towns

func _resolve_like_live_validation(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var last_state := "continue"
	var actions: Array = []
	for step in range(1, 257):
		if session.battle.is_empty():
			return {"state": last_state, "steps": step - 1, "actions": actions}
		var active_stack: Dictionary = BattleRulesScript.get_active_stack(session.battle)
		if active_stack.is_empty() or String(active_stack.get("side", "")) != "player":
			var ready_result: Dictionary = BattleRulesScript.resolve_if_battle_ready(session)
			last_state = String(ready_result.get("state", "continue"))
			if last_state in ["victory", "defeat", "retreat", "surrender", "stalemate", "hero_defeat", "town_lost"]:
				return {"state": last_state, "steps": step, "actions": actions}
			continue
		_align_target(session)
		var action_id := _preferred_action(session)
		if action_id == "":
			return {"state": "invalid", "steps": step, "actions": actions}
		var selected_target_id := String(BattleRulesScript.get_selected_target(session.battle).get("battle_id", ""))
		var action_result: Dictionary = BattleRulesScript.perform_player_action(session, action_id)
		last_state = String(action_result.get("state", "continue"))
		actions.append({"action": action_id, "target_battle_id": selected_target_id, "state": last_state})
		if last_state in ["victory", "defeat", "retreat", "surrender", "stalemate", "hero_defeat", "town_lost"]:
			return {"state": last_state, "steps": step, "actions": actions}
	return {"state": "stalled", "steps": 256, "actions": actions}

func _advance_to_player(session: SessionStateStoreScript.SessionData) -> void:
	for _step in range(64):
		var active_stack: Dictionary = BattleRulesScript.get_active_stack(session.battle)
		if not active_stack.is_empty() and String(active_stack.get("side", "")) == "player":
			return
		var result: Dictionary = BattleRulesScript.resolve_if_battle_ready(session)
		if String(result.get("state", "continue")) != "continue":
			return

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
		var action: Dictionary = surface.get(action_id, {})
		if not bool(action.get("disabled", true)):
			return action_id
	return ""

func _encounter(placement_id: String) -> Dictionary:
	for value in ContentService.get_scenario(SCENARIO_ID).get("encounters", []):
		if value is Dictionary and String(value.get("placement_id", "")) == placement_id:
			return value.duplicate(true)
	return {}

func _route_interrupt_encounter(combat_seed: int) -> Dictionary:
	return {
		"placement_id": "faction_mireclaw_raid_1",
		"encounter_id": "encounter_bone_ferry_watch",
		"x": 9,
		"y": 4,
		"difficulty": "pressure",
		"combat_seed": combat_seed,
		"arrived": false,
		"days_active": 1,
		"goal_distance": 2,
		"goal_x": 7,
		"goal_y": 5,
		"spawn_origin_x": 9,
		"spawn_origin_y": 5,
		"spawned_by_faction_id": "faction_mireclaw",
		"target_kind": "resource",
		"target_placement_id": "causeway_ore",
		"target_label": "Ore Crates",
		"target_x": 7,
		"target_y": 5,
		"target_reason_codes": ["resource_scarcity", "enemy_scouting", "commander_memory"],
		"target_public_reason": "seeking scarce resources",
		"target_public_importance": "high",
		"target_debug_reason": "live commander target selection adopted contest_site",
		"post_objective_continuation": true,
		"post_objective_continuation_day": 2,
		"previous_completed_target_kind": "artifact",
		"previous_completed_target_placement_id": "nightglass_gorget",
		"priority": 292,
		"enemy_army": {
			"id": "army_ripper_vanguard",
			"name": "Ripper Vanguard",
			"stacks": [
				{"unit_id": "unit_gorefen_ripper", "count": 3},
				{"unit_id": "unit_blackbranch_cutthroat", "count": 6},
				{"unit_id": "unit_mire_slinger", "count": 4},
			],
		},
		"enemy_commander_state": {
			"id": "enemy_commander:faction_mireclaw:hero_sable",
			"roster_hero_id": "hero_sable",
			"name": "Sable Muckscribe",
			"faction_id": "faction_mireclaw",
			"archetype": "hexcaller",
			"level": 1,
			"experience": 190,
			"next_level_experience": 250,
			"specialties": ["spellwright"],
			"specialty_focus_ids": ["spellwright", "ledgerkeeper", "borderwarden"],
			"pending_specialty_choices": [],
			"command": {"attack": 0, "defense": 0, "power": 2, "knowledge": 2},
			"command_path": "magic",
			"spellbook": {"known_spell_ids": ["spell_stone_veil", "spell_coal_rain", "spell_relay_drum", "spell_root_green_rootway_12"], "mana": {"current": 20, "max": 20}},
			"artifacts": {"equipped": {"armor": "artifact_bastion_gorget", "banner": "", "boots": "", "trinket": "", "trinket_2": ""}, "inventory": []},
			"battle_traits": ["bogwise", "linekeeper"],
			"deployments": 1,
			"battle_wins": 0,
			"times_defeated": 0,
			"strategic_successes": 1,
			"renown": 1,
			"veterancy_rank": 0,
			"veterancy_label": "",
			"last_outcome": "artifact_secured",
			"target_memory": {
				"focus_pressure_count": 1,
				"focus_target_id": "causeway_ore",
				"focus_target_kind": "resource",
				"focus_target_label": "Ore Crates",
				"front_label": "Ore Crates",
				"front_x": 7,
				"front_y": 5,
				"last_failure_outcome": "",
				"last_failure_target_kind": "",
				"last_success_outcome": "artifact_secured",
				"last_success_target_kind": "artifact",
				"last_target_id": "causeway_ore",
				"last_target_kind": "resource",
				"last_target_label": "Ore Crates",
				"rival_id": "",
				"rival_kind": "",
				"rival_label": "",
				"rivalry_count": 0,
				"target_failure_counts": {},
				"target_success_counts": {"artifact": 1},
			},
		},
	}

func _install_route_interrupt(session: SessionStateStoreScript.SessionData, route_interrupt: Dictionary) -> void:
	var encounters: Array = session.overworld.get("encounters", [])
	var filtered: Array = []
	for value in encounters:
		if value is Dictionary and String(value.get("placement_id", "")) == "faction_mireclaw_raid_1":
			continue
		filtered.append(value)
	filtered.append(route_interrupt.duplicate(true))
	session.overworld["encounters"] = filtered

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

func _hero_state(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var hero: Dictionary = session.overworld.get("hero", {})
	var mana: Dictionary = hero.get("spellbook", {}).get("mana", {})
	return {
		"level": int(hero.get("level", 0)),
		"experience": int(hero.get("experience", 0)),
		"next_level_experience": int(hero.get("next_level_experience", 0)),
		"command": hero.get("command", {}).duplicate(true),
		"pending": hero.get("pending_specialty_choices", []).duplicate(true),
		"mana": int(mana.get("current", 0)),
	}

func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error(message)
	get_tree().quit(1)
