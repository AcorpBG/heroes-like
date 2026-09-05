extends Node

const ScenarioScriptRulesScript = preload("res://scripts/core/ScenarioScriptRules.gd")

const REPORT_ID := "CAMPAIGN_COMPLETION_PERSISTENCE_ATOMICITY_REGRESSION"
const FAILURE_ENV := "HEROES_LIKE_SAVE_FAIL_PHASE"
const CAMPAIGN_ID := "campaign_reedfall"
const SCENARIO_ID := "river-pass"
const NEXT_SCENARIO_ID := "causeway-stand"
const PROGRESSION_PATH := "user://saves/campaign_progression.json"
const MANUAL_PATH := "user://saves/slot1.json"

var _original_file_states := {}
var _original_failure_env := ""
var _original_profile := {}
var _original_active_session = null


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	ContentService.clear_cache()
	_original_file_states = _capture_file_states(_tracked_paths())
	_original_failure_env = OS.get_environment(FAILURE_ENV)
	_original_profile = CampaignProgression.profile.duplicate(true)
	_original_active_session = SessionState.active_session
	OS.unset_environment(FAILURE_ENV)
	if not _require_hooks():
		return

	var failure_rows := _prove_failure_phases_and_retry()
	if failure_rows.is_empty():
		return
	var first_defeat := _prove_first_defeat_control()
	if first_defeat.is_empty():
		return
	var skirmish := _prove_skirmish_control()
	if skirmish.is_empty():
		return

	_cleanup()
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"failure_phases": failure_rows,
		"first_defeat": first_defeat,
		"skirmish": skirmish,
		"save_version": SessionState.SAVE_VERSION,
	})])
	get_tree().quit(0)


func _require_hooks() -> bool:
	if not CampaignProgression.has_method("record_session_completion"):
		return _fail_bool("CampaignProgression is missing record_session_completion.")
	for method_name in [
		"validation_summary_cache_snapshot",
		"validation_clear_summary_cache",
		"validation_transaction_artifact_paths",
	]:
		if not SaveService.has_method(method_name):
			return _fail_bool("SaveService is missing transaction validation hook %s." % method_name)
	return true


