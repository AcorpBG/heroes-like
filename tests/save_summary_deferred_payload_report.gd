extends Node

const REPORT_ID := "SAVE_SUMMARY_DEFERRED_PAYLOAD_REPORT"
const GUARD_SCENARIO_ID := "generated_summary_deferred_guard_xl"
const GUARD_PATH := "user://saves/summary_deferred_guard.json"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://saves"))
	var write_result := _write_large_generated_save(GUARD_PATH)
	if not bool(write_result.get("ok", false)):
		_fail(String(write_result.get("message", "failed to write guard save")))
		return

	var started := Time.get_ticks_msec()
	var summary: Dictionary = SaveService.call("_inspect_slot", "manual", "summary_deferred_guard", GUARD_PATH)
	var elapsed_ms := Time.get_ticks_msec() - started
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GUARD_PATH))

	if not bool(summary.get("valid", false)) or not bool(summary.get("loadable", false)):
		_fail("Large generated save summary was not loadable: %s" % JSON.stringify(summary))
		return
	if not bool(summary.get("payload_deferred", false)):
		_fail("Large generated save summary kept the full payload inline: %s" % JSON.stringify(summary.get("payload_bytes", 0)))
		return
	var inline_payload = summary.get("payload", {})
	if not (inline_payload is Dictionary) or not inline_payload.is_empty():
		_fail("Deferred summary should not retain an inline payload.")
		return
	if ContentService.has_generated_scenario_draft(GUARD_SCENARIO_ID):
		_fail("Summary inspection regenerated and registered a transient generated scenario.")
		return
	if String(summary.get("resume_target", "")) != "outcome":
		_fail("Summary did not derive outcome resume target from payload metadata: %s" % JSON.stringify(summary))
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"elapsed_ms": elapsed_ms,
		"payload_bytes": int(summary.get("payload_bytes", 0)),
		"payload_deferred": bool(summary.get("payload_deferred", false)),
		"resume_target": String(summary.get("resume_target", "")),
	})])
	get_tree().quit(0)

func _write_large_generated_save(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "message": "Could not open %s for writing." % path}
	file.store_string(
		("{\"save_version\":%d,\"session_id\":\"summary-deferred-guard\",\"scenario_id\":\"%s\","
		+ "\"hero_id\":\"hero_mira\",\"day\":12,\"difficulty\":\"normal\",\"launch_mode\":\"%s\","
		+ "\"game_state\":\"outcome\",\"scenario_status\":\"victory\","
		+ "\"scenario_summary\":\"Generated guard save completed.\","
		+ "\"overworld\":{\"resources\":{\"gold\":1,\"wood\":1,\"ore\":1},\"map\":[[\"grass\"]],"
		+ "\"map_size\":{\"width\":1,\"height\":1},\"hero_position\":{\"x\":0,\"y\":0},"
		+ "\"hero\":{\"id\":\"hero_mira\",\"name\":\"Mira\",\"position\":{\"x\":0,\"y\":0}},"
		+ "\"towns\":[],\"resource_nodes\":[],\"artifact_nodes\":[],\"encounters\":[],"
		+ "\"resolved_encounters\":[],\"summary_padding\":\"")
		% [SessionState.SAVE_VERSION, GUARD_SCENARIO_ID, SessionState.LAUNCH_MODE_SKIRMISH]
	)
	var chunk := "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
	for _index in range(96 * 1024):
		file.store_string(chunk)
	file.store_string(
		"\"},\"battle\":{},\"flags\":{\"generated_random_map\":true,"
		+ "\"generated_random_map_provenance\":{\"generator_config\":{\"seed\":\"summary-deferred-guard\"},"
		+ "\"generated_identity\":{\"stable_signature\":\"not-regenerated-during-summary\"}}}}"
	)
	file.close()
	return {"ok": true}

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GUARD_PATH))
	get_tree().quit(1)
