extends Node

const REPORT_ID := "UI_AUDIO_CUE_RUNTIME_REPORT"
const OUTPUT_DIR := "res://.artifacts/ui_audio_cue_runtime_report"

var _errors: Array[String] = []
var _report := {
	"ok": false,
	"summary": {},
	"records": [],
	"errors": [],
}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	UiAudio.validation_reset()
	_exercise_controls()
	await get_tree().process_frame
	_validate_summary()
	_report["ok"] = _errors.is_empty()
	_report["errors"] = _errors.duplicate()
	_write_json("%s/report.json" % OUTPUT_DIR, _report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify(_summary_payload())])
	UiAudio.validation_reset()
	await get_tree().process_frame
	get_tree().quit(0 if _errors.is_empty() else 1)

func _exercise_controls() -> void:
	var root := Control.new()
	root.name = "UiAudioFixture"
	add_child(root)

	var button := Button.new()
	button.name = "CueButton"
	root.add_child(button)
	UiAudio.attach_control(button)
	button.pressed.emit()

	var option := OptionButton.new()
	option.name = "CueOption"
	option.add_item("One")
	root.add_child(option)
	UiAudio.attach_control(option)
	option.item_selected.emit(0)

	var slider := HSlider.new()
	slider.name = "CueSlider"
	root.add_child(slider)
	UiAudio.attach_control(slider)
	slider.value_changed.emit(64.0)

	var tabs := TabContainer.new()
	tabs.name = "CueTabs"
	var first := Control.new()
	first.name = "First"
	var second := Control.new()
	second.name = "Second"
	tabs.add_child(first)
	tabs.add_child(second)
	root.add_child(tabs)
	UiAudio.attach_control(tabs)
	tabs.tab_changed.emit(1)

	var list := ItemList.new()
	list.name = "CueList"
	list.add_item("Choice")
	root.add_child(list)
	UiAudio.attach_control(list)
	list.item_selected.emit(0)

	UiAudio.play_confirm("validation_confirm", {"fixture": "ui_audio_cue_runtime"})
	UiAudio.play_invalid("validation_invalid", {"fixture": "ui_audio_cue_runtime"})

func _validate_summary() -> void:
	var summary := UiAudio.validation_summary()
	var records: Array = summary.get("records", []) if summary.get("records", []) is Array else []
	_report["summary"] = summary
	_report["records"] = records
	_expect_equal("schema", String(summary.get("schema", "")), "ui_audio_runtime_v1")
	_expect(int(summary.get("record_count", 0)) >= 7, "Expected at least seven UI audio records.")
	_expect(String(summary.get("audio_bus", "")) == "Master", "UI audio must route through the Master bus.")
	_expect(int(summary.get("max_active_players", 0)) == UiAudio.MAX_ACTIVE_PLAYERS, "UI audio summary must expose max active player cap.")
	_expect(String(summary.get("sfx_manifest_path", "")) == "res://content/ui_sfx_manifest.json", "UI audio summary must expose the UI SFX manifest path.")
	_expect(bool(summary.get("sfx_manifest_loaded", false)), "UI audio runtime should load the UI SFX manifest.")
	var counts: Dictionary = summary.get("cue_counts", {}) if summary.get("cue_counts", {}) is Dictionary else {}
	for cue_id in ["ui_click", "ui_select", "ui_adjust", "ui_tab", "ui_confirm", "ui_invalid"]:
		_expect(int(counts.get(cue_id, 0)) >= 1, "Missing expected UI audio cue %s in %s." % [cue_id, counts])
	_expect(int(counts.get("ui_select", 0)) >= 2, "Expected both option and item-list select cues in %s." % counts)
	for record in records:
		var entry: Dictionary = record
		_expect(String(entry.get("audio_bus", "")) == "Master", "UI audio record must route through Master: %s" % entry)
		_expect(float(entry.get("duration_sec", 0.0)) > 0.0, "UI audio record must include positive duration: %s" % entry)
		_expect(float(entry.get("frequency", 0.0)) > 0.0, "UI audio record must include positive frequency: %s" % entry)
		_expect(entry.has("played"), "UI audio record must expose played/muted state: %s" % entry)
		_expect(String(entry.get("playback_source", "")) == "imported_wav", "UI audio record should prefer imported runtime SFX assets: %s" % entry)
		_expect(String(entry.get("asset_path", "")).begins_with("res://art/audio/runtime/ui/"), "UI audio record must expose runtime UI SFX asset path: %s" % entry)
		_expect(int(entry.get("imported_asset_count", 0)) == 1, "UI audio record should count the imported asset playback: %s" % entry)
		_expect(int(entry.get("generated_fallback_count", 0)) == 0, "UI audio record should not use generated fallback when the asset is present: %s" % entry)

func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.WRITE)
	if file == null:
		_error("Failed to write %s." % path)
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()

func _summary_payload() -> Dictionary:
	var summary: Dictionary = _report.get("summary", {}) if _report.get("summary", {}) is Dictionary else {}
	return {
		"ok": bool(_report.get("ok", false)),
		"record_count": int(summary.get("record_count", 0)),
		"cue_counts": summary.get("cue_counts", {}),
		"audio_bus": String(summary.get("audio_bus", "")),
		"sfx_manifest_loaded": bool(summary.get("sfx_manifest_loaded", false)),
	}

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_error(message)

func _expect_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		_error("%s expected %s, got %s." % [label, expected, actual])

func _error(message: String) -> void:
	_errors.append(message)
	push_error(message)
