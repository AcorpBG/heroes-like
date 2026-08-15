extends Node

const REPORT_ID := "MUSIC_AUDIO_RUNTIME_REPORT"
const OUTPUT_DIR := "res://.artifacts/music_audio_runtime_report"
const EXPECTED_CUES := [
	"music_menu_theme",
	"music_overworld_theme",
	"music_battle_theme",
	"music_outcome_theme",
]
const EXPECTED_LAYER_CUES := [
	"music_menu_theme",
	"music_menu_theme_harmony",
	"music_menu_theme_motion",
	"music_overworld_theme",
	"music_overworld_theme_harmony",
	"music_overworld_theme_motion",
	"music_battle_theme",
	"music_battle_theme_harmony",
	"music_battle_theme_motion",
	"music_outcome_theme",
	"music_outcome_theme_harmony",
	"music_outcome_theme_motion",
]
const EXPECTED_SEGMENT_DURATION_SEC := 8.0
const EXPECTED_SEGMENT_FRAMES := 352800

var _errors: Array[String] = []
var _report := {
	"ok": false,
	"summary": {},
	"records": [],
	"continuous_summary": {},
	"continuous_record": {},
	"fallback_record": {},
	"shell_summary": {},
	"errors": [],
}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_validate_manifest_asset_surface()
	MusicAudio.validation_reset()
	var menu_record: Dictionary = MusicAudio.sync_context("menu", "validation_menu", {"scenario_id": "river-pass"})
	var stable_record: Dictionary = MusicAudio.sync_context("menu", "validation_menu_repeat", {"scenario_id": "river-pass"})
	var overworld_record: Dictionary = MusicAudio.sync_context("overworld", "validation_overworld", {
		"scenario_id": "river-pass",
		"day": 1,
		"threat_level": "low",
		"launch_mode": SessionState.LAUNCH_MODE_SKIRMISH,
	})
	var battle_record: Dictionary = MusicAudio.sync_context("battle", "validation_battle", {
		"scenario_id": "river-pass",
		"encounter_id": "validation_encounter",
		"encounter_difficulty": "hard",
	})
	var outcome_metadata := {
		"scenario_id": "river-pass",
		"status": "victory",
		"day": 3,
	}
	var outcome_record: Dictionary = MusicAudio.sync_context("outcome", "validation_outcome", outcome_metadata)
	await get_tree().create_timer(EXPECTED_SEGMENT_DURATION_SEC + 0.35).timeout
	var continuous_summary := MusicAudio.validation_summary()
	var continuous_record: Dictionary = MusicAudio.sync_context("outcome", "validation_outcome_repeat_after_loop", outcome_metadata)
	var direct_summary := MusicAudio.validation_summary()
	MusicAudio.validation_reset()
	var saved_manifest_loaded := bool(MusicAudio.get("_music_runtime_manifest_loaded"))
	var saved_manifest: Dictionary = (MusicAudio.get("_music_runtime_manifest") as Dictionary).duplicate(true)
	MusicAudio.set("_music_runtime_manifest_loaded", true)
	MusicAudio.set("_music_runtime_manifest", {"schema": "music_runtime_asset_manifest_v1", "cues": {}})
	var fallback_record: Dictionary = MusicAudio.sync_context("menu", "validation_generated_fallback", {"scenario_id": "fallback"})
	MusicAudio.validation_reset()
	MusicAudio.set("_music_runtime_manifest_loaded", saved_manifest_loaded)
	MusicAudio.set("_music_runtime_manifest", saved_manifest)

	var menu_shell = load("res://scenes/menus/MainMenu.tscn").instantiate()
	add_child(menu_shell)
	await get_tree().process_frame
	await get_tree().process_frame
	var shell_summary := MusicAudio.validation_summary()
	var shell_snapshot: Dictionary = menu_shell.call("validation_snapshot")

	_report["summary"] = direct_summary
	_report["records"] = direct_summary.get("records", [])
	_report["continuous_summary"] = continuous_summary
	_report["continuous_record"] = continuous_record
	_report["fallback_record"] = fallback_record
	_report["shell_summary"] = shell_summary
	_validate_record("menu", menu_record, "music_menu_theme", "menu", true)
	_validate_record("stable", stable_record, "music_menu_theme", "menu", false)
	_validate_record("overworld", overworld_record, "music_overworld_theme", "overworld", true)
	_validate_record("battle", battle_record, "music_battle_theme", "battle", true)
	_validate_record("outcome", outcome_record, "music_outcome_theme", "outcome", true)
	_validate_continuous_playback(continuous_summary, continuous_record)
	_validate_generated_fallback(fallback_record)
	_validate_direct_summary(direct_summary)
	_validate_shell_summary(shell_summary, shell_snapshot)
	_report["ok"] = _errors.is_empty()
	_report["errors"] = _errors.duplicate()
	_write_json("%s/report.json" % OUTPUT_DIR, _report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify(_summary_payload())])
	MusicAudio.validation_reset()
	await get_tree().process_frame
	get_tree().quit(0 if _errors.is_empty() else 1)

