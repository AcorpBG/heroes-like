extends Node

const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const CampaignRulesScript = preload("res://scripts/core/CampaignRules.gd")
const OverworldRulesScript = preload("res://scripts/core/OverworldRules.gd")
const ScenarioScriptRulesScript = preload("res://scripts/core/ScenarioScriptRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const TownRulesScript = preload("res://scripts/core/TownRules.gd")

const REPORT_ID := "BOGBOUND_OATH_CHAPTER_ONE_SEQUENTIAL_VIABILITY_REPORT"
const CAMPAIGN_ID := "campaign_bogbound_oath"
const SCENARIO_ID := "bogbound-oath"
const ARMY_ID := "army_reedmaw_host"
const REINFORCEMENT_HOOK_ID := "reed_watchers_return"
const SELECTED_REINFORCEMENT_CUTTHROATS := 40
const SAVE_SLOT := 3
const CHARTER_SCENARIO_ID := "charter-pyre"
const RIVERWATCH_GORGET_ID := "artifact_bastion_gorget"
const CHARTER_REINFORCEMENT_HOOK_ID := "reed_watcher_slingers_cross_the_bridge"
const CHARTER_REINFORCEMENT_SLINGERS := 15
const CHARTER_SAVE_SLOT := 2
const LOCKMARSH_SCENARIO_ID := "lockmarsh-surge"
const LOCKMARSH_REINFORCEMENT_HOOK_ID := "reed_watchers_cross_the_firebreak"
const LOCKMARSH_REINFORCEMENT_CUTTHROATS := 31
const LOCKMARSH_SAVE_SLOT := 1
const LOCKMARSH_FINALE_REINFORCEMENT_HOOK_ID := "reed_watchers_break_the_archive_seal"
const LOCKMARSH_FINALE_REINFORCEMENT_CUTTHROATS := 11
const LOCKMARSH_FINALE_SAVE_SLOT := 4
const REQUIRED_ENCOUNTERS := ["bogbound_lantern_patrol", "bogbound_survey_guard", "bogbound_archive_wardens"]
const CHARTER_REQUIRED_ENCOUNTERS := ["charter_bridgeward_levies", "charter_beacon_wardens", "charter_granary_levies"]
const LOCKMARSH_REQUIRED_ENCOUNTERS := ["surge_road_chaplains", "surge_charter_guard", "lockmarsh_archive_wardens"]
const PREPARED_COUNTS := {
	"unit_blackbranch_cutthroat": 14,
	"unit_bog_brute": 6,
	"unit_mire_slinger": 6,
	"unit_gorefen_ripper": 2,
}
const ENEMY_ENTRIES := [
	{"unit_ember_archer": 8, "unit_river_guard": 5, "unit_citadel_pikeward": 1},
	{"unit_river_guard": 6, "unit_citadel_pikeward": 4, "unit_ember_archer": 4},
	{"unit_river_guard": 8, "unit_ember_archer": 12, "unit_citadel_pikeward": 6},
]
const CONTROL_SURVIVORS := [
	{"unit_blackbranch_cutthroat": 14, "unit_bog_brute": 4},
	{},
]
const SELECTED_SURVIVORS := [
	{"unit_blackbranch_cutthroat": 54, "unit_bog_brute": 4},
	{"unit_blackbranch_cutthroat": 46},
	{"unit_blackbranch_cutthroat": 19},
	{"unit_blackbranch_cutthroat": 19},
]
const CHARTER_PRE_BRIDGE_COUNTS := {
	"unit_blackbranch_cutthroat": 7,
	"unit_bog_brute": 6,
	"unit_mire_slinger": 5,
	"unit_gorefen_ripper": 2,
	"unit_river_guard": 8,
	"unit_ember_archer": 4,
}
const CHARTER_ENEMY_ENTRIES := [
	{"unit_river_guard": 6, "unit_citadel_pikeward": 4, "unit_ember_archer": 4},
	{"unit_ember_archer": 8, "unit_river_guard": 5, "unit_citadel_pikeward": 1},
	{"unit_river_guard": 11, "unit_ember_archer": 8, "unit_citadel_pikeward": 2},
]
const CHARTER_CONTROL_SURVIVORS := [
	{"unit_blackbranch_cutthroat": 7, "unit_bog_brute": 6, "unit_mire_slinger": 4, "unit_river_guard": 8},
	{"unit_bog_brute": 5},
	{},
]
const CHARTER_SELECTED_SURVIVORS := [
	{"unit_blackbranch_cutthroat": 7, "unit_bog_brute": 6, "unit_mire_slinger": 19, "unit_river_guard": 8},
	{"unit_blackbranch_cutthroat": 7, "unit_bog_brute": 6, "unit_mire_slinger": 17, "unit_river_guard": 8},
	{"unit_blackbranch_cutthroat": 4, "unit_bog_brute": 6, "unit_mire_slinger": 9, "unit_river_guard": 8},
]
const LOCKMARSH_PRE_ROAD_COUNTS := {
	"unit_blackbranch_cutthroat": 9,
	"unit_bog_brute": 7,
	"unit_mire_slinger": 5,
	"unit_gorefen_ripper": 2,
	"unit_river_guard": 8,
	"unit_ember_archer": 5,
}
const LOCKMARSH_ENEMY_ENTRIES := [
	{"unit_river_guard": 9, "unit_ember_archer": 10, "unit_citadel_pikeward": 6},
	{"unit_river_guard": 7, "unit_ember_archer": 6, "unit_citadel_pikeward": 2},
	{"unit_river_guard": 7, "unit_ember_archer": 9, "unit_citadel_pikeward": 2},
]
const LOCKMARSH_CONTROL_SURVIVORS := [
	{"unit_bog_brute": 4},
	{},
]
const LOCKMARSH_SELECTED_SURVIVORS := [
	{"unit_blackbranch_cutthroat": 31, "unit_bog_brute": 4},
	{"unit_blackbranch_cutthroat": 26, "unit_bog_brute": 3},
	{"unit_blackbranch_cutthroat": 33},
]
const LOCKMARSH_LIVE_POST_ARCHIVE_COUNTS := {
	"unit_blackbranch_cutthroat": 15,
	"unit_bog_brute": 1,
}
const LOCKMARSH_LIVE_FINALE_STACK_ORDER := ["unit_bog_brute", "unit_blackbranch_cutthroat"]
const LOCKMARSH_LIVE_FINALE_ENEMY_ENTRY := {
	"unit_river_guard": 16,
	"unit_ember_archer": 2,
	"unit_citadel_pikeward": 1,
}
const LOCKMARSH_LIVE_FINALE_PREDECESSOR_COUNTS := {
	"unit_blackbranch_cutthroat": 25,
	"unit_bog_brute": 1,
}
const LOCKMARSH_LIVE_FINALE_SELECTED_COUNTS := {
	"unit_blackbranch_cutthroat": 26,
	"unit_bog_brute": 1,
}
const LOCKMARSH_LIVE_FINALE_COMBAT_SEED := 50133025
const LOCKMARSH_LIVE_FINALE_DAMAGE_RNG_STATE := "770320593367029343"

var _failed := false
var _campaign_profile_after_chapter_one: Dictionary = {}
var _campaign_profile_after_chapter_two: Dictionary = {}

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
	var charter_control: Dictionary = _run_charter_followthrough(false)
	if _failed:
		return
	var charter_selected: Dictionary = _run_charter_followthrough(true)
	if _failed:
		return
	var lockmarsh_control: Dictionary = _run_lockmarsh_followthrough(false)
	if _failed:
		return
	var lockmarsh_selected: Dictionary = _run_lockmarsh_followthrough(true)
	if _failed:
		return
	var lockmarsh_finale_control: Dictionary = _run_lockmarsh_finale_candidate(0, false)
	if _failed:
		return
	var lockmarsh_finale_predecessor: Dictionary = _run_lockmarsh_finale_candidate(LOCKMARSH_FINALE_REINFORCEMENT_CUTTHROATS - 1, false)
	if _failed:
		return
	var lockmarsh_finale_selected: Dictionary = _run_lockmarsh_finale_candidate(0, true)
	if _failed:
		return
	if control.get("states", []) != ["victory", "defeat"] or control.get("survivors", []) != CONTROL_SURVIVORS:
		_fail("Old-content control did not reproduce the exact sequential Survey Guard defeat: %s" % JSON.stringify(control))
		return
	if selected.get("states", []) != ["victory", "victory", "victory", "victory"] or selected.get("survivors", []) != SELECTED_SURVIVORS:
		_fail("Staged Reed-Watcher sequence did not complete the exact three encounters and Riverwatch assault: %s" % JSON.stringify(selected))
		return
	if selected.get("enemy_entries", []) != ENEMY_ENTRIES or selected.get("town_enemy_entry", {}) != {"unit_river_guard": 4}:
		_fail("Staged sequence changed an authored enemy force: %s" % JSON.stringify(selected))
		return
	if selected.get("reinforcement_fired_ids", []).count(REINFORCEMENT_HOOK_ID) != 1:
		_fail("Reed-Watcher reinforcement did not fire exactly once: %s" % JSON.stringify(selected))
		return
	if not bool(selected.get("army_mirrors_exact", false)) or not bool(selected.get("save_resume_exact", false)) or not bool(selected.get("one_shot_exact", false)):
		_fail("Reed-Watcher reinforcement lost army mirrors, save authority, or one-shot ownership: %s" % JSON.stringify(selected))
		return
	if charter_control.get("states", []) != ["victory", "victory", "defeat"] or charter_control.get("survivors", []) != CHARTER_CONTROL_SURVIVORS:
		_fail("Old-content Charter control did not reproduce the exact post-Bridgeward Granary defeat: %s" % JSON.stringify(charter_control))
		return
	if charter_selected.get("states", []) != ["victory", "victory", "victory"] or charter_selected.get("survivors", []) != CHARTER_SELECTED_SURVIVORS:
		_fail("Reed-Watcher sling followthrough did not preserve Bridgeward, Beacon, and Granary victories: %s" % JSON.stringify(charter_selected))
		return
	if charter_selected.get("enemy_entries", []) != CHARTER_ENEMY_ENTRIES:
		_fail("Charter followthrough changed an authored enemy force: %s" % JSON.stringify(charter_selected))
		return
	if charter_selected.get("reinforcement_fired_ids", []).count(CHARTER_REINFORCEMENT_HOOK_ID) != 1:
		_fail("Charter Reed-Watcher sling reinforcement did not fire exactly once: %s" % JSON.stringify(charter_selected))
		return
	if not bool(charter_selected.get("army_mirrors_exact", false)) or not bool(charter_selected.get("save_resume_exact", false)) or not bool(charter_selected.get("one_shot_exact", false)):
		_fail("Charter Reed-Watcher followthrough lost army mirrors, save authority, or one-shot ownership: %s" % JSON.stringify(charter_selected))
		return
	if not bool(charter_control.get("campaign_entry_exact", false)) or not bool(charter_selected.get("campaign_entry_exact", false)) or charter_control.get("campaign_entry", {}) != charter_selected.get("campaign_entry", {}):
		_fail("Charter followthrough did not use one exact production campaign carryover entry: %s" % JSON.stringify({"control": charter_control, "selected": charter_selected}))
		return
	if String(charter_selected.get("town_state", "")) != "victory" or _campaign_profile_after_chapter_two.is_empty():
		_fail("Charter followthrough did not complete Highwater and bank the production Chapter 3 carryover: %s" % JSON.stringify(charter_selected))
		return
	if lockmarsh_control.get("states", []) != ["victory", "defeat"] or lockmarsh_control.get("survivors", []) != LOCKMARSH_CONTROL_SURVIVORS:
		_fail("Old-content Lockmarsh control did not reproduce the exact post-Road Charter defeat: %s" % JSON.stringify(lockmarsh_control))
		return
	if lockmarsh_selected.get("states", []) != ["victory", "victory", "victory"] or lockmarsh_selected.get("survivors", []) != LOCKMARSH_SELECTED_SURVIVORS:
		_fail("Final Reed-Watcher firebreak stage did not preserve exact Road, Charter, and Archive victories: %s" % JSON.stringify(lockmarsh_selected))
		return
	if lockmarsh_selected.get("enemy_entries", []) != LOCKMARSH_ENEMY_ENTRIES:
		_fail("Lockmarsh followthrough changed an authored enemy force: %s" % JSON.stringify(lockmarsh_selected))
		return
	if lockmarsh_selected.get("reinforcement_fired_ids", []).count(LOCKMARSH_REINFORCEMENT_HOOK_ID) != 1:
		_fail("Lockmarsh Reed-Watcher reinforcement did not fire exactly once: %s" % JSON.stringify(lockmarsh_selected))
		return
	if not bool(lockmarsh_selected.get("army_mirrors_exact", false)) or not bool(lockmarsh_selected.get("save_resume_exact", false)) or not bool(lockmarsh_selected.get("one_shot_exact", false)):
		_fail("Lockmarsh Reed-Watcher followthrough lost army mirrors, save authority, or one-shot ownership: %s" % JSON.stringify(lockmarsh_selected))
		return
	if not bool(lockmarsh_control.get("campaign_entry_exact", false)) or not bool(lockmarsh_selected.get("campaign_entry_exact", false)) or lockmarsh_control.get("campaign_entry", {}) != lockmarsh_selected.get("campaign_entry", {}):
		_fail("Lockmarsh followthrough did not use one exact production Chapter 3 campaign entry: %s" % JSON.stringify({"control": lockmarsh_control, "selected": lockmarsh_selected}))
		return
	if String(lockmarsh_finale_control.get("state", "")) != "defeat" or lockmarsh_finale_control.get("pre_hook_counts", {}) != LOCKMARSH_LIVE_POST_ARCHIVE_COUNTS:
		_fail("Exact live post-Archive Highwater control did not reproduce the shipped defeat: %s" % JSON.stringify(lockmarsh_finale_control))
		return
	if String(lockmarsh_finale_predecessor.get("state", "")) != "defeat" or lockmarsh_finale_predecessor.get("pre_hook_counts", {}) != LOCKMARSH_LIVE_FINALE_PREDECESSOR_COUNTS:
		_fail("Ten additional Cutthroats did not remain the exact losing predecessor at Highwater: %s" % JSON.stringify(lockmarsh_finale_predecessor))
		return
	if String(lockmarsh_finale_selected.get("state", "")) != "victory" or lockmarsh_finale_selected.get("pre_hook_counts", {}) != LOCKMARSH_LIVE_POST_ARCHIVE_COUNTS or lockmarsh_finale_selected.get("post_hook_counts", {}) != LOCKMARSH_LIVE_FINALE_SELECTED_COUNTS or lockmarsh_finale_selected.get("survivors", {}) != {"unit_blackbranch_cutthroat": 5}:
		_fail("Exact eleven-Cutthroat post-Archive stage did not win the unchanged live Highwater assault with exact survivors: %s" % JSON.stringify(lockmarsh_finale_selected))
		return
	for finale_row in [lockmarsh_finale_control, lockmarsh_finale_predecessor, lockmarsh_finale_selected]:
		if finale_row.get("player_entry_order", []) != LOCKMARSH_LIVE_FINALE_STACK_ORDER or finale_row.get("enemy_entry", {}) != LOCKMARSH_LIVE_FINALE_ENEMY_ENTRY or not bool(finale_row.get("commander_exact", false)) or finale_row.get("enemy_battle_traits", []) != ["linekeeper"] or int(finale_row.get("combat_seed", 0)) != LOCKMARSH_LIVE_FINALE_COMBAT_SEED or String(finale_row.get("damage_rng_state", "")) != LOCKMARSH_LIVE_FINALE_DAMAGE_RNG_STATE:
			_fail("Lockmarsh finale screen drifted from the exact routed commander, briefing-normalized captain, RNG, or bolstered Highwater force: %s" % JSON.stringify(finale_row))
			return
	if not bool(lockmarsh_finale_predecessor.get("live_trace_prefix_exact", false)):
		_fail("Ten-Cutthroat predecessor did not reproduce the routed Highwater action prefix: %s" % JSON.stringify(lockmarsh_finale_predecessor))
		return
	if lockmarsh_finale_selected.get("fired_ids", []).count(LOCKMARSH_FINALE_REINFORCEMENT_HOOK_ID) != 1 or not bool(lockmarsh_finale_selected.get("army_mirrors_exact", false)) or not bool(lockmarsh_finale_selected.get("save_resume_exact", false)) or not bool(lockmarsh_finale_selected.get("one_shot_exact", false)):
		_fail("Post-Archive Reed-Watcher stage lost exact one-shot, mirror, or save ownership: %s" % JSON.stringify(lockmarsh_finale_selected))
		return
	if _assert_content_contract() != content_contract:
		_fail("Sequential controls mutated the authored Bogbound content contract.")
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"content": content_contract,
		"control": control,
		"selected": selected,
		"charter_control": charter_control,
		"charter_selected": charter_selected,
		"lockmarsh_control": lockmarsh_control,
		"lockmarsh_selected": lockmarsh_selected,
		"lockmarsh_finale_control": lockmarsh_finale_control,
		"lockmarsh_finale_predecessor": lockmarsh_finale_predecessor,
		"lockmarsh_finale_selected": lockmarsh_finale_selected,
	})])
	get_tree().quit(0)

