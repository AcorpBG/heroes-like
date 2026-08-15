extends Node

const REPORT_ID := "UI_AUDIO_CUE_RUNTIME_REPORT"
const OUTPUT_DIR := "res://.artifacts/ui_audio_cue_runtime_report"
const EXPECTED_CUES := {
	"ui_click": {"path": "res://art/audio/runtime/ui/click.wav", "duration_msec": 70, "volume_db": -18.0, "role": "button_click"},
	"ui_select": {"path": "res://art/audio/runtime/ui/select.wav", "duration_msec": 80, "volume_db": -18.0, "role": "list_select"},
	"ui_adjust": {"path": "res://art/audio/runtime/ui/adjust.wav", "duration_msec": 60, "volume_db": -20.0, "role": "slider_adjust"},
	"ui_tab": {"path": "res://art/audio/runtime/ui/tab.wav", "duration_msec": 90, "volume_db": -18.5, "role": "tab_change"},
	"ui_confirm": {"path": "res://art/audio/runtime/ui/confirm.wav", "duration_msec": 120, "volume_db": -17.0, "role": "confirm_action"},
	"ui_invalid": {"path": "res://art/audio/runtime/ui/invalid.wav", "duration_msec": 150, "volume_db": -17.5, "role": "invalid_action"},
}

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
	var settings_authority_before: Dictionary = SettingsService.settings.duplicate(true)
	var original_reduced_repetition := SettingsService.reduced_repetitive_sounds_enabled()
	SettingsService.settings["accessibility"]["reduce_repetitive_sounds"] = false
	SettingsService.apply_settings()
	UiAudio.validation_reset()
	_exercise_controls()
	await get_tree().process_frame
	_validate_summary()
	_validate_generated_fallback()
	_validate_reduced_repetition()
	var original_effects_volume := SettingsService.effects_volume_percent()
	SettingsService.settings["audio"]["effects_volume_percent"] = 0
	SettingsService.apply_settings()
	var muted_record := UiAudio.play_confirm("validation_effects_muted", {"fixture": "ui_audio_cue_runtime"})
	SettingsService.settings["audio"]["effects_volume_percent"] = original_effects_volume
	SettingsService.settings["accessibility"]["reduce_repetitive_sounds"] = original_reduced_repetition
	SettingsService.apply_settings()
	_expect(SettingsService.settings == settings_authority_before, "UI audio validation must restore exact SettingsService authority.")
	_report["settings_authority_exact"] = SettingsService.settings == settings_authority_before
	_report["muted_record"] = muted_record
	_expect(bool(muted_record.get("muted", false)) and not bool(muted_record.get("played", true)), "Zero Effects volume must mute UI cue playback: %s" % muted_record)
	await get_tree().process_frame
	_report["ok"] = _errors.is_empty()
	_report["errors"] = _errors.duplicate()
	_write_json("%s/report.json" % OUTPUT_DIR, _report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify(_summary_payload())])
	UiAudio.validation_reset()
	await get_tree().process_frame
	get_tree().quit(0 if _errors.is_empty() else 1)

func _validate_generated_fallback() -> void:
	var original_manifest: Dictionary = UiAudio._ui_sfx_manifest.duplicate(true)
	var original_loaded: bool = UiAudio._ui_sfx_manifest_loaded
	UiAudio.validation_reset()
	UiAudio._ui_sfx_manifest = {}
	UiAudio._ui_sfx_manifest_loaded = true
	var fallback_record := UiAudio.play_invalid("validation_generated_fallback", {"fixture": "ui_audio_production_sfx"})
	_expect(bool(fallback_record.get("played", false)), "Missing imported UI assets must retain generated waveform playback: %s" % fallback_record)
	_expect(String(fallback_record.get("playback_source", "")) == "generated_waveform", "Missing imported UI assets must use the generated waveform fallback: %s" % fallback_record)
	_expect(int(fallback_record.get("generated_fallback_count", 0)) == 1 and int(fallback_record.get("imported_asset_count", -1)) == 0, "Generated UI fallback counts must remain exact: %s" % fallback_record)
	UiAudio.validation_reset()
	UiAudio._ui_sfx_manifest = original_manifest
	UiAudio._ui_sfx_manifest_loaded = original_loaded
	_report["generated_fallback"] = fallback_record