func _validate_record(label: String, record: Dictionary, expected_cue: String, expected_context: String, expected_changed: bool) -> void:
	_expect_equal("%s schema" % label, String(record.get("schema", "")), "music_audio_runtime_v1")
	_expect_equal("%s cue" % label, String(record.get("cue_id", "")), expected_cue)
	_expect_equal("%s context" % label, String(record.get("context_id", "")), expected_context)
	_expect_equal("%s changed" % label, bool(record.get("changed", false)), expected_changed)
	_expect(int(record.get("layer_count", 0)) == 3, "%s record must expose three music layers: %s" % [label, record])
	_expect(int(record.get("active_player_count", 0)) == MusicAudio.MAX_ACTIVE_PLAYERS, "%s route must own exactly three active music players: %s" % [label, record])
	_expect(["Master", "Music"].has(String(record.get("audio_bus", ""))), "%s record must route through Master or Music: %s" % [label, record])
	_expect(String(record.get("music_manifest_path", "")) == "res://content/music_runtime_manifest.json", "%s record must expose music manifest path: %s" % [label, record])
	_expect(bool(record.get("music_manifest_loaded", false)), "%s record must load music manifest: %s" % [label, record])
	for layer in record.get("layers", []):
		var layer_record: Dictionary = layer
		_expect(String(layer_record.get("cue_id", "")).begins_with(expected_cue), "%s layer has unexpected cue id: %s" % [label, layer_record])
		_expect(float(layer_record.get("duration_sec", 0.0)) > 0.0, "%s layer must expose duration: %s" % [label, layer_record])
		_expect(float(layer_record.get("frequency", 0.0)) > 0.0, "%s layer must expose frequency: %s" % [label, layer_record])
		_expect(String(layer_record.get("playback_source", "")) == "imported_wav", "%s layer should prefer imported runtime music WAV assets: %s" % [label, layer_record])
		_expect(String(layer_record.get("asset_path", "")).begins_with("res://art/audio/runtime/music/"), "%s layer must expose runtime music asset path: %s" % [label, layer_record])
		_expect(absf(float(layer_record.get("duration_sec", 0.0)) - EXPECTED_SEGMENT_DURATION_SEC) < 0.01, "%s layer must expose the exact production segment duration: %s" % [label, layer_record])
		_expect(absf(float(layer_record.get("stream_length_sec", 0.0)) - EXPECTED_SEGMENT_DURATION_SEC) < 0.01, "%s layer stream length must match the production segment: %s" % [label, layer_record])
		_expect(bool(layer_record.get("looped", false)), "%s imported layer must be loop-enabled: %s" % [label, layer_record])
		_expect(int(layer_record.get("loop_mode", -1)) == int(AudioStreamWAV.LOOP_FORWARD), "%s imported layer must use LOOP_FORWARD: %s" % [label, layer_record])
		_expect(int(layer_record.get("loop_begin_sample", -1)) == 0, "%s imported layer must loop from sample zero: %s" % [label, layer_record])
		_expect(abs(int(layer_record.get("loop_end_sample", 0)) - EXPECTED_SEGMENT_FRAMES) <= 1, "%s imported layer loop end must match the exact segment frames: %s" % [label, layer_record])
		_expect(int(layer_record.get("mix_rate", 0)) == 44100, "%s imported layer must retain 44.1 kHz playback: %s" % [label, layer_record])
		_expect(bool(layer_record.get("stereo", false)), "%s imported layer must retain stereo playback: %s" % [label, layer_record])
		_expect(int(layer_record.get("imported_asset_count", 0)) == 1, "%s layer should count imported music playback: %s" % [label, layer_record])
		_expect(int(layer_record.get("generated_fallback_count", 0)) == 0, "%s layer should not use generated fallback when asset is present: %s" % [label, layer_record])

