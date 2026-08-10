extends Node

const REPORT_ID := "CAMPAIGN_REPLAY_PROGRESS_PRESERVATION_REGRESSION"
const CAMPAIGN_ID := "campaign_reedfall"
const OPENING_SCENARIO_ID := "river-pass"
const SECOND_SCENARIO_ID := "causeway-stand"
const FINAL_SCENARIO_ID := "fen-crown"
const PROGRESSION_PATH := "user://saves/campaign_progression.json"

var _original_progression_states := {}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ContentService.clear_cache()
	_original_progression_states = _capture_progression_states()

	var victory_defeat := _prove_victory_defeat_preserves_clear()
	if victory_defeat.is_empty():
		return
	var first_defeat := _prove_first_defeat_stays_locked()
	if first_defeat.is_empty():
		return
	var defeat_victory := _prove_defeat_victory_unlocks()
	if defeat_victory.is_empty():
		return
	var victory_refresh := _prove_victory_victory_refreshes()
	if victory_refresh.is_empty():
		return
	var persistence := _prove_normalization_and_progression_reload(victory_defeat.get("profile", {}))
	if persistence.is_empty():
		return

	_cleanup()
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"victory_defeat": _without_profile(victory_defeat),
		"first_defeat": first_defeat,
		"defeat_victory": defeat_victory,
		"victory_victory_refresh": victory_refresh,
		"normalization_and_reload": persistence,
		"save_version": SessionState.SAVE_VERSION,
	})])
	get_tree().quit(0)

func _prove_victory_defeat_preserves_clear() -> Dictionary:
	var profile := CampaignRules.build_profile()
	profile = _record(profile, OPENING_SCENARIO_ID, "victory", 7, "River Pass secured", {
		"pass_cleared": true,
	}, {"gold": 1600, "wood": 6, "ore": 4})
	if not CampaignRules.is_scenario_unlocked(profile, CAMPAIGN_ID, SECOND_SCENARIO_ID):
		return _fail_dictionary("Opening victory did not unlock Causeway Stand.")

	profile = _record(profile, SECOND_SCENARIO_ID, "victory", 12, "Blackfen Gate broken", {
		"reed_camp_cleared": true,
		"gate_marshals_broken": true,
	}, {"gold": 2400, "wood": 8, "ore": 6})
	var before_state := CampaignRules.get_campaign_state(profile, CAMPAIGN_ID)
	var before_record: Dictionary = CampaignRules.get_scenario_record(profile, CAMPAIGN_ID, SECOND_SCENARIO_ID).duplicate(true)
	var before_bundle: Dictionary = before_state.get("carryover_bundles", {}).get(SECOND_SCENARIO_ID, {}).duplicate(true)
	var before_attempts := int(before_record.get("attempts", 0))
	if String(before_record.get("status", "")) != "victory" \
			or not bool(before_record.get("exported_flags", {}).get("gate_marshals_broken", false)) \
			or before_bundle.is_empty() \
			or not CampaignRules.is_scenario_unlocked(profile, CAMPAIGN_ID, FINAL_SCENARIO_ID):
		return _fail_dictionary("Causeway victory did not establish the required cleared-state authority.")

	var defeat_session = _outcome_session(profile, SECOND_SCENARIO_ID, "defeat", 15, "Causeway replay lost", {}, {"gold": 3})
	if defeat_session == null:
		return _fail_dictionary("Could not construct the Causeway replay defeat session.")
	var after := CampaignRules.record_session_completion(profile, defeat_session)
	var after_state := CampaignRules.get_campaign_state(after, CAMPAIGN_ID)
	var after_record: Dictionary = CampaignRules.get_scenario_record(after, CAMPAIGN_ID, SECOND_SCENARIO_ID)
	var after_bundle: Dictionary = after_state.get("carryover_bundles", {}).get(SECOND_SCENARIO_ID, {})
	var expected_record := before_record.duplicate(true)
	expected_record["attempts"] = before_attempts + 1
	var restart_action := CampaignRules.build_restart_action(after, CAMPAIGN_ID)
	if after_record != expected_record:
		return _fail_dictionary("Replay defeat changed the recorded Causeway victory beyond incrementing attempts: %s" % JSON.stringify({
			"expected": expected_record,
			"actual": after_record,
		}))
	if after_bundle != before_bundle:
		return _fail_dictionary("Replay defeat changed the victory carryover bundle.")
	if not CampaignRules.is_scenario_unlocked(after, CAMPAIGN_ID, FINAL_SCENARIO_ID):
		return _fail_dictionary("Replay defeat relocked Fen Crown after it was cleared for entry.")
	if int(restart_action.get("victory_count", -1)) != 2 \
			or int(after_state.get("scenario_records", {}).size()) != 2 \
			or String(after_state.get("last_completed_scenario_id", "")) != SECOND_SCENARIO_ID \
			or String(after.get("last_campaign_id", "")) != CAMPAIGN_ID \
			or String(after.get("last_scenario_id", "")) != SECOND_SCENARIO_ID:
		return _fail_dictionary("Replay defeat changed campaign progress counts or completion pointers: %s" % JSON.stringify({
			"restart_action": restart_action,
			"state": after_state,
			"last_campaign_id": after.get("last_campaign_id", ""),
			"last_scenario_id": after.get("last_scenario_id", ""),
		}))
	if defeat_session.scenario_status != "defeat":
		return _fail_dictionary("Preserving cleared progress mutated the live replay outcome.")
	return {
		"profile": after,
		"attempts": int(after_record.get("attempts", 0)),
		"victories": 2,
		"record_count": 2,
		"exported_flag_preserved": true,
		"carryover_preserved": true,
		"finale_unlocked": true,
		"live_outcome": defeat_session.scenario_status,
	}