func _prove_failure_phases_and_retry() -> Dictionary:
	var rows := {}
	for phase in ["precommit", "after_backup"]:
		var old_profile := _seed_empty_profile()
		if old_profile.is_empty():
			return {}
		var cache_before := _prime_unrelated_summary_cache(phase)
		if cache_before.is_empty():
			return _fail_dictionary("Could not prime the unrelated slot summary cache for %s." % phase)
		var session = CampaignRules.build_session(old_profile, SCENARIO_ID, "normal", CAMPAIGN_ID)
		if session == null or session.scenario_id != SCENARIO_ID:
			return _fail_dictionary("Could not construct the campaign completion fixture for %s." % phase)
		_stage_river_pass_victory(session)
		ScenarioRules.normalize_scenario_state(session)
		ScenarioScriptRulesScript.process_hooks(session)
		ScenarioRules.normalize_scenario_state(session)
		if session.scenario_status != "in_progress":
			return _fail_dictionary("Campaign completion fixture became terminal before the injected %s boundary." % phase)

		var session_before: Dictionary = session.to_dict()
		var profile_before: Dictionary = CampaignProgression.profile.duplicate(true)
		var file_before := _file_state(PROGRESSION_PATH)
		OS.set_environment(FAILURE_ENV, phase)
		var failed_result: Dictionary = ScenarioRules.evaluate_session(session)
		OS.unset_environment(FAILURE_ENV)

		if String(failed_result.get("status", "")) != "in_progress" \
				or "could not be saved" not in String(failed_result.get("message", "")).to_lower():
			return _fail_dictionary("Injected %s failure did not reach the completion caller as a visible retry result: %s" % [phase, JSON.stringify(failed_result)])
		if session.to_dict() != session_before:
			return _fail_dictionary("Injected %s failure did not restore the exact pre-completion session: %s" % [phase, JSON.stringify(_dictionary_difference(session_before, session.to_dict()))])
		if CampaignProgression.profile != profile_before:
			return _fail_dictionary("Injected %s failure published an uncommitted campaign profile." % phase)
		if _file_state(PROGRESSION_PATH) != file_before:
			return _fail_dictionary("Injected %s failure changed the prior progression bytes." % phase)
		if SaveService.validation_summary_cache_snapshot() != cache_before:
			return _fail_dictionary("Injected %s failure changed the primed summary cache." % phase)
		if not _artifacts_absent(PROGRESSION_PATH):
			return _fail_dictionary("Injected %s failure left progression transaction artifacts." % phase)
		if not _profile_is_empty_and_locked(CampaignProgression.profile):
			return _fail_dictionary("Injected %s failure changed attempts, carryover, or the downstream lock." % phase)

		var retry_result: Dictionary = ScenarioRules.evaluate_session(session)
		if String(retry_result.get("status", "")) != "victory" or session.scenario_status != "victory":
			return _fail_dictionary("Clearing %s and evaluating once did not complete the same live session: %s" % [phase, JSON.stringify(retry_result)])
		var committed_profile: Dictionary = CampaignProgression.profile.duplicate(true)
		var committed_record: Dictionary = CampaignRules.get_scenario_record(committed_profile, CAMPAIGN_ID, SCENARIO_ID)
		var committed_state: Dictionary = CampaignRules.get_campaign_state(committed_profile, CAMPAIGN_ID)
		var loaded_profile := CampaignRules.normalize_profile(SaveService.load_progression())
		if String(committed_record.get("status", "")) != "victory" \
				or int(committed_record.get("attempts", 0)) != 1 \
				or not CampaignRules.is_scenario_unlocked(committed_profile, CAMPAIGN_ID, NEXT_SCENARIO_ID) \
				or not committed_state.get("carryover_bundles", {}).has(SCENARIO_ID):
			return _fail_dictionary("Successful %s retry did not publish one victory attempt, carryover, and unlock." % phase)
		if loaded_profile != committed_profile or not _artifacts_absent(PROGRESSION_PATH):
			return _fail_dictionary("Successful %s retry did not persist/reload the exact live profile cleanly." % phase)

		var terminal_session_before: Dictionary = session.to_dict()
		var terminal_profile_before: Dictionary = committed_profile.duplicate(true)
		var terminal_file_before := _file_state(PROGRESSION_PATH)
		var repeat_result: Dictionary = ScenarioRules.evaluate_session(session)
		if String(repeat_result.get("status", "")) != "victory" \
				or session.to_dict() != terminal_session_before \
				or CampaignProgression.profile != terminal_profile_before \
				or _file_state(PROGRESSION_PATH) != terminal_file_before \
				or int(CampaignRules.get_scenario_record(CampaignProgression.profile, CAMPAIGN_ID, SCENARIO_ID).get("attempts", 0)) != 1:
			return _fail_dictionary("Repeated terminal evaluation after %s duplicated or changed completion." % phase)

		rows[phase] = {
			"old_bytes_exact": true,
			"cache_exact": true,
			"profile_exact": true,
			"session_exact": true,
			"locks_carryover_attempts_exact": true,
			"artifact_residue": false,
			"retry_attempts": 1,
			"retry_unlocked": true,
			"terminal_repeat_idempotent": true,
		}
	return rows