func _assert_content_contract() -> Dictionary:
	var scenario: Dictionary = ContentService.get_scenario(SCENARIO_ID)
	var army_counts: Dictionary = _stack_counts(ContentService.get_army_group(ARMY_ID))
	if String(scenario.get("player_army_id", "")) != ARMY_ID or army_counts != {"unit_blackbranch_cutthroat": 7, "unit_bog_brute": 6, "unit_mire_slinger": 5, "unit_gorefen_ripper": 2}:
		_fail("Bogbound base opening army drifted: %s" % JSON.stringify(army_counts))
		return {}
	var hook: Dictionary = _script_hook(scenario, REINFORCEMENT_HOOK_ID)
	var expected_hook := {
		"id": REINFORCEMENT_HOOK_ID,
		"priority": 120.0,
		"conditions": [{"type": "objective_met", "objective_id": "clear_lantern_patrol"}],
		"effects": [
			{"type": "add_army_units", "units": {"unit_blackbranch_cutthroat": float(SELECTED_REINFORCEMENT_CUTTHROATS)}},
			{"type": "spawn_resource_node", "placement": {"placement_id": "reed_watchers_cache", "site_id": "site_waystone_cache", "x": 4.0, "y": 0.0}},
			{"type": "message", "text": "When the Lantern Patrol breaks, Reed-Watcher cutters rally behind Vaska while mire scouts drag a seized waystone cache back onto the road."},
		],
	}
	if hook != expected_hook:
		_fail("Bogbound Reed-Watcher reinforcement hook drifted: %s" % JSON.stringify(hook))
		return {}
	var enemy_entries := []
	for placement_id in REQUIRED_ENCOUNTERS:
		enemy_entries.append(_encounter_entry_counts(_encounter(placement_id)))
	if enemy_entries != ENEMY_ENTRIES:
		_fail("Bogbound required enemy forces drifted: %s" % JSON.stringify(enemy_entries))
		return {}
	var riverwatch: Dictionary = ContentService.get_town("town_riverwatch")
	if _stack_counts({"stacks": riverwatch.get("garrison", [])}) != {"unit_river_guard": 4}:
		_fail("Riverwatch garrison drifted.")
		return {}
	var charter_scenario: Dictionary = ContentService.get_scenario(CHARTER_SCENARIO_ID)
	var charter_hook: Dictionary = _script_hook_for_scenario(charter_scenario, CHARTER_REINFORCEMENT_HOOK_ID)
	var expected_charter_hook := {
		"id": CHARTER_REINFORCEMENT_HOOK_ID,
		"priority": 105.0,
		"conditions": [
			{"type": "flag_true", "flag": "carryover_lantern_patrol_broken"},
			{"type": "encounter_resolved", "placement_id": "charter_bridgeward_levies"},
		],
		"effects": [
			{"type": "add_army_units", "units": {"unit_mire_slinger": float(CHARTER_REINFORCEMENT_SLINGERS)}},
			{"type": "message", "text": "Once the bridgeward column breaks, fifteen Reed-Watcher sling crews cross from Riverwatch and rejoin Vaska for the granary push."},
		],
	}
	if charter_hook != expected_charter_hook:
		_fail("Charter Reed-Watcher sling hook drifted: %s" % JSON.stringify(charter_hook))
		return {}
	var charter_enemy_entries := []
	for placement_id in CHARTER_REQUIRED_ENCOUNTERS:
		charter_enemy_entries.append(_encounter_entry_counts(_encounter_for_scenario(charter_scenario, placement_id)))
	if charter_enemy_entries != CHARTER_ENEMY_ENTRIES:
		_fail("Charter followthrough enemy forces drifted: %s" % JSON.stringify(charter_enemy_entries))
		return {}
	var lockmarsh_scenario: Dictionary = ContentService.get_scenario(LOCKMARSH_SCENARIO_ID)
	var lockmarsh_hook: Dictionary = _script_hook_for_scenario(lockmarsh_scenario, LOCKMARSH_REINFORCEMENT_HOOK_ID)
	var expected_lockmarsh_hook := {
		"id": LOCKMARSH_REINFORCEMENT_HOOK_ID,
		"priority": 99.0,
		"conditions": [{"type": "objective_met", "objective_id": "break_road_chaplains"}],
		"effects": [
			{"type": "add_army_units", "units": {"unit_blackbranch_cutthroat": float(LOCKMARSH_REINFORCEMENT_CUTTHROATS)}},
			{"type": "message", "text": "With the road chaplains broken, the final thirty-one Reed-Watcher cutters cross the firebreak and reform around Vaska for the Highwater assault."},
		],
	}
	if lockmarsh_hook != expected_lockmarsh_hook:
		_fail("Lockmarsh Reed-Watcher firebreak hook drifted: %s" % JSON.stringify(lockmarsh_hook))
		return {}
	var lockmarsh_finale_hook: Dictionary = _script_hook_for_scenario(lockmarsh_scenario, LOCKMARSH_FINALE_REINFORCEMENT_HOOK_ID)
	var expected_lockmarsh_finale_hook := {
		"id": LOCKMARSH_FINALE_REINFORCEMENT_HOOK_ID,
		"priority": 94.0,
		"conditions": [{"type": "objective_met", "objective_id": "break_archive_wardens"}],
		"effects": [
			{"type": "add_army_units", "units": {"unit_blackbranch_cutthroat": float(LOCKMARSH_FINALE_REINFORCEMENT_CUTTHROATS)}},
			{"type": "message", "text": "With the archive wardens broken, eleven Reed-Watcher cutters emerge from the flooded ledger vaults and join Vaska for the final assault on Highwater."},
		],
	}
	if lockmarsh_finale_hook != expected_lockmarsh_finale_hook:
		_fail("Lockmarsh post-Archive Reed-Watcher hook drifted: %s" % JSON.stringify(lockmarsh_finale_hook))
		return {}
	var lockmarsh_enemy_entries := []
	for placement_id in LOCKMARSH_REQUIRED_ENCOUNTERS:
		lockmarsh_enemy_entries.append(_encounter_entry_counts(_encounter_for_scenario(lockmarsh_scenario, placement_id)))
	if lockmarsh_enemy_entries != LOCKMARSH_ENEMY_ENTRIES:
		_fail("Lockmarsh followthrough enemy forces drifted: %s" % JSON.stringify(lockmarsh_enemy_entries))
		return {}
	var highwater_counts: Dictionary = _stack_counts({"stacks": ContentService.get_town("town_highwater_keep").get("garrison", [])})
	if highwater_counts != {"unit_river_guard": 5, "unit_ember_archer": 2, "unit_citadel_pikeward": 1}:
		_fail("Authored Highwater garrison drifted: %s" % JSON.stringify(highwater_counts))
		return {}
	return {
		"army_id": ARMY_ID,
		"army_counts": army_counts,
		"hook": hook,
		"enemy_entries": enemy_entries,
		"riverwatch_garrison": {"unit_river_guard": 4},
		"charter_hook": charter_hook,
		"charter_enemy_entries": charter_enemy_entries,
		"lockmarsh_hook": lockmarsh_hook,
		"lockmarsh_finale_hook": lockmarsh_finale_hook,
		"lockmarsh_enemy_entries": lockmarsh_enemy_entries,
		"highwater_garrison": highwater_counts,
	}

