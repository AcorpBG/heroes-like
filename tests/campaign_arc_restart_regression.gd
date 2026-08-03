extends Node

const REPORT_ID := "CAMPAIGN_ARC_RESTART_REGRESSION"
const TARGET_CAMPAIGN_ID := "campaign_reedfall"
const TARGET_START_SCENARIO_ID := "river-pass"
const TARGET_ADVANCED_SCENARIO_ID := "causeway-stand"
const OTHER_CAMPAIGN_ID := "campaign_stonewake"
const OTHER_SCENARIO_ID := "stonewake-watch"
const CAPTURE_DIR := "res://.artifacts/campaign_arc_restart_regression"

var _original_profile := {}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ContentService.clear_cache()
	_original_profile = CampaignProgression.ensure_profile().duplicate(true)
	var save_bytes_before := _session_save_bytes()
	var settings_before: Dictionary = SettingsService.settings.duplicate(true)
	var settings_file_before := _file_state(SettingsService.SETTINGS_FILE)
	var seeded_profile := CampaignRules.normalize_profile(_original_profile)
	seeded_profile["campaign_states"][TARGET_CAMPAIGN_ID] = {
		"scenario_records": {
			TARGET_START_SCENARIO_ID: {
				"status": "victory",
				"summary": "Seeded completed opening chapter",
				"day": 8,
				"attempts": 2,
				"hero_level": 3,
				"known_spell_ids": ["spell_beacon_path"],
				"artifact_ids": [],
				"specialties": [],
				"exported_flags": {"pass_cleared": true},
			},
		},
		"carryover_bundles": {
			TARGET_START_SCENARIO_ID: {
				"source_scenario_id": TARGET_START_SCENARIO_ID,
				"hero_id": "hero_lyra_emberwell",
				"summary": "Seeded carryover",
				"resources": {"gold": 800, "wood": 2},
				"spell_ids": ["spell_beacon_path"],
			},
		},
		"last_selected_scenario_id": TARGET_ADVANCED_SCENARIO_ID,
		"last_completed_scenario_id": TARGET_START_SCENARIO_ID,
	}
	seeded_profile["campaign_states"][OTHER_CAMPAIGN_ID] = {
		"scenario_records": {
			OTHER_SCENARIO_ID: {
				"status": "victory",
				"summary": "Other arc must survive",
				"day": 6,
				"attempts": 1,
				"hero_level": 2,
			},
		},
		"carryover_bundles": {},
		"last_selected_scenario_id": OTHER_SCENARIO_ID,
		"last_completed_scenario_id": OTHER_SCENARIO_ID,
	}
	seeded_profile["last_campaign_id"] = TARGET_CAMPAIGN_ID
	seeded_profile["last_scenario_id"] = TARGET_ADVANCED_SCENARIO_ID
	CampaignProgression.profile = CampaignRules.normalize_profile(seeded_profile)
	CampaignProgression.save_profile()
	var preserved_other_state := CampaignRules.get_campaign_state(CampaignProgression.profile, OTHER_CAMPAIGN_ID).duplicate(true)

	var restart_action := CampaignProgression.campaign_restart_action(TARGET_CAMPAIGN_ID)
	if bool(restart_action.get("disabled", true)) or int(restart_action.get("attempt_count", 0)) != 2 or int(restart_action.get("victory_count", 0)) != 1 or int(restart_action.get("carryover_count", 0)) != 1:
		_fail("Seeded campaign progress did not expose an exact restart action: %s." % JSON.stringify(restart_action))
		return

	var shell = load("res://scenes/menus/MainMenu.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	shell.call("validation_open_campaign_stage")
	if not bool(shell.call("validation_select_campaign", TARGET_CAMPAIGN_ID)):
		_fail("Campaign board could not select the seeded target campaign.")
		return
	if not bool(shell.call("validation_set_campaign_difficulty", "hard")):
		_fail("Campaign board could not retain a non-default difficulty through restart.")
		return
	var before_snapshot: Dictionary = shell.call("validation_snapshot")
	if not bool(before_snapshot.get("campaign_restart_visible", false)) or bool(before_snapshot.get("campaign_restart_disabled", true)):
		_fail("Campaign board did not expose Restart Arc for recorded progress: %s." % JSON.stringify(before_snapshot))
		return

	var request: Dictionary = shell.call("validation_request_campaign_restart")
	if not bool(request.get("dialog_visible", false)) or String(request.get("pending_campaign_id", "")) != TARGET_CAMPAIGN_ID:
		_fail("Restart Arc did not require a campaign-bound confirmation: %s." % JSON.stringify(request))
		return
	var request_text := "%s\n%s" % [String(request.get("title", "")), String(request.get("text", ""))]
	for token in ["Lanterns Through Reedfall", "2 recorded attempts", "1 victory", "1 carryover bundle", "Expedition saves and other campaigns are preserved"]:
		if request_text.find(token) < 0:
			_fail("Restart confirmation omitted %s: %s." % [token, request_text])
			return
	if CampaignRules.get_campaign_state(CampaignProgression.profile, TARGET_CAMPAIGN_ID).get("scenario_records", {}).is_empty():
		_fail("Opening the restart confirmation mutated campaign progress before confirmation.")
		return
	await _capture("restart_confirmation")

	var confirmation: Dictionary = shell.call("validation_confirm_campaign_restart")
	if String(confirmation.get("pending_campaign_id", "")) != "" or String(confirmation.get("selected_campaign_id", "")) != TARGET_CAMPAIGN_ID:
		_fail("Confirmed restart did not return to the selected campaign: %s." % JSON.stringify(confirmation))
		return
	var after_snapshot: Dictionary = shell.call("validation_snapshot")
	if String(after_snapshot.get("selected_campaign_scenario_id", "")) != TARGET_START_SCENARIO_ID:
		_fail("Restarted campaign did not return to its authored starting chapter: %s." % JSON.stringify(after_snapshot))
		return
	if String(after_snapshot.get("selected_campaign_difficulty", "")) != "hard":
		_fail("Restarted campaign changed the selected difficulty: %s." % JSON.stringify(after_snapshot))
		return
	if bool(after_snapshot.get("campaign_restart_visible", true)) or not bool(after_snapshot.get("campaign_restart_disabled", false)):
		_fail("Restart command remained active after campaign-local progress was cleared: %s." % JSON.stringify(after_snapshot))
		return
	await _capture("restart_complete")

	var persisted := CampaignRules.normalize_profile(SaveService.load_progression())
	var target_state := CampaignRules.get_campaign_state(persisted, TARGET_CAMPAIGN_ID)
	if not target_state.get("scenario_records", {}).is_empty() or not target_state.get("carryover_bundles", {}).is_empty():
		_fail("Persisted restart retained target campaign records or carryover: %s." % JSON.stringify(target_state))
		return
	if String(target_state.get("last_selected_scenario_id", "")) != "" or String(target_state.get("last_completed_scenario_id", "")) != "":
		_fail("Persisted restart retained target campaign chapter pointers: %s." % JSON.stringify(target_state))
		return
	if CampaignRules.get_campaign_state(persisted, OTHER_CAMPAIGN_ID) != preserved_other_state:
		_fail("Restart changed another campaign state.")
		return
	if _session_save_bytes() != save_bytes_before:
		_fail("Restart changed an expedition save file.")
		return
	if SettingsService.settings != settings_before or _file_state(SettingsService.SETTINGS_FILE) != settings_file_before:
		_fail("Restart changed device settings in memory or on disk.")
		return
	if SessionState.SAVE_VERSION != 9:
		_fail("Campaign restart changed the runtime save-version contract.")
		return

	_restore_original_profile()
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"campaign_id": TARGET_CAMPAIGN_ID,
		"starting_scenario_id": TARGET_START_SCENARIO_ID,
		"attempts_cleared": 2,
		"victories_cleared": 1,
		"carryover_bundles_cleared": 1,
		"other_campaign_preserved": true,
		"expedition_save_files_preserved": save_bytes_before.size(),
		"device_settings_preserved": true,
		"difficulty_preserved": "hard",
		"save_version": SessionState.SAVE_VERSION,
	})])
	get_tree().quit(0)