func _validate_reduced_repetition() -> void:
	UiAudio.validation_reset()
	SettingsService.settings["accessibility"]["reduce_repetitive_sounds"] = true
	SettingsService.apply_settings()
	var first_click := UiAudio.play_cue("ui_click", "reduced_first")
	var repeated_click := UiAudio.play_cue("ui_click", "reduced_repeat")
	UiAudio.play_cue("ui_select", "reduced_select")
	UiAudio.play_cue("ui_adjust", "reduced_adjust")
	UiAudio.play_cue("ui_tab", "reduced_tab")
	var replacement := UiAudio.play_confirm("reduced_confirm")
	var summary := UiAudio.validation_summary()
	_expect(bool(first_click.get("played", false)), "Reduced repetition must allow the first UI cue: %s" % first_click)
	_expect(not bool(repeated_click.get("played", true)) and String(repeated_click.get("suppressed_reason", "")) == "repeat_cooldown", "Reduced repetition must suppress an immediate duplicate before player creation: %s" % repeated_click)
	_expect(not bool(repeated_click.get("player_created", true)), "Suppressed UI duplicates must create no player: %s" % repeated_click)
	_expect(bool(replacement.get("played", false)), "Reduced repetition must keep distinct confirmation cues audible: %s" % replacement)
	_expect(int(summary.get("effective_voice_budget", 0)) == UiAudio.REDUCED_REPETITION_MAX_ACTIVE_PLAYERS, "Reduced repetition must expose the four-player UI budget: %s" % summary)
	_expect(int(summary.get("active_player_count", 0)) == UiAudio.REDUCED_REPETITION_MAX_ACTIVE_PLAYERS, "Reduced repetition must hold the live UI voice count at four: %s" % summary)
	_report["reduced_repetition"] = {
		"first_click": first_click,
		"repeated_click": repeated_click,
		"replacement": replacement,
		"summary": summary,
	}
	UiAudio.validation_reset()

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
	_expect(String(summary.get("audio_bus", "")) == "Effects", "UI audio must route through the Effects bus.")
	_expect(int(summary.get("max_active_players", 0)) == UiAudio.MAX_ACTIVE_PLAYERS, "UI audio summary must expose max active player cap.")
	_expect(String(summary.get("sfx_manifest_path", "")) == "res://content/ui_sfx_manifest.json", "UI audio summary must expose the UI SFX manifest path.")
	_expect(bool(summary.get("sfx_manifest_loaded", false)), "UI audio runtime should load the UI SFX manifest.")
	var counts: Dictionary = summary.get("cue_counts", {}) if summary.get("cue_counts", {}) is Dictionary else {}
	for cue_id in ["ui_click", "ui_select", "ui_adjust", "ui_tab", "ui_confirm", "ui_invalid"]:
		_expect(int(counts.get(cue_id, 0)) >= 1, "Missing expected UI audio cue %s in %s." % [cue_id, counts])
	_expect(int(counts.get("ui_select", 0)) >= 2, "Expected both option and item-list select cues in %s." % counts)
	var imported_cue_ids := {}
	var route_sources := {
		"CueButton": "ui_click",
		"CueOption": "ui_select",
		"CueSlider": "ui_adjust",
		"CueTabs": "ui_tab",
		"CueList": "ui_select",
	}
	var routed_sources_seen := {}
	for record in records:
		var entry: Dictionary = record
		_expect(String(entry.get("audio_bus", "")) == "Effects", "UI audio record must route through Effects: %s" % entry)
		_expect(float(entry.get("duration_sec", 0.0)) > 0.0, "UI audio record must include positive duration: %s" % entry)
		_expect(float(entry.get("frequency", 0.0)) > 0.0, "UI audio record must include positive frequency: %s" % entry)
		_expect(entry.has("played"), "UI audio record must expose played/muted state: %s" % entry)
		if bool(entry.get("muted", false)):
			_expect(not bool(entry.get("played", true)), "Muted UI audio records must not report playback: %s" % entry)
			continue
		_expect(String(entry.get("playback_source", "")) == "imported_wav", "UI audio record should prefer imported runtime SFX assets: %s" % entry)
		_expect(String(entry.get("asset_path", "")).begins_with("res://art/audio/runtime/ui/"), "UI audio record must expose runtime UI SFX asset path: %s" % entry)
		_expect(int(entry.get("imported_asset_count", 0)) == 1, "UI audio record should count the imported asset playback: %s" % entry)
		_expect(int(entry.get("generated_fallback_count", 0)) == 0, "UI audio record should not use generated fallback when the asset is present: %s" % entry)
		var cue_id := String(entry.get("cue_id", ""))
		var expected: Dictionary = EXPECTED_CUES.get(cue_id, {}) if EXPECTED_CUES.get(cue_id, {}) is Dictionary else {}
		_expect(not expected.is_empty(), "Imported UI audio record must use one exact production cue id: %s" % entry)
		if not expected.is_empty():
			imported_cue_ids[cue_id] = true
			_expect(String(entry.get("asset_path", "")) == String(expected.get("path", "")), "UI cue %s must use its exact imported path: %s" % [cue_id, entry])
			_expect(String(entry.get("role", "")) == String(expected.get("role", "")), "UI cue %s must preserve its exact role: %s" % [cue_id, entry])
			_expect(int(entry.get("duration_msec", 0)) == int(expected.get("duration_msec", 0)), "UI cue %s must preserve its exact duration: %s" % [cue_id, entry])
			_expect(is_equal_approx(float(entry.get("volume_db", 0.0)), float(expected.get("volume_db", 0.0))), "UI cue %s must preserve its exact volume: %s" % [cue_id, entry])
			_expect(int(entry.get("stream_mix_rate", 0)) == 44100, "UI cue %s must load at 44.1 kHz: %s" % [cue_id, entry])
			_expect(bool(entry.get("stream_stereo", false)), "UI cue %s must load as stereo: %s" % [cue_id, entry])
			_expect(int(entry.get("stream_format", -1)) == AudioStreamWAV.FORMAT_QOA, "UI cue %s must use Godot's imported QOA runtime format: %s" % [cue_id, entry])
			_expect(int(entry.get("stream_loop_mode", -1)) == AudioStreamWAV.LOOP_DISABLED, "UI cue %s must remain a non-looping transient: %s" % [cue_id, entry])
			var expected_length := float(expected.get("duration_msec", 0)) / 1000.0
			_expect(absf(float(entry.get("stream_length_sec", 0.0)) - expected_length) <= (1.0 / 44100.0), "UI cue %s stream length must match its authored duration: %s" % [cue_id, entry])
		var source := String(entry.get("source", ""))
		for control_name in route_sources:
			if source.ends_with(String(control_name)):
				routed_sources_seen[control_name] = cue_id
				_expect(cue_id == String(route_sources[control_name]), "Control %s must retain exact UI cue route %s: %s" % [control_name, route_sources[control_name], entry])
	_expect(imported_cue_ids.size() == EXPECTED_CUES.size(), "Focused UI audio must exercise all six production cue identities: %s" % imported_cue_ids)
	_expect(routed_sources_seen.size() == route_sources.size(), "Focused UI audio must exercise all five real control-family routes: %s" % routed_sources_seen)
	_report["production_asset_contract"] = {
		"cue_ids": imported_cue_ids.keys(),
		"route_sources": routed_sources_seen,
		"sample_rate_hz": 44100,
		"channel_count": 2,
		"sample_width_bits": 16,
	}

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
		"production_asset_contract": _report.get("production_asset_contract", {}),
		"generated_fallback": _report.get("generated_fallback", {}),
		"settings_authority_exact": bool(_report.get("settings_authority_exact", false)),
		"reduced_repetition": _report.get("reduced_repetition", {}),
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