func _run_sequence(use_authored_reinforcement: bool) -> Dictionary:
	var session: SessionStateStoreScript.SessionData = CampaignRulesScript.build_session(
		{},
		SCENARIO_ID,
		"normal",
		CAMPAIGN_ID
	)
	if not use_authored_reinforcement:
		_suppress_reinforcement_hook(session)
	_set_live_army(session, PREPARED_COUNTS)
	var session_identity_before := {"scenario_id": session.scenario_id, "launch_mode": session.launch_mode, "difficulty": session.difficulty}
	var states := []
	var survivors := []
	var enemy_entries := []
	var save_resume_exact := not use_authored_reinforcement
	var one_shot_exact := not use_authored_reinforcement
	for placement_id in REQUIRED_ENCOUNTERS:
		var encounter: Dictionary = _encounter(placement_id)
		session.battle = BattleRulesScript.create_battle_payload(session, encounter)
		enemy_entries.append(_battle_side_counts(session.battle, "enemy"))
		var high_difficulty := String(encounter.get("difficulty", "")) == "high"
		var result: Dictionary = _resolve_like_live_validation(session, high_difficulty, high_difficulty)
		var state := String(result.get("state", ""))
		states.append(state)
		survivors.append(_stack_counts(session.overworld.get("army", {})))
		if state != "victory":
			break
		if use_authored_reinforcement and placement_id == "bogbound_lantern_patrol":
			var saved: Dictionary = _save_restore_after_reinforcement(session)
			if not bool(saved.get("ok", false)):
				return {}
			session = saved.get("session", session)
			save_resume_exact = bool(saved.get("save_resume_exact", false))
			one_shot_exact = bool(saved.get("one_shot_exact", false))
	if states.size() == REQUIRED_ENCOUNTERS.size() and states[-1] == "victory":
		var gorget_claim: Dictionary = OverworldRulesScript.claim_artifact_for_session(
			session,
			RIVERWATCH_GORGET_ID,
			"Recovered at Riverwatch",
			true
		)
		if not bool(gorget_claim.get("ok", false)) or RIVERWATCH_GORGET_ID not in _owned_artifact_ids(session):
			_fail("Bogbound production carryover control could not claim the authored Riverwatch Gorget: %s" % JSON.stringify(gorget_claim))
			return {}
		session.battle = BattleRulesScript.create_town_assault_payload(session, "riverwatch_hold")
		var town_enemy_entry: Dictionary = _battle_side_counts(session.battle, "enemy")
		var town_result: Dictionary = _resolve_like_live_validation(session, true, false)
		var town_state := String(town_result.get("state", ""))
		states.append(town_state)
		survivors.append(_stack_counts(session.overworld.get("army", {})))
		if use_authored_reinforcement and town_state == "victory":
			_campaign_profile_after_chapter_one = CampaignRulesScript.record_session_completion({}, session)
		return _sequence_payload(session, session_identity_before, states, survivors, enemy_entries, town_enemy_entry, save_resume_exact, one_shot_exact)
	return _sequence_payload(session, session_identity_before, states, survivors, enemy_entries, {}, save_resume_exact, one_shot_exact)

