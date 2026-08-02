extends Node

const REPORT_ID := "OVERWORLD_AMBIENT_AUDIO_RUNTIME_REPORT"
const OUTPUT_DIR := "res://.artifacts/overworld_ambient_audio_runtime_report"
const EXPECTED_PRESSURE_CUE := "overworld_ambient_pressure"
const EXPECTED_DAY_PULSE_CUE := "overworld_ambient_day_pulse"

var _errors: Array[String] = []
var _report := {
	"ok": false,
	"summary": {},
	"records": [],
	"shell_summary": {},
	"errors": [],
}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	AmbientAudio.validation_reset()
	var session = ScenarioFactory.create_session(
		"river-pass",
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	OverworldRules.normalize_overworld_state(session)
	_set_enemy_pressure(session, "faction_mireclaw", 0)
	var calm_record: Dictionary = AmbientAudio.sync_overworld_session(session, "validation_calm")
	var stable_record: Dictionary = AmbientAudio.sync_overworld_session(session, "validation_stable_repeat")
	_set_enemy_pressure(session, "faction_mireclaw", 6)
	var pressure_record: Dictionary = AmbientAudio.sync_overworld_session(session, "validation_pressure")
	session.day = 2
	var day_record: Dictionary = AmbientAudio.sync_overworld_session(session, "validation_day_pulse")
	var direct_summary := AmbientAudio.validation_summary()
	AmbientAudio.validation_reset()
	var original_effects_volume := SettingsService.effects_volume_percent()
	SettingsService.settings["audio"]["effects_volume_percent"] = 0
	SettingsService.apply_settings()
	var muted_record: Dictionary = AmbientAudio.sync_overworld_session(session, "validation_effects_muted")
	SettingsService.settings["audio"]["effects_volume_percent"] = original_effects_volume
	SettingsService.apply_settings()
	AmbientAudio.validation_reset()
	_report["muted_record"] = muted_record
	_expect(bool(muted_record.get("muted", false)) and not bool(muted_record.get("played", true)), "Zero Effects volume must mute ambient playback: %s" % muted_record)

	SessionState.set_active_session(session)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	var shell_summary: Dictionary = shell.call("validation_ambient_audio_summary")
	var shell_snapshot: Dictionary = shell.call("validation_snapshot")

	_report["summary"] = direct_summary
	_report["records"] = direct_summary.get("records", [])
	_report["shell_summary"] = shell_summary
	_validate_record("calm", calm_record, true, "calm")
	_validate_record("stable", stable_record, false, "calm")
	_validate_record("pressure", pressure_record, true, "medium")
	_validate_record("day", day_record, true, "medium")
	_validate_direct_summary(direct_summary)
	_validate_shell_summary(shell_summary, shell_snapshot)
	_report["ok"] = _errors.is_empty()
	_report["errors"] = _errors.duplicate()
	_write_json("%s/report.json" % OUTPUT_DIR, _report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify(_summary_payload())])
	AmbientAudio.validation_reset()
	await get_tree().process_frame
	get_tree().quit(0 if _errors.is_empty() else 1)

func _validate_record(label: String, record: Dictionary, expected_changed: bool, expected_threat: String) -> void:
	_expect_equal("%s schema" % label, String(record.get("schema", "")), "overworld_ambient_audio_runtime_v1")
	_expect_equal("%s cue" % label, String(record.get("cue_id", "")), "overworld_ambient_mix")
	_expect_equal("%s changed" % label, bool(record.get("changed", false)), expected_changed)
	_expect_equal("%s threat" % label, String(record.get("threat_level", "")), expected_threat)
	_expect(String(record.get("terrain_id", "")) != "", "%s record must expose terrain id: %s" % [label, record])
	_expect(int(record.get("layer_count", 0)) >= 1, "%s record must expose at least one ambient layer: %s" % [label, record])
	_expect(String(record.get("audio_bus", "")) == "Effects", "%s record must route through Effects: %s" % [label, record])
	_expect(String(record.get("sfx_manifest_path", "")) == "res://content/ambient_sfx_manifest.json", "%s record must expose ambient SFX manifest path: %s" % [label, record])
	_expect(bool(record.get("sfx_manifest_loaded", false)), "%s record must load ambient SFX manifest: %s" % [label, record])
	for layer in record.get("layers", []):
		var layer_record: Dictionary = layer
		_expect(String(layer_record.get("cue_id", "")).begins_with("overworld_ambient_"), "%s layer has unexpected cue id: %s" % [label, layer_record])
		_expect(float(layer_record.get("duration_sec", 0.0)) > 0.0, "%s layer must expose duration: %s" % [label, layer_record])
		_expect(float(layer_record.get("frequency", 0.0)) > 0.0, "%s layer must expose frequency: %s" % [label, layer_record])
		_expect(String(layer_record.get("playback_source", "")) == "imported_wav", "%s layer should prefer imported ambient WAV assets: %s" % [label, layer_record])
		_expect(String(layer_record.get("asset_path", "")).begins_with("res://art/audio/runtime/ambient/"), "%s layer must expose ambient asset path: %s" % [label, layer_record])
		_expect(int(layer_record.get("imported_asset_count", 0)) == 1, "%s layer should count imported asset playback: %s" % [label, layer_record])
		_expect(int(layer_record.get("generated_fallback_count", 0)) == 0, "%s layer should not use generated fallback when asset is present: %s" % [label, layer_record])