func _prove_first_defeat_stays_locked() -> Dictionary:
	var profile := CampaignRules.build_profile()
	profile = _record(profile, OPENING_SCENARIO_ID, "defeat", 5, "River Pass lost", {
		"pass_cleared": true,
	}, {"gold": 2000})
	var state := CampaignRules.get_campaign_state(profile, CAMPAIGN_ID)
	var record := CampaignRules.get_scenario_record(profile, CAMPAIGN_ID, OPENING_SCENARIO_ID)
	if String(record.get("status", "")) != "defeat" \
			or int(record.get("attempts", 0)) != 1 \
			or CampaignRules.is_scenario_unlocked(profile, CAMPAIGN_ID, SECOND_SCENARIO_ID) \
			or state.get("carryover_bundles", {}).has(OPENING_SCENARIO_ID) \
			or int(CampaignRules.build_restart_action(profile, CAMPAIGN_ID).get("victory_count", -1)) != 0:
		return _fail_dictionary("A first defeat incorrectly banked a clear, carryover, or downstream unlock.")
	return {
		"attempts": 1,
		"victories": 0,
		"next_locked": true,
		"carryover_absent": true,
	}

func _prove_defeat_victory_unlocks() -> Dictionary:
	var profile := CampaignRules.build_profile()
	profile = _record(profile, OPENING_SCENARIO_ID, "defeat", 5, "River Pass lost", {}, {"gold": 100})
	profile = _record(profile, OPENING_SCENARIO_ID, "victory", 6, "River Pass recovered", {
		"pass_cleared": true,
	}, {"gold": 1400, "wood": 4})
	var state := CampaignRules.get_campaign_state(profile, CAMPAIGN_ID)
	var record := CampaignRules.get_scenario_record(profile, CAMPAIGN_ID, OPENING_SCENARIO_ID)
	if String(record.get("status", "")) != "victory" \
			or int(record.get("attempts", 0)) != 2 \
			or not bool(record.get("exported_flags", {}).get("pass_cleared", false)) \
			or not state.get("carryover_bundles", {}).has(OPENING_SCENARIO_ID) \
			or not CampaignRules.is_scenario_unlocked(profile, CAMPAIGN_ID, SECOND_SCENARIO_ID) \
			or int(CampaignRules.build_restart_action(profile, CAMPAIGN_ID).get("victory_count", -1)) != 1:
		return _fail_dictionary("Defeat followed by victory did not replace the failed record and unlock progression.")
	return {
		"attempts": 2,
		"victories": 1,
		"status": "victory",
		"next_unlocked": true,
		"carryover_banked": true,
	}

func _prove_victory_victory_refreshes() -> Dictionary:
	var profile := CampaignRules.build_profile()
	profile = _record(profile, OPENING_SCENARIO_ID, "victory", 8, "First River Pass victory", {
		"pass_cleared": true,
	}, {"gold": 800, "wood": 2})
	var first_bundle: Dictionary = CampaignRules.get_campaign_state(profile, CAMPAIGN_ID).get("carryover_bundles", {}).get(OPENING_SCENARIO_ID, {}).duplicate(true)
	profile = _record(profile, OPENING_SCENARIO_ID, "victory", 4, "Improved River Pass victory", {
		"mire_cleared": true,
	}, {"gold": 2200, "wood": 6})
	var record := CampaignRules.get_scenario_record(profile, CAMPAIGN_ID, OPENING_SCENARIO_ID)
	var refreshed_bundle: Dictionary = CampaignRules.get_campaign_state(profile, CAMPAIGN_ID).get("carryover_bundles", {}).get(OPENING_SCENARIO_ID, {})
	if String(record.get("status", "")) != "victory" \
			or int(record.get("attempts", 0)) != 2 \
			or int(record.get("day", 0)) != 4 \
			or String(record.get("summary", "")) != "Improved River Pass victory" \
			or record.get("exported_flags", {}) != {"mire_cleared": true} \
			or refreshed_bundle == first_bundle \
			or refreshed_bundle.get("flags", {}) != {"mire_cleared": true} \
			or int(refreshed_bundle.get("resources", {}).get("gold", 0)) != 1100:
		return _fail_dictionary("A repeat victory did not refresh the authored victory snapshot and carryover.")
	return {
		"attempts": 2,
		"status": "victory",
		"summary_refreshed": true,
		"day_refreshed": true,
		"exported_flags_refreshed": true,
		"carryover_refreshed": true,
	}