func _prove_first_defeat_control() -> Dictionary:
	var old_profile := _seed_empty_profile()
	if old_profile.is_empty():
		return {}
	var session = CampaignRules.build_session(old_profile, SCENARIO_ID, "normal", CAMPAIGN_ID)
	if session == null or session.scenario_id != SCENARIO_ID:
		return _fail_dictionary("Could not construct the first-defeat control fixture.")
	session.flags["campaign"] = "defeat"
	ScenarioRules.normalize_scenario_state(session)
	ScenarioScriptRulesScript.process_hooks(session)
	ScenarioRules.normalize_scenario_state(session)
	var result: Dictionary = ScenarioRules.evaluate_session(session)
	var profile: Dictionary = CampaignProgression.profile.duplicate(true)
	var state: Dictionary = CampaignRules.get_campaign_state(profile, CAMPAIGN_ID)
	var record: Dictionary = CampaignRules.get_scenario_record(profile, CAMPAIGN_ID, SCENARIO_ID)
	var loaded := CampaignRules.normalize_profile(SaveService.load_progression())
	if String(result.get("status", "")) != "defeat" or session.scenario_status != "defeat" \
			or String(record.get("status", "")) != "defeat" \
			or int(record.get("attempts", 0)) != 1 \
			or state.get("carryover_bundles", {}).has(SCENARIO_ID) \
			or CampaignRules.is_scenario_unlocked(profile, CAMPAIGN_ID, NEXT_SCENARIO_ID) \
			or loaded != profile \
			or not _artifacts_absent(PROGRESSION_PATH):
		return _fail_dictionary("First-defeat control changed its lock/carryover/attempt or failed persistence: %s" % JSON.stringify(result))
	return {
		"status": "defeat",
		"attempts": 1,
		"next_locked": true,
		"carryover_absent": true,
		"reload_exact": true,
	}


func _prove_skirmish_control() -> Dictionary:
	var old_profile := _seed_empty_profile()
	if old_profile.is_empty():
		return {}
	var cache_before := _prime_unrelated_summary_cache("skirmish")
	if cache_before.is_empty():
		return _fail_dictionary("Could not prime the skirmish control cache.")
	var session = ScenarioFactory.create_session(SCENARIO_ID, "normal", SessionStateStore.LAUNCH_MODE_SKIRMISH)
	if session == null or session.scenario_id != SCENARIO_ID:
		return _fail_dictionary("Could not construct the skirmish control fixture.")
	_stage_river_pass_victory(session)
	ScenarioRules.normalize_scenario_state(session)
	ScenarioScriptRulesScript.process_hooks(session)
	ScenarioRules.normalize_scenario_state(session)
	var profile_before: Dictionary = CampaignProgression.profile.duplicate(true)
	var file_before := _file_state(PROGRESSION_PATH)
	OS.set_environment(FAILURE_ENV, "after_backup")
	var result: Dictionary = ScenarioRules.evaluate_session(session)
	OS.unset_environment(FAILURE_ENV)
	if String(result.get("status", "")) != "victory" or session.scenario_status != "victory" \
			or CampaignProgression.profile != profile_before \
			or _file_state(PROGRESSION_PATH) != file_before \
			or SaveService.validation_summary_cache_snapshot() != cache_before \
			or not _profile_is_empty_and_locked(CampaignProgression.profile) \
			or not _artifacts_absent(PROGRESSION_PATH):
		return _fail_dictionary("Skirmish completion touched campaign persistence or obeyed the injected campaign-save failure: %s" % JSON.stringify(result))
	return {
		"status": "victory",
		"campaign_profile_exact": true,
		"progression_bytes_exact": true,
		"cache_exact": true,
		"next_locked": true,
	}


func _seed_empty_profile() -> Dictionary:
	_remove_paths(_progression_paths())
	OS.unset_environment(FAILURE_ENV)
	var profile := CampaignRules.normalize_profile(CampaignRules.build_profile())
	if SaveService.save_progression(profile) == "":
		_fail("Could not seed the empty campaign profile.")
		return {}
	var loaded := CampaignRules.normalize_profile(SaveService.load_progression())
	if loaded != profile:
		_fail("Seeded empty campaign profile did not reload exactly.")
		return {}
	CampaignProgression.profile = loaded.duplicate(true)
	return loaded


func _prime_unrelated_summary_cache(marker: String) -> Dictionary:
	_remove_paths(_manual_paths())
	SaveService.validation_clear_summary_cache()
	var fixture = ScenarioFactory.create_session(SCENARIO_ID, "normal", SessionStateStore.LAUNCH_MODE_SKIRMISH)
	if fixture == null or fixture.scenario_id == "":
		return {}
	fixture.day = 2
	fixture.flags["campaign_completion_cache_marker"] = marker
	var save_result: Dictionary = SaveService.save_runtime_manual_session(fixture, 1)
	if not bool(save_result.get("ok", false)):
		return {}
	var summary: Dictionary = SaveService.inspect_manual_slot(1)
	if not SaveService.can_load_summary(summary):
		return {}
	return SaveService.validation_summary_cache_snapshot()