func _run_charter_followthrough(use_authored_reinforcement: bool) -> Dictionary:
	if _campaign_profile_after_chapter_one.is_empty():
		_fail("Charter followthrough has no completed Bogbound campaign profile to import.")
		return {}
	var session: SessionStateStoreScript.SessionData = CampaignRulesScript.build_session(
		_campaign_profile_after_chapter_one,
		CHARTER_SCENARIO_ID,
		"normal",
		CAMPAIGN_ID
	)
	var campaign_entry: Dictionary = _charter_campaign_entry_signature(session)
	var campaign_entry_exact: bool = String(campaign_entry.get("scenario_id", "")) == CHARTER_SCENARIO_ID \
		and String(campaign_entry.get("launch_mode", "")) == SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN \
		and String(campaign_entry.get("campaign_id", "")) == CAMPAIGN_ID \
		and String(campaign_entry.get("previous_scenario_id", "")) == SCENARIO_ID \
		and bool(campaign_entry.get("carryover_lantern_patrol_broken", false)) \
		and RIVERWATCH_GORGET_ID in campaign_entry.get("artifact_ids", [])
	if not campaign_entry_exact:
		_fail("Charter followthrough did not import the exact Bogbound campaign carryover: %s" % JSON.stringify(campaign_entry))
		return {}
	var specialty_result: Dictionary = TownRulesScript.choose_specialty_at_active_town(session, "armsmaster")
	if not bool(specialty_result.get("ok", false)):
		_fail("Charter followthrough could not choose the exact live Armsmaster specialty before the road battles: %s" % JSON.stringify(specialty_result))
		return {}
	_set_live_army(session, CHARTER_PRE_BRIDGE_COUNTS)
	ScenarioScriptRulesScript.normalize_script_state(session)
	if not use_authored_reinforcement:
		var suppressed_state: Dictionary = session.overworld.get("scenario_script_state", {})
		suppressed_state["fired_hook_ids"] = [CHARTER_REINFORCEMENT_HOOK_ID]
		session.overworld["scenario_script_state"] = suppressed_state
	var post_hook_counts := {}
	var post_hook_mirrors_exact := false
	var save_resume_exact := not use_authored_reinforcement
	var one_shot_exact := not use_authored_reinforcement
	var states := []
	var survivors := []
	var enemy_entries := []
	var town_state := ""
	var town_survivors := {}
	var town_enemy_entry := {}
	for placement_id in CHARTER_REQUIRED_ENCOUNTERS:
		var encounter: Dictionary = _encounter_for_scenario(ContentService.get_scenario(CHARTER_SCENARIO_ID), placement_id)
		session.battle = BattleRulesScript.create_battle_payload(session, encounter)
		enemy_entries.append(_battle_side_counts(session.battle, "enemy"))
		var high_difficulty := String(encounter.get("difficulty", "")) == "high"
		var result: Dictionary = _resolve_like_live_validation(session, high_difficulty, high_difficulty)
		var state := String(result.get("state", ""))
		states.append(state)
		survivors.append(_stack_counts(session.overworld.get("army", {})))
		if state != "victory":
			break
		if placement_id == "charter_bridgeward_levies":
			post_hook_counts = _stack_counts(session.overworld.get("army", {}))
			post_hook_mirrors_exact = _army_mirrors_exact(session)
			if use_authored_reinforcement:
				if post_hook_counts != {
					"unit_blackbranch_cutthroat": 7,
					"unit_bog_brute": 6,
					"unit_mire_slinger": 19,
					"unit_river_guard": 8,
				}:
					_fail("Charter Reed-Watcher hook did not produce the exact deterministic post-Bridgeward fifteen-Slinger army: %s" % JSON.stringify(post_hook_counts))
					return {}
				var saved: Dictionary = _save_restore_after_charter_reinforcement(session)
				if not bool(saved.get("ok", false)):
					return {}
				session = saved.get("session", session)
				save_resume_exact = bool(saved.get("save_resume_exact", false))
				one_shot_exact = bool(saved.get("one_shot_exact", false))
	if use_authored_reinforcement and states == ["victory", "victory", "victory"]:
		session.battle = BattleRulesScript.create_town_assault_payload(session, "highwater_keep")
		town_enemy_entry = _battle_side_counts(session.battle, "enemy")
		var town_result: Dictionary = _resolve_like_live_validation(session, true, false)
		town_state = String(town_result.get("state", ""))
		town_survivors = _stack_counts(session.overworld.get("army", {}))
		if town_state == "victory":
			_campaign_profile_after_chapter_two = CampaignRulesScript.record_session_completion(_campaign_profile_after_chapter_one, session)
	return {
		"states": states,
		"survivors": survivors,
		"enemy_entries": enemy_entries,
		"reinforcement_fired_ids": session.overworld.get("scenario_script_state", {}).get("fired_hook_ids", []),
		"post_hook_counts": post_hook_counts,
		"campaign_entry": campaign_entry,
		"campaign_entry_exact": campaign_entry_exact,
		"army_mirrors_exact": post_hook_mirrors_exact and _army_mirrors_exact(session),
		"save_resume_exact": save_resume_exact,
		"one_shot_exact": one_shot_exact,
		"town_state": town_state,
		"town_survivors": town_survivors,
		"town_enemy_entry": town_enemy_entry,
	}