func _prove_normalization_and_progression_reload(profile_value: Variant) -> Dictionary:
	if not (profile_value is Dictionary):
		return _fail_dictionary("Victory/defeat profile was unavailable for persistence proof.")
	var profile: Dictionary = profile_value
	var normalized := CampaignRules.normalize_profile(profile)
	var normalized_record := CampaignRules.get_scenario_record(normalized, CAMPAIGN_ID, SECOND_SCENARIO_ID)
	var normalized_state := CampaignRules.get_campaign_state(normalized, CAMPAIGN_ID)
	if String(normalized_record.get("status", "")) != "victory" \
			or int(normalized_record.get("attempts", 0)) != 2 \
			or not bool(normalized_record.get("exported_flags", {}).get("gate_marshals_broken", false)) \
			or not normalized_state.get("carryover_bundles", {}).has(SECOND_SCENARIO_ID) \
			or not CampaignRules.is_scenario_unlocked(normalized, CAMPAIGN_ID, FINAL_SCENARIO_ID):
		return _fail_dictionary("Profile normalization lost preserved replay victory authority.")

	_remove_progression_artifacts()
	var saved_path := SaveService.save_progression(normalized)
	var loaded := CampaignRules.normalize_profile(SaveService.load_progression())
	if saved_path == "" or loaded != normalized:
		return _fail_dictionary("SaveService progression reload did not preserve the normalized replay profile exactly.")
	var loaded_record := CampaignRules.get_scenario_record(loaded, CAMPAIGN_ID, SECOND_SCENARIO_ID)
	if String(loaded_record.get("status", "")) != "victory" \
			or int(loaded_record.get("attempts", 0)) != 2 \
			or not CampaignRules.is_scenario_unlocked(loaded, CAMPAIGN_ID, FINAL_SCENARIO_ID):
		return _fail_dictionary("Reloaded progression no longer exposes the preserved victory and unlock.")
	return {
		"normalized_exact": true,
		"save_service_reload_exact": true,
		"status": "victory",
		"attempts": 2,
		"finale_unlocked": true,
	}

func _record(
	profile: Dictionary,
	scenario_id: String,
	status: String,
	day: int,
	summary: String,
	flags: Dictionary,
	resources: Dictionary
) -> Dictionary:
	var session = _outcome_session(profile, scenario_id, status, day, summary, flags, resources)
	if session == null:
		_fail("Could not build %s %s outcome fixture." % [scenario_id, status])
		return {}
	return CampaignRules.record_session_completion(profile, session)

func _outcome_session(
	profile: Dictionary,
	scenario_id: String,
	status: String,
	day: int,
	summary: String,
	flags: Dictionary,
	resources: Dictionary
):
	var session = CampaignRules.build_session(profile, scenario_id, "normal", CAMPAIGN_ID)
	if session == null or session.scenario_id != scenario_id:
		return null
	session.scenario_status = status
	session.scenario_summary = summary
	session.day = day
	for key in flags.keys():
		session.flags[String(key)] = flags[key]
	var stockpile: Dictionary = session.overworld.get("resources", {}).duplicate(true)
	for key in resources.keys():
		stockpile[String(key)] = int(resources[key])
	session.overworld["resources"] = stockpile
	return session

func _capture_progression_states() -> Dictionary:
	var states := {}
	for path in [PROGRESSION_PATH, "%s.candidate" % PROGRESSION_PATH, "%s.backup" % PROGRESSION_PATH]:
		states[path] = {
			"exists": FileAccess.file_exists(path),
			"bytes": FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray(),
		}
	return states

func _remove_progression_artifacts() -> void:
	for path in [PROGRESSION_PATH, "%s.candidate" % PROGRESSION_PATH, "%s.backup" % PROGRESSION_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _restore_progression_states() -> void:
	_remove_progression_artifacts()
	for path in _original_progression_states.keys():
		var state: Dictionary = _original_progression_states[path]
		if not bool(state.get("exists", false)):
			continue
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(String(path).get_base_dir()))
		var file := FileAccess.open(String(path), FileAccess.WRITE)
		if file != null:
			file.store_buffer(state.get("bytes", PackedByteArray()))
			file.close()

func _without_profile(result: Dictionary) -> Dictionary:
	var compact := result.duplicate(true)
	compact.erase("profile")
	return compact

func _cleanup() -> void:
	_restore_progression_states()
	CampaignProgression.load_profile()

func _fail_dictionary(message: String) -> Dictionary:
	_fail(message)
	return {}

func _fail(message: String) -> void:
	_cleanup()
	push_error("%s: %s" % [REPORT_ID, message])
	get_tree().quit(1)