func _stage_river_pass_victory(session) -> void:
	var towns = session.overworld.get("towns", [])
	for index in range(towns.size()):
		var town = towns[index]
		if town is Dictionary and String(town.get("placement_id", "")) == "duskfen_bastion":
			town["owner"] = "player"
			towns[index] = town
			break
	session.overworld["towns"] = towns
	session.flags["pass_cleared"] = true
	session.flags["mire_cleared"] = true
	var resolved = session.overworld.get("resolved_encounters", [])
	if not (resolved is Array):
		resolved = []
	# Stage every current authored victory requirement before testing the commit
	# boundary; this fixture is not normal-play campaign completion evidence.
	for placement in ["river_pass_ghoul_grove", "river_pass_hollow_mire", "river_pass_reed_totemists", "duskfen_counterstroke"]:
		if placement not in resolved:
			resolved.append(placement)
	session.overworld["resolved_encounters"] = resolved


func _profile_is_empty_and_locked(profile: Dictionary) -> bool:
	var state: Dictionary = CampaignRules.get_campaign_state(profile, CAMPAIGN_ID)
	return state.get("scenario_records", {}).is_empty() \
		and state.get("carryover_bundles", {}).is_empty() \
		and not CampaignRules.is_scenario_unlocked(profile, CAMPAIGN_ID, NEXT_SCENARIO_ID) \
		and int(CampaignRules.build_restart_action(profile, CAMPAIGN_ID).get("attempt_count", 0)) == 0


func _artifacts_absent(file_path: String) -> bool:
	var paths: Dictionary = SaveService.validation_transaction_artifact_paths(file_path)
	return not FileAccess.file_exists(String(paths.get("candidate", "%s.candidate" % file_path))) \
		and not FileAccess.file_exists(String(paths.get("backup", "%s.backup" % file_path)))


func _dictionary_difference(before: Dictionary, after: Dictionary) -> Dictionary:
	var difference := {}
	for key in before.keys():
		if not after.has(key) or before[key] != after[key]:
			difference[String(key)] = {"before": before[key], "after": after.get(key)}
	for key in after.keys():
		if not before.has(key):
			difference[String(key)] = {"before": null, "after": after[key]}
	return difference


func _progression_paths() -> Array:
	return [PROGRESSION_PATH, "%s.candidate" % PROGRESSION_PATH, "%s.backup" % PROGRESSION_PATH]


func _manual_paths() -> Array:
	return [MANUAL_PATH, "%s.candidate" % MANUAL_PATH, "%s.backup" % MANUAL_PATH]


func _tracked_paths() -> Array:
	return _progression_paths() + _manual_paths()


func _capture_file_states(paths: Array) -> Dictionary:
	var states := {}
	for path_value in paths:
		var path := String(path_value)
		states[path] = _file_state(path)
	return states


func _file_state(path: String) -> Dictionary:
	return {
		"exists": FileAccess.file_exists(path),
		"bytes": FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray(),
	}


func _remove_paths(paths: Array) -> void:
	for path_value in paths:
		var path := String(path_value)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _restore_file_states() -> void:
	_remove_paths(_tracked_paths())
	for path_value in _original_file_states.keys():
		var path := String(path_value)
		var state: Dictionary = _original_file_states[path]
		if not bool(state.get("exists", false)):
			continue
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_buffer(state.get("bytes", PackedByteArray()))
			file.close()


func _cleanup() -> void:
	OS.unset_environment(FAILURE_ENV)
	if _original_failure_env != "":
		OS.set_environment(FAILURE_ENV, _original_failure_env)
	_restore_file_states()
	SaveService.validation_clear_summary_cache()
	CampaignProgression.profile = _original_profile.duplicate(true)
	SessionState.active_session = _original_active_session


func _fail_bool(message: String) -> bool:
	_fail(message)
	return false


func _fail_dictionary(message: String) -> Dictionary:
	_fail(message)
	return {}


func _fail(message: String) -> void:
	_cleanup()
	push_error("%s: %s" % [REPORT_ID, message])
	get_tree().quit(1)