func _run_lockmarsh_followthrough(use_authored_reinforcement: bool) -> Dictionary:
	if _campaign_profile_after_chapter_two.is_empty():
		_fail("Lockmarsh followthrough has no completed Charter campaign profile to import.")
		return {}
	var session: SessionStateStoreScript.SessionData = CampaignRulesScript.build_session(
		_campaign_profile_after_chapter_two,
		LOCKMARSH_SCENARIO_ID,
		"normal",
		CAMPAIGN_ID
	)
	var campaign_entry: Dictionary = _lockmarsh_campaign_entry_signature(session)
	var campaign_entry_exact: bool = String(campaign_entry.get("scenario_id", "")) == LOCKMARSH_SCENARIO_ID \
		and String(campaign_entry.get("launch_mode", "")) == SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN \
		and String(campaign_entry.get("campaign_id", "")) == CAMPAIGN_ID \
		and String(campaign_entry.get("previous_scenario_id", "")) == CHARTER_SCENARIO_ID \
		and bool(campaign_entry.get("carryover_charter_road_opened", false)) \
		and bool(campaign_entry.get("carryover_beacon_wardens_broken", false)) \
		and bool(campaign_entry.get("carryover_granary_levies_broken", false)) \
		and RIVERWATCH_GORGET_ID in campaign_entry.get("artifact_ids", [])
	if not campaign_entry_exact:
		_fail("Lockmarsh followthrough did not import the exact Charter campaign carryover: %s" % JSON.stringify(campaign_entry))
		return {}
	_set_live_army(session, LOCKMARSH_PRE_ROAD_COUNTS)
	ScenarioScriptRulesScript.normalize_script_state(session)
	if not use_authored_reinforcement:
		var suppressed_state: Dictionary = session.overworld.get("scenario_script_state", {})
		var fired_hook_ids: Array = suppressed_state.get("fired_hook_ids", []).duplicate()
		if LOCKMARSH_REINFORCEMENT_HOOK_ID not in fired_hook_ids:
			fired_hook_ids.append(LOCKMARSH_REINFORCEMENT_HOOK_ID)
		suppressed_state["fired_hook_ids"] = fired_hook_ids
		session.overworld["scenario_script_state"] = suppressed_state
	var post_hook_counts := {}
	var post_hook_mirrors_exact := false
	var save_resume_exact := not use_authored_reinforcement
	var one_shot_exact := not use_authored_reinforcement
	var states := []
	var survivors := []
	var enemy_entries := []
	for placement_id in LOCKMARSH_REQUIRED_ENCOUNTERS:
		var encounter: Dictionary = _encounter_for_scenario(ContentService.get_scenario(LOCKMARSH_SCENARIO_ID), placement_id)
		session.battle = BattleRulesScript.create_battle_payload(session, encounter)
		enemy_entries.append(_battle_side_counts(session.battle, "enemy"))
		var high_difficulty := String(encounter.get("difficulty", "")) == "high"
		var result: Dictionary = _resolve_like_live_validation(session, high_difficulty, high_difficulty)
		var state := String(result.get("state", ""))
		states.append(state)
		survivors.append(_stack_counts(session.overworld.get("army", {})))
		if state != "victory":
			break
		if placement_id == "surge_road_chaplains":
			post_hook_counts = _stack_counts(session.overworld.get("army", {}))
			post_hook_mirrors_exact = _army_mirrors_exact(session)
			if use_authored_reinforcement:
				if post_hook_counts != {"unit_blackbranch_cutthroat": 31, "unit_bog_brute": 4}:
					_fail("Lockmarsh Reed-Watcher hook did not produce the exact deterministic post-Road thirty-one-Cutthroat army: %s" % JSON.stringify(post_hook_counts))
					return {}
				var saved: Dictionary = _save_restore_after_lockmarsh_reinforcement(session)
				if not bool(saved.get("ok", false)):
					return {}
				session = saved.get("session", session)
				save_resume_exact = bool(saved.get("save_resume_exact", false))
				one_shot_exact = bool(saved.get("one_shot_exact", false))
	return {
		"states": states,
		"survivors": survivors,
		"enemy_entries": enemy_entries,
		"reinforcement_fired_ids": session.overworld.get("scenario_script_state", {}).get("fired_hook_ids", []),
		"post_hook_counts": post_hook_counts,
		"campaign_entry": campaign_entry,
		"campaign_entry_exact": campaign_entry_exact,
		"army_mirrors_exact": post_hook_mirrors_exact and _army_mirrors_exact(session),
		"save_resume_exact": save_resume_exact,
		"one_shot_exact": one_shot_exact,
	}