func _validate_manifest_asset_surface() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://content/music_runtime_manifest.json"))
	_expect(parsed is Dictionary, "Music production manifest must parse as a Dictionary: %s" % parsed)
	if not (parsed is Dictionary):
		return
	var manifest: Dictionary = parsed
	_expect_equal("manifest schema", String(manifest.get("schema", "")), "music_runtime_asset_manifest_v1")
	_expect_equal("manifest bus", String(manifest.get("audio_bus", "")), "Music")
	_expect(not bool(manifest.get("final_composition", true)), "Music production manifest must not claim final composition.")
	_expect(int(manifest.get("sample_rate_hz", 0)) == 44100, "Music production manifest must use 44.1 kHz.")
	_expect(int(manifest.get("channel_count", 0)) == 2, "Music production manifest must use stereo assets.")
	_expect(int(manifest.get("sample_width_bits", 0)) == 16, "Music production manifest must use 16-bit source assets.")
	_expect(int(manifest.get("segment_duration_msec", 0)) == 8000, "Music production manifest must use eight-second segments.")
	_expect_equal("manifest loop mode", String(manifest.get("loop_mode", "")), "forward")
	_expect_equal("manifest asset tier", String(manifest.get("asset_tier", "")), "production_layered_loop_v1")
	var cues: Dictionary = manifest.get("cues", {}) if manifest.get("cues", {}) is Dictionary else {}
	var actual_ids: Array = cues.keys()
	var expected_ids: Array = EXPECTED_LAYER_CUES.duplicate()
	actual_ids.sort()
	expected_ids.sort()
	_expect_equal("manifest exact cue ids", JSON.stringify(actual_ids), JSON.stringify(expected_ids))
	for cue_id_value in expected_ids:
		var cue_id := String(cue_id_value)
		var cue: Dictionary = cues.get(cue_id, {}) if cues.get(cue_id, {}) is Dictionary else {}
		var path := String(cue.get("path", ""))
		_expect(int(cue.get("duration_msec", 0)) == 8000, "Music cue must use exact segment duration: %s" % cue)
		_expect(ResourceLoader.exists(path), "Music cue resource must exist: %s" % path)
		var stream = load(path) if ResourceLoader.exists(path) else null
		_expect(stream is AudioStreamWAV, "Music cue resource must import as AudioStreamWAV for %s: %s" % [cue_id, stream])
		if stream is AudioStreamWAV:
			_expect(int(stream.mix_rate) == 44100, "Music cue import must retain 44.1 kHz: %s" % cue_id)
			_expect(bool(stream.stereo), "Music cue import must retain stereo: %s" % cue_id)
			_expect(absf(stream.get_length() - EXPECTED_SEGMENT_DURATION_SEC) < 0.01, "Music cue import must retain exact duration: %s" % cue_id)

func _validate_continuous_playback(summary: Dictionary, record: Dictionary) -> void:
	_expect(int(summary.get("active_player_count", 0)) == MusicAudio.MAX_ACTIVE_PLAYERS, "All imported music players must remain active after one complete segment: %s" % summary)
	_expect_equal("continuous context", String(summary.get("current_context_id", "")), "outcome")
	var layers: Array = summary.get("current_layers", []) if summary.get("current_layers", []) is Array else []
	_expect(layers.size() == MusicAudio.MAX_ACTIVE_PLAYERS, "Continuous summary must retain all three layers: %s" % [layers])
	for layer_value in layers:
		var layer: Dictionary = layer_value
		_expect(bool(layer.get("looped", false)), "Continuous layer must remain loop-enabled: %s" % layer)
		_expect(int(layer.get("loop_mode", -1)) == int(AudioStreamWAV.LOOP_FORWARD), "Continuous layer must retain forward-loop mode: %s" % layer)
	_expect(not bool(record.get("changed", true)), "Unchanged context must not restart after a complete loop: %s" % record)
	_expect(int(record.get("active_player_count", 0)) == MusicAudio.MAX_ACTIVE_PLAYERS, "Stable context must keep all loop players: %s" % record)

