extends Node

const REPORT_ID := "MAIN_MENU_LEAN_BOOT_SAVE_GUARD"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
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
	if not String(first_snapshot.get("active_expedition_full", first_snapshot.get("active_expedition", ""))).contains("open Load to inspect"):
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

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"boot_display_ms": boot_display_ms,
		"first_view_save_inspections": first_counts,
		"explicit_load_save_inspections": final_counts,
		"save_browser_items": (save_snapshot.get("save_browser_items", []) if save_snapshot.get("save_browser_items", []) is Array else []).size(),
	})])
	get_tree().quit(0)

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