func _session_save_bytes() -> Dictionary:
	var payloads := {}
	for summary_value in SaveService.list_session_summaries():
		if not (summary_value is Dictionary):
			continue
		var path := String(summary_value.get("path", ""))
		if path != "" and FileAccess.file_exists(path):
			payloads[path] = FileAccess.get_file_as_bytes(path)
	return payloads

func _file_state(path: String) -> Dictionary:
	return {
		"exists": FileAccess.file_exists(path),
		"bytes": FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray(),
	}

func _capture(stem: String) -> void:
	if OS.get_environment("CAMPAIGN_ARC_RESTART_CAPTURE") != "1":
		return
	await RenderingServer.frame_post_draw
	var absolute_dir := ProjectSettings.globalize_path(CAPTURE_DIR)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	var image := get_viewport().get_texture().get_image()
	image.save_png("%s/%s_%dx%d.png" % [absolute_dir, stem, image.get_width(), image.get_height()])

func _restore_original_profile() -> void:
	if _original_profile.is_empty():
		return
	CampaignProgression.profile = CampaignRules.normalize_profile(_original_profile)
	CampaignProgression.save_profile()

func _fail(message: String) -> void:
	_restore_original_profile()
	push_error("%s: %s" % [REPORT_ID, message])
	get_tree().quit(1)