func _validate_generated_fallback(record: Dictionary) -> void:
	_expect(bool(record.get("changed", false)), "Missing-manifest fallback context must start: %s" % record)
	_expect(bool(record.get("played", false)), "Missing-manifest fallback context must play: %s" % record)
	var layers: Array = record.get("layers", []) if record.get("layers", []) is Array else []
	_expect(layers.size() == MusicAudio.MAX_ACTIVE_PLAYERS, "Generated fallback must retain three layers: %s" % [layers])
	for layer_value in layers:
		var layer: Dictionary = layer_value
		_expect_equal("fallback source", String(layer.get("playback_source", "")), "generated_waveform")
		_expect(int(layer.get("imported_asset_count", 0)) == 0, "Fallback layer must not count imported playback: %s" % layer)
		_expect(int(layer.get("generated_fallback_count", 0)) == 1, "Fallback layer must count generated playback: %s" % layer)

func _validate_direct_summary(summary: Dictionary) -> void:
	_expect_equal("direct schema", String(summary.get("schema", "")), "music_audio_runtime_v1")
	_expect(int(summary.get("record_count", 0)) >= 4, "Music direct summary must keep changed context records: %s" % summary)
	_expect(["Master", "Music"].has(String(summary.get("audio_bus", ""))), "Music direct summary must expose a valid bus: %s" % summary)
	_expect(int(summary.get("max_active_players", 0)) == MusicAudio.MAX_ACTIVE_PLAYERS, "Music direct summary must expose player cap: %s" % summary)
	_expect(String(summary.get("music_manifest_path", "")) == "res://content/music_runtime_manifest.json", "Music direct summary must expose the music manifest path: %s" % summary)
	_expect(bool(summary.get("music_manifest_loaded", false)), "Music direct summary must load the music manifest: %s" % summary)
	var cue_counts: Dictionary = summary.get("cue_counts", {}) if summary.get("cue_counts", {}) is Dictionary else {}
	var context_counts: Dictionary = summary.get("context_counts", {}) if summary.get("context_counts", {}) is Dictionary else {}
	for cue in EXPECTED_CUES:
		_expect(int(cue_counts.get(cue, 0)) >= 1, "Music summary must include cue %s: %s" % [cue, cue_counts])
	for context_id in ["menu", "overworld", "battle", "outcome"]:
		_expect(int(context_counts.get(context_id, 0)) >= 1, "Music summary must include context %s: %s" % [context_id, context_counts])
	var current_layers: Array = summary.get("current_layers", []) if summary.get("current_layers", []) is Array else []
	_expect(current_layers.size() == 3, "Music direct summary must keep current generated layers: %s" % summary)
	_expect_equal("current context", String(summary.get("current_context_id", "")), "outcome")

func _validate_shell_summary(summary: Dictionary, snapshot: Dictionary) -> void:
	_expect_equal("shell schema", String(summary.get("schema", "")), "music_audio_runtime_v1")
	_expect(int(summary.get("record_count", 0)) >= 1, "MainMenu must sync MusicAudio at runtime: %s" % summary)
	_expect(String(summary.get("music_manifest_path", "")) == "res://content/music_runtime_manifest.json", "MainMenu music summary must expose the music manifest path: %s" % summary)
	_expect(bool(summary.get("music_manifest_loaded", false)), "MainMenu music summary must load the music manifest: %s" % summary)
	var cue_counts: Dictionary = summary.get("cue_counts", {}) if summary.get("cue_counts", {}) is Dictionary else {}
	_expect(int(cue_counts.get("music_menu_theme", 0)) >= 1, "MainMenu shell route must play menu music cue: %s" % summary)
	var snapshot_summary: Dictionary = snapshot.get("music_audio", {}) if snapshot.get("music_audio", {}) is Dictionary else {}
	_expect_equal("snapshot music schema", String(snapshot_summary.get("schema", "")), "music_audio_runtime_v1")
	_expect(int(snapshot_summary.get("record_count", 0)) >= 1, "MainMenu validation snapshot must expose music audio summary: %s" % snapshot_summary)

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
		"shell_record_count": int(shell_summary.get("record_count", 0)),
		"audio_bus": String(summary.get("audio_bus", "")),
		"max_active_players": int(summary.get("max_active_players", 0)),
		"music_manifest_loaded": bool(summary.get("music_manifest_loaded", false)),
		"continuous_active_player_count": int(continuous_summary.get("active_player_count", 0)),
		"segment_duration_sec": EXPECTED_SEGMENT_DURATION_SEC,
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