func _run_lockmarsh_finale_candidate(additional_cutthroats: int, use_authored_hook: bool) -> Dictionary:
	var session: SessionStateStoreScript.SessionData = CampaignRulesScript.build_session(
		_campaign_profile_after_chapter_two,
		LOCKMARSH_SCENARIO_ID,
		"normal",
		CAMPAIGN_ID
	)
	_set_live_finale_fixture(session, additional_cutthroats, use_authored_hook)
	var pre_hook_counts: Dictionary = _stack_counts(session.overworld.get("army", {}))
	var post_hook_counts: Dictionary = pre_hook_counts.duplicate(true)
	var fired_ids: Array = []
	var save_resume_exact := not use_authored_hook
	var one_shot_exact := not use_authored_hook
	if use_authored_hook:
		var hook_result: Dictionary = ScenarioScriptRulesScript.process_hooks(session)
		fired_ids = hook_result.get("fired_ids", []).duplicate()
		post_hook_counts = _stack_counts(session.overworld.get("army", {}))
		if fired_ids != [LOCKMARSH_FINALE_REINFORCEMENT_HOOK_ID] or post_hook_counts != LOCKMARSH_LIVE_FINALE_SELECTED_COUNTS:
			_fail("Exact post-Archive production hook did not add eleven Cutthroats once: %s" % JSON.stringify({"hook_result": hook_result, "counts": post_hook_counts}))
			return {}
		var saved: Dictionary = _save_restore_after_lockmarsh_finale_reinforcement(session)
		if not bool(saved.get("ok", false)):
			return {}
		session = saved.get("session", session)
		save_resume_exact = bool(saved.get("save_resume_exact", false))
		one_shot_exact = bool(saved.get("one_shot_exact", false))
	var commander_exact: bool = _live_finale_commander_exact(session)
	session.battle = BattleRulesScript.create_town_assault_payload(session, "highwater_keep")
	var _briefing_text: String = BattleRulesScript.consume_tactical_briefing(session)
	var player_entry_order: Array = _battle_side_unit_order(session.battle, "player")
	var enemy_entry: Dictionary = _battle_side_counts(session.battle, "enemy")
	var combat_seed := int(session.battle.get("combat_seed", 0))
	var damage_rng_state := String(session.battle.get("damage_rng_state", ""))
	var enemy_battle_traits: Array = session.battle.get("enemy_hero_payload", {}).get("battle_traits", []).duplicate()
	var result: Dictionary = _resolve_like_live_validation(session, true, false)
	var action_trace: Array = result.get("action_trace", []).duplicate(true)
	var live_trace_prefix_exact := additional_cutthroats == LOCKMARSH_FINALE_REINFORCEMENT_CUTTHROATS - 1 \
		and action_trace.size() >= 3 \
		and String(action_trace[0].get("message", "")) == "Vaska Reedmaw casts Cinder Burst on River Guard for 37 damage. River Guard is staggered. Blackbranch Cutthroat seizes the tempo." \
		and "River Guard batters Bog Brute for 28 damage." in String(action_trace[1].get("message", "")) \
		and "River Guard braces for impact. River Guard steadies the line." in String(action_trace[1].get("message", "")) \
		and "Blackbranch Cutthroat retaliates for 53 damage." in String(action_trace[2].get("message", ""))
	return {
		"additional_cutthroats": additional_cutthroats,
		"use_authored_hook": use_authored_hook,
		"pre_hook_counts": pre_hook_counts,
		"post_hook_counts": post_hook_counts,
		"player_entry_order": player_entry_order,
		"enemy_entry": enemy_entry,
		"enemy_battle_traits": enemy_battle_traits,
		"combat_seed": combat_seed,
		"damage_rng_state": damage_rng_state,
		"live_trace_prefix_exact": live_trace_prefix_exact,
		"state": String(result.get("state", "")),
		"steps": int(result.get("steps", 0)),
		"action_trace": action_trace,
		"survivors": _stack_counts(session.overworld.get("army", {})),
		"fired_ids": fired_ids,
		"commander_exact": commander_exact,
		"army_mirrors_exact": _army_mirrors_exact(session),
		"save_resume_exact": save_resume_exact,
		"one_shot_exact": one_shot_exact,
	}

func _set_live_finale_fixture(session: SessionStateStoreScript.SessionData, additional_cutthroats: int, use_authored_hook: bool) -> void:
	session.day = 2
	session.flags["road_chaplains_broken"] = true
	session.flags["charter_guard_broken"] = true
	session.overworld["resolved_encounters"] = LOCKMARSH_REQUIRED_ENCOUNTERS.duplicate()
	_set_live_finale_commander(session)
	var counts: Dictionary = LOCKMARSH_LIVE_POST_ARCHIVE_COUNTS.duplicate(true)
	if not use_authored_hook:
		counts["unit_blackbranch_cutthroat"] = int(counts.get("unit_blackbranch_cutthroat", 0)) + additional_cutthroats
	_set_live_army(session, counts, LOCKMARSH_LIVE_FINALE_STACK_ORDER)
	_set_live_highwater_garrison(session)
	ScenarioScriptRulesScript.normalize_script_state(session)
	var fired_hook_ids := [
		"open_charter_road",
		"beacon_scout_cache",
		"chaplain_firebreak",
		LOCKMARSH_REINFORCEMENT_HOOK_ID,
		"charter_ledger_breach",
	]
	if not use_authored_hook:
		fired_hook_ids.append(LOCKMARSH_FINALE_REINFORCEMENT_HOOK_ID)
	session.overworld["scenario_script_state"] = {
		"fired_hook_ids": fired_hook_ids,
		"event_log": [],
	}

func _set_live_finale_commander(session: SessionStateStoreScript.SessionData) -> void:
	var active_hero_id := String(session.overworld.get("active_hero_id", session.hero_id))
	var hero: Dictionary = session.overworld.get("hero", {}).duplicate(true)
	hero["level"] = 4
	hero["experience"] = 1640
	hero["next_level_experience"] = 1900
	hero["command"] = {"attack": 4, "defense": 1, "power": 1, "knowledge": 1}
	hero["specialties"] = ["drillmaster", "armsmaster", "armsmaster", "drillmaster"]
	hero["pending_specialty_choices"] = []
	hero["movement"] = {"current": 13, "max": 15}
	hero["position"] = {"x": 10, "y": 2}
	var spellbook: Dictionary = hero.get("spellbook", {}).duplicate(true)
	spellbook["mana"] = {"current": 12, "max": 12}
	hero["spellbook"] = spellbook
	session.overworld["hero"] = hero.duplicate(true)
	var player_heroes: Array = session.overworld.get("player_heroes", []).duplicate(true)
	for index in range(player_heroes.size()):
		if player_heroes[index] is Dictionary and String(player_heroes[index].get("id", "")) == active_hero_id:
			player_heroes[index] = hero.duplicate(true)
	session.overworld["player_heroes"] = player_heroes

func _live_finale_commander_exact(session: SessionStateStoreScript.SessionData) -> bool:
	var hero: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	var spellbook: Dictionary = hero.get("spellbook", {}) if hero.get("spellbook", {}) is Dictionary else {}
	return int(hero.get("level", 0)) == 4 \
		and int(hero.get("experience", 0)) == 1640 \
		and hero.get("command", {}) == {"attack": 4, "defense": 1, "power": 1, "knowledge": 1} \
		and hero.get("specialties", []) == ["drillmaster", "armsmaster", "armsmaster", "drillmaster"] \
		and hero.get("pending_specialty_choices", []) == [] \
		and spellbook.get("mana", {}) == {"current": 12, "max": 12}

func _set_live_highwater_garrison(session: SessionStateStoreScript.SessionData) -> void:
	var towns: Array = session.overworld.get("towns", []).duplicate(true)
	for index in range(towns.size()):
		if towns[index] is Dictionary and String(towns[index].get("placement_id", "")) == "highwater_keep":
			var town: Dictionary = towns[index].duplicate(true)
			town["garrison"] = [
				{"unit_id": "unit_river_guard", "count": 16},
				{"unit_id": "unit_ember_archer", "count": 2},
				{"unit_id": "unit_citadel_pikeward", "count": 1},
			]
			town["available_recruits"] = {"unit_river_guard": 0}
			towns[index] = town
			break
	session.overworld["towns"] = towns

