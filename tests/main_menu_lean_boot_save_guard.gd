extends Node

const REPORT_ID := "MAIN_MENU_LEAN_BOOT_SAVE_GUARD"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var tree := get_tree()
	SessionState.reset_session()
	SaveService.validation_begin_summary_inspection_trace()
	var started_ms := Time.get_ticks_msec()
	var shell = load("res://scenes/menus/MainMenu.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	var first_snapshot: Dictionary = shell.call("validation_snapshot")
	var boot_display_ms := Time.get_ticks_msec() - started_ms
	var first_counts := SaveService.validation_summary_inspection_trace_snapshot()
	if _save_inspection_count(first_counts) != 0:
		_fail("First-view boot touched save summaries: %s" % JSON.stringify(first_counts))
		return
	if bool(first_snapshot.get("save_browser_loaded", true)):
		_fail("First-view boot marked the hidden save browser loaded.")
		return
	if bool(first_snapshot.get("campaign_browser_loaded", true)) or bool(first_snapshot.get("skirmish_browser_loaded", true)):
		_fail("First-view boot materialized a hidden Campaign or Skirmish browser: %s" % JSON.stringify(first_snapshot))
		return
	if int(first_snapshot.get("campaign_count", -1)) != 0 or int(first_snapshot.get("skirmish_count", -1)) != 0:
		_fail("First-view hidden browser rows were not deferred: %s" % JSON.stringify(first_snapshot))
		return
	if String(first_snapshot.get("campaign_board_status", "")) != "deferred":
		_fail("First-view Campaign board did not expose the deferred state.")
		return
	if boot_display_ms > 15000:
		_fail("First-view Main Menu display exceeded 15000 ms: %d" % boot_display_ms)
		return
	if not String(first_snapshot.get("active_expedition_full", first_snapshot.get("active_expedition", ""))).contains("Load: choose a saved expedition"):
		_fail("First-view footer did not use cheap Load inspection copy: %s" % String(first_snapshot.get("active_expedition_full", "")))
		return
	if String(first_snapshot.get("save_pulse_full", first_snapshot.get("save_pulse", ""))).contains("Latest save"):
		_fail("First-view save pulse still advertises a scanned latest save.")
		return

	shell.call("validation_open_saves_stage")
	await get_tree().process_frame
	var save_snapshot: Dictionary = shell.call("validation_snapshot")
	var final_counts := SaveService.validation_end_summary_inspection_trace()
	if _save_inspection_count(final_counts) <= 0:
		_fail("Explicit Saves/Load opening did not inspect save summaries: %s" % JSON.stringify(final_counts))
		return
	if not bool(save_snapshot.get("save_browser_loaded", false)):
		_fail("Saves/Load stage did not mark save browser loaded.")
		return
	if (save_snapshot.get("save_browser_items", []) if save_snapshot.get("save_browser_items", []) is Array else []).is_empty():
		_fail("Saves/Load stage did not populate save browser rows.")
		return
	if bool(save_snapshot.get("campaign_browser_loaded", true)) or bool(save_snapshot.get("skirmish_browser_loaded", true)):
		_fail("Opening Saves unexpectedly materialized Campaign or Skirmish.")
		return

	shell.call("validation_open_campaign_stage")
	await get_tree().process_frame
	var campaign_snapshot: Dictionary = shell.call("validation_snapshot")
	if not bool(campaign_snapshot.get("campaign_browser_loaded", false)) or bool(campaign_snapshot.get("skirmish_browser_loaded", true)):
		_fail("Campaign public stage did not load only the Campaign browser.")
		return
	if int(campaign_snapshot.get("campaign_count", 0)) <= 0 or String(campaign_snapshot.get("campaign_board_status", "")) != "active":
		_fail("Campaign public stage did not populate the active Campaign browser.")
		return

	shell.call("validation_open_skirmish_stage")
	await get_tree().process_frame
	var skirmish_snapshot: Dictionary = shell.call("validation_snapshot")
	if not bool(skirmish_snapshot.get("campaign_browser_loaded", false)) or not bool(skirmish_snapshot.get("skirmish_browser_loaded", false)):
		_fail("Skirmish public stage did not retain Campaign and load Skirmish.")
		return
	if int(skirmish_snapshot.get("campaign_count", 0)) <= 0 or int(skirmish_snapshot.get("skirmish_count", 0)) <= 0:
		_fail("Public secondary-stage browsers did not preserve populated rows.")
		return
	if not bool(shell.call("validation_select_first_maps_folder_skirmish")):
		_fail("Skirmish board did not expose a current maps-folder package entry.")
		return
	var package_snapshot: Dictionary = shell.call("validation_snapshot")
	var package_setup: Dictionary = package_snapshot.get("selected_skirmish_setup", {}) if package_snapshot.get("selected_skirmish_setup", {}) is Dictionary else {}
	if String(package_setup.get("startup_source", "")) != "maps_folder_package":
		_fail("Selected maps-folder package did not retain its entry-owned setup.")
		return
	var package_launch_started := Time.get_ticks_msec()
	var package_launch: Dictionary = shell.call("validation_start_selected_skirmish")
	var package_launch_ms := Time.get_ticks_msec() - package_launch_started
	if not bool(package_launch.get("started", false)) or package_launch_ms > 30000:
		_fail("Selected maps-folder package launch was not exact and bounded: %s in %d ms" % [JSON.stringify(package_launch), package_launch_ms])
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"boot_display_ms": boot_display_ms,
		"first_view_save_inspections": first_counts,
		"explicit_load_save_inspections": final_counts,
		"save_browser_items": (save_snapshot.get("save_browser_items", []) if save_snapshot.get("save_browser_items", []) is Array else []).size(),
		"campaign_items": int(campaign_snapshot.get("campaign_count", 0)),
		"skirmish_items": int(skirmish_snapshot.get("skirmish_count", 0)),
		"first_view_campaign_deferred": not bool(first_snapshot.get("campaign_browser_loaded", true)),
		"first_view_skirmish_deferred": not bool(first_snapshot.get("skirmish_browser_loaded", true)),
		"selected_package_setup_entry_owned": true,
		"selected_package_launch_ms": package_launch_ms,
	})])
	tree.quit(0)

func _save_inspection_count(counts: Dictionary) -> int:
	return (
		int(counts.get("inspect_manual_slot", 0))
		+ int(counts.get("inspect_autosave", 0))
		+ int(counts.get("list_session_summaries", 0))
		+ int(counts.get("latest_loadable_summary", 0))
		+ int(counts.get("slot_file_inspections", 0))
	)

func _fail(message: String) -> void:
	SaveService.validation_end_summary_inspection_trace()
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