func _validate_direct_summary(summary: Dictionary) -> void:
	_expect_equal("direct schema", String(summary.get("schema", "")), "overworld_ambient_audio_runtime_v1")
	_expect(int(summary.get("record_count", 0)) >= 3, "Ambient direct summary must keep changed records: %s" % summary)
	_expect(String(summary.get("audio_bus", "")) == "Effects", "Ambient direct summary must route through Effects: %s" % summary)
	_expect(String(summary.get("sfx_manifest_path", "")) == "res://content/ambient_sfx_manifest.json", "Ambient direct summary must expose the ambient SFX manifest path: %s" % summary)
	_expect(bool(summary.get("sfx_manifest_loaded", false)), "Ambient direct summary must load the ambient SFX manifest: %s" % summary)
	_expect(int(summary.get("max_active_players", 0)) == AmbientAudio.MAX_ACTIVE_PLAYERS, "Ambient direct summary must expose player cap: %s" % summary)
	_expect(int(summary.get("pressure_layer_count", 0)) >= 1, "Ambient direct summary must include pressure layer evidence: %s" % summary)
	var current_layers: Array = summary.get("current_layers", []) if summary.get("current_layers", []) is Array else []
	_expect(current_layers.size() >= 2, "Ambient direct summary must keep current terrain and pressure/day layers: %s" % summary)
	_expect(_layer_cue_present(current_layers, EXPECTED_PRESSURE_CUE), "Ambient direct summary must keep pressure cue %s: %s" % [EXPECTED_PRESSURE_CUE, current_layers])
	_expect(_layer_cue_present(current_layers, EXPECTED_DAY_PULSE_CUE), "Ambient direct summary must keep day pulse cue %s: %s" % [EXPECTED_DAY_PULSE_CUE, current_layers])

func _validate_shell_summary(summary: Dictionary, snapshot: Dictionary) -> void:
	_expect_equal("shell schema", String(summary.get("schema", "")), "overworld_ambient_audio_runtime_v1")
	_expect(int(summary.get("record_count", 0)) >= 1, "OverworldShell must sync AmbientAudio at runtime: %s" % summary)
	_expect(String(summary.get("audio_bus", "")) == "Effects", "Shell ambient summary must route through Effects: %s" % summary)
	var snapshot_summary: Dictionary = snapshot.get("ambient_audio", {}) if snapshot.get("ambient_audio", {}) is Dictionary else {}
	_expect_equal("snapshot ambient schema", String(snapshot_summary.get("schema", "")), "overworld_ambient_audio_runtime_v1")
	_expect(int(snapshot_summary.get("record_count", 0)) >= 1, "Overworld validation snapshot must expose ambient audio summary: %s" % snapshot_summary)

func _set_enemy_pressure(session, faction_id: String, pressure: int) -> void:
	var states: Array = session.overworld.get("enemy_states", []) if session.overworld.get("enemy_states", []) is Array else []
	for index in range(states.size()):
		var state = states[index]
		if state is Dictionary and String(state.get("faction_id", "")) == faction_id:
			state["pressure"] = pressure
			states[index] = state
	session.overworld["enemy_states"] = states

func _layer_cue_present(layers: Array, cue_id: String) -> bool:
	for layer in layers:
		if layer is Dictionary and String(layer.get("cue_id", "")) == cue_id:
			return true
	return false

func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.WRITE)
	if file == null:
		_error("Failed to write %s." % path)
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()

func _summary_payload() -> Dictionary:
	var summary: Dictionary = _report.get("summary", {}) if _report.get("summary", {}) is Dictionary else {}
	var shell_summary: Dictionary = _report.get("shell_summary", {}) if _report.get("shell_summary", {}) is Dictionary else {}
	return {
		"ok": bool(_report.get("ok", false)),
		"record_count": int(summary.get("record_count", 0)),
		"pressure_layer_count": int(summary.get("pressure_layer_count", 0)),
		"shell_record_count": int(shell_summary.get("record_count", 0)),
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
