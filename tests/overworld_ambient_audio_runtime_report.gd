extends Node

const REPORT_ID := "OVERWORLD_AMBIENT_AUDIO_RUNTIME_REPORT"
const OUTPUT_DIR := "res://.artifacts/overworld_ambient_audio_runtime_report"
const EXPECTED_PRESSURE_CUE := "overworld_ambient_pressure"
const EXPECTED_DAY_PULSE_CUE := "overworld_ambient_day_pulse"
const EXPECTED_SEGMENT_DURATION_SEC := 12.0
const EXPECTED_SEGMENT_FRAMES := 529200
const EXPECTED_TERRAIN_IDS := [
	"grass",
	"water",
	"mire",
	"dirt",
	"rough",
	"sand",
	"snow",
	"lava",
	"underground",
]
const EXPECTED_AMBIENT_CUES := [
	"overworld_ambient_grass",
	"overworld_ambient_water",
	"overworld_ambient_mire",
	"overworld_ambient_dirt",
	"overworld_ambient_rough",
	"overworld_ambient_sand",
	"overworld_ambient_snow",
	"overworld_ambient_lava",
	"overworld_ambient_underground",
	EXPECTED_PRESSURE_CUE,
	EXPECTED_DAY_PULSE_CUE,
]

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
	_validate_manifest_asset_surface()
	AmbientAudio.validation_reset()
	var session = ScenarioFactory.create_session(
		"river-pass",
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	OverworldRules.normalize_overworld_state(session)
	session.day = 1
	_set_enemy_pressure(session, "faction_mireclaw", 0)
	var terrain_records := {}
	for terrain_id_value in EXPECTED_TERRAIN_IDS:
		var terrain_id := String(terrain_id_value)
		_set_hero_terrain(session, terrain_id)
		var terrain_record: Dictionary = AmbientAudio.sync_overworld_session(session, "validation_terrain_%s" % terrain_id)
		terrain_records[terrain_id] = terrain_record.duplicate(true)
		_validate_record("terrain %s" % terrain_id, terrain_record, true, "calm", 1)
	var stable_record: Dictionary = AmbientAudio.sync_overworld_session(session, "validation_stable_repeat")
	_validate_record("stable", stable_record, false, "calm", 1)
	_set_enemy_pressure(session, "faction_mireclaw", 6)
	var pressure_record: Dictionary = AmbientAudio.sync_overworld_session(session, "validation_pressure")
	_validate_record("pressure", pressure_record, true, "medium", 2)
	session.day = 2
	var day_record: Dictionary = AmbientAudio.sync_overworld_session(session, "validation_day_pulse")
	_validate_record("day", day_record, true, "medium", 3)
	await get_tree().create_timer(EXPECTED_SEGMENT_DURATION_SEC + 0.35).timeout
	var continuous_summary: Dictionary = AmbientAudio.validation_summary()
	var continuous_record: Dictionary = AmbientAudio.sync_overworld_session(session, "validation_repeat_after_loop")
	_validate_continuous_playback(continuous_summary, continuous_record)
	var direct_summary: Dictionary = AmbientAudio.validation_summary()
	var saved_manifest_loaded := bool(AmbientAudio.get("_ambient_sfx_manifest_loaded"))
	var saved_manifest: Dictionary = (AmbientAudio.get("_ambient_sfx_manifest") as Dictionary).duplicate(true)
	AmbientAudio.validation_reset()
	AmbientAudio.set("_ambient_sfx_manifest_loaded", true)
	AmbientAudio.set("_ambient_sfx_manifest", {"schema": "overworld_ambient_runtime_sfx_manifest_v1", "cues": {}})
	var fallback_record: Dictionary = AmbientAudio.sync_overworld_session(session, "validation_generated_fallback")
	_validate_generated_fallback(fallback_record)
	AmbientAudio.validation_reset()
	AmbientAudio.set("_ambient_sfx_manifest_loaded", saved_manifest_loaded)
	AmbientAudio.set("_ambient_sfx_manifest", saved_manifest)
	AmbientAudio.validation_reset()
	var original_effects_volume := SettingsService.effects_volume_percent()
	SettingsService.settings["audio"]["effects_volume_percent"] = 0
	SettingsService.apply_settings()
	var muted_record: Dictionary = AmbientAudio.sync_overworld_session(session, "validation_effects_muted")
	SettingsService.settings["audio"]["effects_volume_percent"] = original_effects_volume
	SettingsService.apply_settings()
	AmbientAudio.validation_reset()
	_report["muted_record"] = muted_record
	_report["terrain_records"] = terrain_records
	_report["continuous_summary"] = continuous_summary
	_report["continuous_record"] = continuous_record
	_report["fallback_record"] = fallback_record
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

func _validate_record(label: String, record: Dictionary, expected_changed: bool, expected_threat: String, expected_layer_count: int) -> void:
	_expect_equal("%s schema" % label, String(record.get("schema", "")), "overworld_ambient_audio_runtime_v1")
	_expect_equal("%s cue" % label, String(record.get("cue_id", "")), "overworld_ambient_mix")
	_expect_equal("%s changed" % label, bool(record.get("changed", false)), expected_changed)
	_expect_equal("%s threat" % label, String(record.get("threat_level", "")), expected_threat)
	_expect(String(record.get("terrain_id", "")) != "", "%s record must expose terrain id: %s" % [label, record])
	_expect(int(record.get("layer_count", 0)) == expected_layer_count, "%s record must expose the exact ambient layer count %d: %s" % [label, expected_layer_count, record])
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
		_expect(absf(float(layer_record.get("duration_sec", 0.0)) - EXPECTED_SEGMENT_DURATION_SEC) < 0.01, "%s layer must expose the exact production segment duration: %s" % [label, layer_record])
		_expect(absf(float(layer_record.get("stream_length_sec", 0.0)) - EXPECTED_SEGMENT_DURATION_SEC) < 0.01, "%s layer stream length must match the production segment: %s" % [label, layer_record])
		_expect(bool(layer_record.get("looped", false)), "%s imported layer must be loop-enabled: %s" % [label, layer_record])
		_expect(int(layer_record.get("loop_mode", -1)) == int(AudioStreamWAV.LOOP_FORWARD), "%s imported layer must use LOOP_FORWARD: %s" % [label, layer_record])
		_expect(int(layer_record.get("loop_begin_sample", -1)) == 0, "%s imported layer must loop from sample zero: %s" % [label, layer_record])
		_expect(abs(int(layer_record.get("loop_end_sample", 0)) - EXPECTED_SEGMENT_FRAMES) <= 1, "%s imported layer loop end must match the exact segment frames: %s" % [label, layer_record])
		_expect(int(layer_record.get("mix_rate", 0)) == 44100, "%s imported layer must retain 44.1 kHz playback: %s" % [label, layer_record])
		_expect(bool(layer_record.get("stereo", false)), "%s imported layer must retain stereo playback: %s" % [label, layer_record])
		_expect(int(layer_record.get("imported_asset_count", 0)) == 1, "%s layer should count imported asset playback: %s" % [label, layer_record])
		_expect(int(layer_record.get("generated_fallback_count", 0)) == 0, "%s layer should not use generated fallback when asset is present: %s" % [label, layer_record])

func _validate_manifest_asset_surface() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://content/ambient_sfx_manifest.json"))
	_expect(parsed is Dictionary, "Ambient production manifest must parse as a Dictionary: %s" % parsed)
	if not (parsed is Dictionary):
		return
	var manifest: Dictionary = parsed
	_expect_equal("manifest schema", String(manifest.get("schema", "")), "overworld_ambient_runtime_sfx_manifest_v1")
	_expect_equal("manifest bus", String(manifest.get("audio_bus", "")), "Effects")
	_expect(not bool(manifest.get("final_sound_design", true)), "Ambient production manifest must not claim final sound design.")
	_expect(int(manifest.get("sample_rate_hz", 0)) == 44100, "Ambient production manifest must use 44.1 kHz.")
	_expect(int(manifest.get("channel_count", 0)) == 2, "Ambient production manifest must use stereo assets.")
	_expect(int(manifest.get("sample_width_bits", 0)) == 16, "Ambient production manifest must use 16-bit source assets.")
	_expect(int(manifest.get("segment_duration_msec", 0)) == 12000, "Ambient production manifest must use twelve-second segments.")
	_expect_equal("manifest loop mode", String(manifest.get("loop_mode", "")), "forward")
	_expect_equal("manifest asset tier", String(manifest.get("asset_tier", "")), "production_ambient_loop_v1")
	var cues: Dictionary = manifest.get("cues", {}) if manifest.get("cues", {}) is Dictionary else {}
	var actual_ids: Array = cues.keys()
	var expected_ids: Array = EXPECTED_AMBIENT_CUES.duplicate()
	actual_ids.sort()
	expected_ids.sort()
	_expect_equal("manifest exact cue ids", JSON.stringify(actual_ids), JSON.stringify(expected_ids))
	for cue_id_value in expected_ids:
		var cue_id := String(cue_id_value)
		var cue: Dictionary = cues.get(cue_id, {}) if cues.get(cue_id, {}) is Dictionary else {}
		var path := String(cue.get("path", ""))
		_expect(int(cue.get("duration_msec", 0)) == 12000, "Ambient cue must use exact segment duration: %s" % cue)
		_expect(ResourceLoader.exists(path), "Ambient cue resource must exist: %s" % path)
		var stream = load(path) if ResourceLoader.exists(path) else null
		_expect(stream is AudioStreamWAV, "Ambient cue resource must import as AudioStreamWAV for %s: %s" % [cue_id, stream])
		if stream is AudioStreamWAV:
			_expect(int(stream.mix_rate) == 44100, "Ambient cue import must retain 44.1 kHz: %s" % cue_id)
			_expect(bool(stream.stereo), "Ambient cue import must retain stereo: %s" % cue_id)
			_expect(absf(stream.get_length() - EXPECTED_SEGMENT_DURATION_SEC) < 0.01, "Ambient cue import must retain exact duration: %s" % cue_id)
			_expect(int(stream.loop_mode) == int(AudioStreamWAV.LOOP_DISABLED), "Shared ambient import must remain unmodified before detached playback: %s" % cue_id)

func _validate_continuous_playback(summary: Dictionary, record: Dictionary) -> void:
	_expect(int(summary.get("active_player_count", 0)) == 3, "All imported ambient players must remain active after one complete segment: %s" % summary)
	var layers: Array = summary.get("current_layers", []) if summary.get("current_layers", []) is Array else []
	_expect(layers.size() == 3, "Continuous summary must retain terrain, pressure, and day layers: %s" % [layers])
	for layer_value in layers:
		var layer: Dictionary = layer_value
		_expect(bool(layer.get("looped", false)), "Continuous layer must remain loop-enabled: %s" % layer)
		_expect(int(layer.get("loop_mode", -1)) == int(AudioStreamWAV.LOOP_FORWARD), "Continuous layer must retain forward-loop mode: %s" % layer)
	_expect(not bool(record.get("changed", true)), "Unchanged ambient context must not restart after a complete loop: %s" % record)
	_expect(int(record.get("active_player_count", 0)) == 3, "Stable ambient context must keep all loop players: %s" % record)

func _validate_generated_fallback(record: Dictionary) -> void:
	_expect(bool(record.get("changed", false)), "Missing-manifest ambient fallback context must start: %s" % record)
	_expect(bool(record.get("played", false)), "Missing-manifest ambient fallback context must play: %s" % record)
	var layers: Array = record.get("layers", []) if record.get("layers", []) is Array else []
	_expect(layers.size() == 3, "Generated ambient fallback must retain terrain, pressure, and day layers: %s" % [layers])
	for layer_value in layers:
		var layer: Dictionary = layer_value
		_expect_equal("fallback source", String(layer.get("playback_source", "")), "generated_waveform")
		_expect(int(layer.get("imported_asset_count", 0)) == 0, "Fallback layer must not count imported playback: %s" % layer)
		_expect(int(layer.get("generated_fallback_count", 0)) == 1, "Fallback layer must count generated playback: %s" % layer)

func _validate_direct_summary(summary: Dictionary) -> void:
	_expect_equal("direct schema", String(summary.get("schema", "")), "overworld_ambient_audio_runtime_v1")
	_expect(int(summary.get("record_count", 0)) >= 11, "Ambient direct summary must keep complete terrain plus pressure/day transition records: %s" % summary)
	_expect(String(summary.get("audio_bus", "")) == "Effects", "Ambient direct summary must route through Effects: %s" % summary)
	_expect(String(summary.get("sfx_manifest_path", "")) == "res://content/ambient_sfx_manifest.json", "Ambient direct summary must expose the ambient SFX manifest path: %s" % summary)
	_expect(bool(summary.get("sfx_manifest_loaded", false)), "Ambient direct summary must load the ambient SFX manifest: %s" % summary)
	_expect(int(summary.get("max_active_players", 0)) == AmbientAudio.MAX_ACTIVE_PLAYERS, "Ambient direct summary must expose player cap: %s" % summary)
	_expect(int(summary.get("pressure_layer_count", 0)) >= 1, "Ambient direct summary must include pressure layer evidence: %s" % summary)
	var terrain_counts: Dictionary = summary.get("terrain_counts", {}) if summary.get("terrain_counts", {}) is Dictionary else {}
	for terrain_id_value in EXPECTED_TERRAIN_IDS:
		var terrain_id := String(terrain_id_value)
		_expect(int(terrain_counts.get(terrain_id, 0)) >= 1, "Ambient direct summary must include terrain cue %s: %s" % [terrain_id, terrain_counts])
	var current_layers: Array = summary.get("current_layers", []) if summary.get("current_layers", []) is Array else []
	_expect(current_layers.size() == 3, "Ambient direct summary must keep current terrain, pressure, and day layers: %s" % summary)
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

func _set_hero_terrain(session, terrain_id: String) -> void:
	var hero_position: Dictionary = session.overworld.get("hero_position", {}) if session.overworld.get("hero_position", {}) is Dictionary else {}
	var x := int(hero_position.get("x", 0))
	var y := int(hero_position.get("y", 0))
	var map_data: Array = session.overworld.get("map", []) if session.overworld.get("map", []) is Array else []
	_expect(y >= 0 and y < map_data.size(), "Ambient terrain fixture hero row must be in bounds: %s" % hero_position)
	if y < 0 or y >= map_data.size():
		return
	var row: Array = map_data[y] if map_data[y] is Array else []
	_expect(x >= 0 and x < row.size(), "Ambient terrain fixture hero column must be in bounds: %s" % hero_position)
	if x < 0 or x >= row.size():
		return
	row[x] = terrain_id
	map_data[y] = row
	session.overworld["map"] = map_data

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
	var continuous_summary: Dictionary = _report.get("continuous_summary", {}) if _report.get("continuous_summary", {}) is Dictionary else {}
	return {
		"ok": bool(_report.get("ok", false)),
		"record_count": int(summary.get("record_count", 0)),
		"pressure_layer_count": int(summary.get("pressure_layer_count", 0)),
		"terrain_cue_count": EXPECTED_TERRAIN_IDS.size(),
		"segment_duration_sec": EXPECTED_SEGMENT_DURATION_SEC,
		"continuous_active_player_count": int(continuous_summary.get("active_player_count", 0)),
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