func _save_restore_after_lockmarsh_finale_reinforcement(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var signature_before: Dictionary = _session_signature(session)
	var save_result: Dictionary = SaveService.save_runtime_manual_session(session, LOCKMARSH_FINALE_SAVE_SLOT)
	if not bool(save_result.get("ok", false)):
		_fail("Lockmarsh post-Archive reinforcement runtime save failed: %s" % JSON.stringify(save_result))
		return {}
	var summary: Dictionary = SaveService.inspect_manual_slot(LOCKMARSH_FINALE_SAVE_SLOT)
	var restored: SessionStateStoreScript.SessionData = SaveService.restore_manual_session(LOCKMARSH_FINALE_SAVE_SLOT)
	if restored == null:
		_fail("Lockmarsh post-Archive reinforcement runtime save did not restore.")
		return {}
	var signature_after: Dictionary = _session_signature(restored)
	var army_before: Dictionary = restored.overworld.get("army", {}).duplicate(true)
	var refire: Dictionary = ScenarioScriptRulesScript.process_hooks(restored)
	return {
		"ok": true,
		"session": restored,
		"save_resume_exact": signature_after == signature_before and String(summary.get("resume_target", "")) == "overworld",
		"one_shot_exact": refire.get("fired_ids", []).find(LOCKMARSH_FINALE_REINFORCEMENT_HOOK_ID) == -1 and restored.overworld.get("army", {}) == army_before,
	}

func _save_restore_after_lockmarsh_reinforcement(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var signature_before: Dictionary = _session_signature(session)
	var save_result: Dictionary = SaveService.save_runtime_manual_session(session, LOCKMARSH_SAVE_SLOT)
	if not bool(save_result.get("ok", false)):
		_fail("Lockmarsh Reed-Watcher reinforcement runtime save failed: %s" % JSON.stringify(save_result))
		return {}
	var summary: Dictionary = SaveService.inspect_manual_slot(LOCKMARSH_SAVE_SLOT)
	var restored: SessionStateStoreScript.SessionData = SaveService.restore_manual_session(LOCKMARSH_SAVE_SLOT)
	if restored == null:
		_fail("Lockmarsh Reed-Watcher reinforcement runtime save did not restore.")
		return {}
	var signature_after: Dictionary = _session_signature(restored)
	var army_before: Dictionary = restored.overworld.get("army", {}).duplicate(true)
	var refire: Dictionary = ScenarioScriptRulesScript.process_hooks(restored)
	return {
		"ok": true,
		"session": restored,
		"save_resume_exact": signature_after == signature_before and String(summary.get("resume_target", "")) == "overworld",
		"one_shot_exact": refire.get("fired_ids", []).find(LOCKMARSH_REINFORCEMENT_HOOK_ID) == -1 and restored.overworld.get("army", {}) == army_before,
	}

func _save_restore_after_charter_reinforcement(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var signature_before: Dictionary = _session_signature(session)
	var save_result: Dictionary = SaveService.save_runtime_manual_session(session, CHARTER_SAVE_SLOT)
	if not bool(save_result.get("ok", false)):
		_fail("Charter Reed-Watcher reinforcement runtime save failed: %s" % JSON.stringify(save_result))
		return {}
	var summary: Dictionary = SaveService.inspect_manual_slot(CHARTER_SAVE_SLOT)
	var restored: SessionStateStoreScript.SessionData = SaveService.restore_manual_session(CHARTER_SAVE_SLOT)
	if restored == null:
		_fail("Charter Reed-Watcher reinforcement runtime save did not restore.")
		return {}
	var signature_after: Dictionary = _session_signature(restored)
	var army_before: Dictionary = restored.overworld.get("army", {}).duplicate(true)
	var refire: Dictionary = ScenarioScriptRulesScript.process_hooks(restored)
	return {
		"ok": true,
		"session": restored,
		"save_resume_exact": signature_after == signature_before and String(summary.get("resume_target", "")) == "overworld",
		"one_shot_exact": refire.get("fired_ids", []).find(CHARTER_REINFORCEMENT_HOOK_ID) == -1 and restored.overworld.get("army", {}) == army_before,
	}

func _save_restore_after_reinforcement(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var signature_before: Dictionary = _session_signature(session)
	var save_result: Dictionary = SaveService.save_runtime_manual_session(session, SAVE_SLOT)
	if not bool(save_result.get("ok", false)):
		_fail("Bogbound reinforcement runtime save failed: %s" % JSON.stringify(save_result))
		return {}
	var summary: Dictionary = SaveService.inspect_manual_slot(SAVE_SLOT)
	var restored: SessionStateStoreScript.SessionData = SaveService.restore_manual_session(SAVE_SLOT)
	if restored == null:
		_fail("Bogbound reinforcement runtime save did not restore.")
		return {}
	var signature_after: Dictionary = _session_signature(restored)
	var army_before: Dictionary = restored.overworld.get("army", {}).duplicate(true)
	var refire: Dictionary = ScenarioScriptRulesScript.process_hooks(restored)
	return {
		"ok": true,
		"session": restored,
		"save_resume_exact": signature_after == signature_before and String(summary.get("resume_target", "")) == "overworld",
		"one_shot_exact": refire.get("fired_ids", []).find(REINFORCEMENT_HOOK_ID) == -1 and restored.overworld.get("army", {}) == army_before,
	}

func _sequence_payload(session: SessionStateStoreScript.SessionData, identity_before: Dictionary, states: Array, survivors: Array, enemy_entries: Array, town_enemy_entry: Dictionary, save_resume_exact: bool, one_shot_exact: bool) -> Dictionary:
	return {
		"states": states,
		"survivors": survivors,
		"enemy_entries": enemy_entries,
		"town_enemy_entry": town_enemy_entry,
		"reinforcement_fired_ids": session.overworld.get("scenario_script_state", {}).get("fired_hook_ids", []),
		"army_mirrors_exact": _army_mirrors_exact(session),
		"save_resume_exact": save_resume_exact,
		"one_shot_exact": one_shot_exact,
		"session_identity_exact": identity_before == {"scenario_id": session.scenario_id, "launch_mode": session.launch_mode, "difficulty": session.difficulty},
	}

func _suppress_reinforcement_hook(session: SessionStateStoreScript.SessionData) -> void:
	ScenarioScriptRulesScript.normalize_script_state(session)
	var state: Dictionary = session.overworld.get("scenario_script_state", {})
	state["fired_hook_ids"] = [REINFORCEMENT_HOOK_ID]
	session.overworld["scenario_script_state"] = state

func _set_live_army(session: SessionStateStoreScript.SessionData, counts: Dictionary, stack_order: Array = []) -> void:
	var army: Dictionary = ContentService.get_army_group(ARMY_ID).duplicate(true)
	army["stacks"] = []
	var ordered_unit_ids: Array = stack_order if not stack_order.is_empty() else counts.keys()
	for unit_id in ordered_unit_ids:
		army["stacks"].append({"unit_id": unit_id, "count": int(counts.get(unit_id, 0))})
	session.overworld["army"] = army.duplicate(true)
	var hero: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	hero["army"] = army.duplicate(true)
	session.overworld["hero"] = hero
	var player_heroes: Array = session.overworld.get("player_heroes", [])
	for index in range(player_heroes.size()):
		var candidate: Dictionary = player_heroes[index] if player_heroes[index] is Dictionary else {}
		if String(candidate.get("id", "")) == String(session.overworld.get("active_hero_id", "")):
			candidate["army"] = army.duplicate(true)
			player_heroes[index] = candidate
	session.overworld["player_heroes"] = player_heroes

func _army_mirrors_exact(session: SessionStateStoreScript.SessionData) -> bool:
	var army: Dictionary = session.overworld.get("army", {})
	if session.overworld.get("hero", {}).get("army", {}) != army:
		return false
	for value in session.overworld.get("player_heroes", []):
		if value is Dictionary and String(value.get("id", "")) == String(session.overworld.get("active_hero_id", "")):
			return value.get("army", {}) == army
	return false

func _session_signature(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return {
		"scenario_id": session.scenario_id,
		"launch_mode": session.launch_mode,
		"day": session.day,
		"army": session.overworld.get("army", {}),
		"hero_army": session.overworld.get("hero", {}).get("army", {}),
		"resolved_encounters": session.overworld.get("resolved_encounters", []),
		"script_state": session.overworld.get("scenario_script_state", {}),
		"resources": session.overworld.get("resources", {}),
	}

func _charter_campaign_entry_signature(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var hero: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	return {
		"scenario_id": session.scenario_id,
		"launch_mode": session.launch_mode,
		"campaign_id": String(session.flags.get("campaign_id", "")),
		"previous_scenario_id": String(session.flags.get("campaign_previous_scenario_id", "")),
		"carryover_lantern_patrol_broken": bool(session.flags.get("carryover_lantern_patrol_broken", false)),
		"artifact_ids": _owned_artifact_ids(session),
		"hero_level": int(hero.get("level", 0)),
		"hero_experience": int(hero.get("experience", 0)),
		"hero_command": hero.get("command", {}).duplicate(true),
		"hero_specialties": hero.get("specialties", []).duplicate(true),
		"hero_pending_specialty_choices": hero.get("pending_specialty_choices", []).duplicate(true),
		"hero_spellbook": hero.get("spellbook", {}).duplicate(true),
	}

func _lockmarsh_campaign_entry_signature(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var hero: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	return {
		"scenario_id": session.scenario_id,
		"launch_mode": session.launch_mode,
		"campaign_id": String(session.flags.get("campaign_id", "")),
		"previous_scenario_id": String(session.flags.get("campaign_previous_scenario_id", "")),
		"carryover_charter_road_opened": bool(session.flags.get("carryover_charter_road_opened", false)),
		"carryover_beacon_wardens_broken": bool(session.flags.get("carryover_beacon_wardens_broken", false)),
		"carryover_granary_levies_broken": bool(session.flags.get("carryover_granary_levies_broken", false)),
		"artifact_ids": _owned_artifact_ids(session),
		"hero_level": int(hero.get("level", 0)),
		"hero_experience": int(hero.get("experience", 0)),
		"hero_command": hero.get("command", {}).duplicate(true),
		"hero_specialties": hero.get("specialties", []).duplicate(true),
		"hero_pending_specialty_choices": hero.get("pending_specialty_choices", []).duplicate(true),
		"hero_spellbook": hero.get("spellbook", {}).duplicate(true),
	}

func _owned_artifact_ids(session: SessionStateStoreScript.SessionData) -> Array:
	var hero: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	var artifacts: Dictionary = hero.get("artifacts", {}) if hero.get("artifacts", {}) is Dictionary else {}
	var result := []
	for artifact_id_value in artifacts.get("equipped", {}).values():
		var artifact_id := String(artifact_id_value)
		if artifact_id != "" and artifact_id not in result:
			result.append(artifact_id)
	for artifact_id_value in artifacts.get("inventory", []):
		var artifact_id := String(artifact_id_value)
		if artifact_id != "" and artifact_id not in result:
			result.append(artifact_id)
	return result

func _resolve_like_live_validation(
	session: SessionStateStoreScript.SessionData,
	enable_spell: bool = false,
	prioritize_support: bool = false
) -> Dictionary:
	var last_state := "continue"
	var spell_casts := 0
	var action_trace: Array = []
	for step in range(1, 257):
		if session.battle.is_empty():
			return {"state": last_state, "steps": step - 1, "action_trace": action_trace}
		var active_stack: Dictionary = BattleRulesScript.get_active_stack(session.battle)
		if active_stack.is_empty() or String(active_stack.get("side", "")) != "player":
			var ready_result: Dictionary = BattleRulesScript.resolve_if_battle_ready(session)
			action_trace.append({"action": "resolve_ready_state", "state": String(ready_result.get("state", "")), "message": String(ready_result.get("message", ""))})
			last_state = String(ready_result.get("state", "continue"))
			if last_state in ["victory", "defeat", "retreat", "surrender", "stalemate", "hero_defeat", "town_lost"]:
				return {"state": last_state, "steps": step, "action_trace": action_trace}
			continue
		_align_target(session)
		if enable_spell and spell_casts < 1:
			var spell_id := _preferred_validation_spell_id(session, prioritize_support)
			if spell_id != "":
				var spell_result: Dictionary = BattleRulesScript.cast_player_spell(session, spell_id)
				action_trace.append({"action": "cast_spell", "action_id": "cast_spell:%s" % spell_id, "state": String(spell_result.get("state", "")), "message": String(spell_result.get("message", ""))})
				last_state = String(spell_result.get("state", "continue"))
				if bool(spell_result.get("ok", false)):
					spell_casts += 1
				if last_state in ["victory", "defeat", "retreat", "surrender", "stalemate", "hero_defeat", "town_lost"]:
					if not session.battle.is_empty():
						var terminal_spell_ready: Dictionary = BattleRulesScript.resolve_if_battle_ready(session)
						last_state = String(terminal_spell_ready.get("state", last_state))
					return {"state": last_state, "steps": step, "action_trace": action_trace}
				continue
		var action_id := _preferred_action(session)
		if action_id == "":
			return {"state": "invalid", "steps": step, "action_trace": action_trace}
		var action_result: Dictionary = BattleRulesScript.perform_player_action(session, action_id)
		action_trace.append({"action": action_id, "state": String(action_result.get("state", "")), "message": String(action_result.get("message", ""))})
		last_state = String(action_result.get("state", "continue"))
		if last_state in ["victory", "defeat", "retreat", "surrender", "stalemate", "hero_defeat", "town_lost"]:
			if not session.battle.is_empty():
				var terminal_action_ready: Dictionary = BattleRulesScript.resolve_if_battle_ready(session)
				last_state = String(terminal_action_ready.get("state", last_state))
			return {"state": last_state, "steps": step, "action_trace": action_trace}
	return {"state": "stalled", "steps": 256, "action_trace": action_trace}

func _preferred_validation_spell_id(session: SessionStateStoreScript.SessionData, prioritize_support: bool) -> String:
	var fallback := ""
	var support_fallback := ""
	for action in BattleRulesScript.get_spell_actions(session):
		if not (action is Dictionary) or bool(action.get("disabled", false)):
			continue
		var spell_id := String(action.get("id", "")).trim_prefix("cast_spell:")
		var spell: Dictionary = ContentService.get_spell(spell_id)
		var effect_type := String(spell.get("effect", {}).get("type", ""))
		if support_fallback == "" and effect_type in ["defense_buff", "initiative_buff", "attack_buff"]:
			support_fallback = spell_id
		if effect_type == "damage_enemy" and not prioritize_support:
			return spell_id
		if fallback == "":
			fallback = spell_id
	if prioritize_support and support_fallback != "":
		return support_fallback
	return fallback

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

func _script_hook(scenario: Dictionary, hook_id: String) -> Dictionary:
	return _script_hook_for_scenario(scenario, hook_id)

func _script_hook_for_scenario(scenario: Dictionary, hook_id: String) -> Dictionary:
	for value in scenario.get("script_hooks", []):
		if value is Dictionary and String(value.get("id", "")) == hook_id:
			return value.duplicate(true)
	return {}

func _encounter(placement_id: String) -> Dictionary:
	return _encounter_for_scenario(ContentService.get_scenario(SCENARIO_ID), placement_id)

func _encounter_for_scenario(scenario: Dictionary, placement_id: String) -> Dictionary:
	for value in scenario.get("encounters", []):
		if value is Dictionary and String(value.get("placement_id", "")) == placement_id:
			return value.duplicate(true)
	return {}

func _encounter_entry_counts(encounter: Dictionary) -> Dictionary:
	var army: Dictionary = encounter.get("enemy_army", {}) if encounter.get("enemy_army", {}) is Dictionary else {}
	if army.is_empty():
		var definition: Dictionary = ContentService.get_encounter(String(encounter.get("encounter_id", "")))
		army = ContentService.get_army_group(String(definition.get("enemy_group_id", "")))
	return _stack_counts(army)

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

func _battle_side_unit_order(battle: Dictionary, side: String) -> Array:
	var result: Array = []
	for value in battle.get("stacks", []):
		if value is Dictionary and String(value.get("side", "")) == side:
			result.append(String(value.get("unit_id", "")))
	return result

func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error(message)
	get_tree().quit(1)
