extends Node

const REPORT_ID := "RUNTIME_AUDIO_CACHE_FALLBACK_REPORT"
const RuntimeAudioLoaderScript = preload("res://scripts/audio/RuntimeAudioLoader.gd")
const SOURCE_WAV_PATH := "res://art/audio/runtime/ui/click.wav"
const MENU_SOURCE_PATHS := {
	"music_menu_theme": "res://art/audio/runtime/music/menu_root.ogg",
	"music_menu_theme_harmony": "res://art/audio/runtime/music/menu_harmony.ogg",
	"music_menu_theme_motion": "res://art/audio/runtime/music/menu_motion.ogg",
}
const FIXTURE_DIR := "user://runtime_audio_cache_fallback_report"
const REPORTED_MISSING_MENU_MOTION_PAYLOAD := "user://runtime_audio_cache_fallback_report/.godot/imported/menu_motion.ogg-774a4e315ae3f6482f7c06a6c3e415b2.oggvorbisstr"

var _errors: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var fixture_root := ProjectSettings.globalize_path(FIXTURE_DIR)
	DirAccess.make_dir_recursive_absolute(fixture_root)
	var fixture_path := "%s/present_source.wav" % FIXTURE_DIR
	var missing_payload_path := "%s/missing_import.sample" % FIXTURE_DIR
	var source_bytes := FileAccess.get_file_as_bytes(SOURCE_WAV_PATH)
	_expect(not source_bytes.is_empty(), "Source WAV fixture could not be read.")
	var fixture_file := FileAccess.open(fixture_path, FileAccess.WRITE)
	_expect(fixture_file != null, "Could not create the source-audio fixture.")
	if fixture_file != null:
		fixture_file.store_buffer(source_bytes)
		fixture_file.close()
	_write_import_metadata(fixture_path, missing_payload_path)
	var source_fallback := RuntimeAudioLoaderScript.load_stream(fixture_path)
	_expect(source_fallback is AudioStreamWAV, "Missing imported payload did not fall back to present source WAV bytes.")

	var absent_source_path := "%s/absent_source.wav" % FIXTURE_DIR
	_write_import_metadata(absent_source_path, missing_payload_path)
	var unavailable := RuntimeAudioLoaderScript.load_stream(absent_source_path)
	_expect(unavailable == null, "Missing source and imported payload must fail quietly so the caller can synthesize its fallback.")

	var saved_manifest_loaded := bool(MusicAudio.get("_music_runtime_manifest_loaded"))
	var saved_manifest: Dictionary = (MusicAudio.get("_music_runtime_manifest") as Dictionary).duplicate(true)
	var original_master_volume := SettingsService.master_volume_percent()
	var original_music_volume := SettingsService.music_volume_percent()
	if original_master_volume <= 0:
		_expect(bool(SettingsService.set_master_volume_percent(80).get("ok", false)), "Could not enable master audio for the cold-cache menu test.")
	if original_music_volume <= 0:
		_expect(bool(SettingsService.set_music_volume_percent(65).get("ok", false)), "Could not enable music audio for the cold-cache menu test.")
	var menu_cues := {}
	var fixture_paths: Array[String] = []
	for cue_id_value in MENU_SOURCE_PATHS:
		var cue_id := String(cue_id_value)
		var source_path := String(MENU_SOURCE_PATHS[cue_id])
		var fixture_ogg_path := "%s/%s.ogg" % [FIXTURE_DIR, cue_id]
		var missing_ogg_payload_path := REPORTED_MISSING_MENU_MOTION_PAYLOAD if cue_id == "music_menu_theme_motion" else "%s/missing_%s.oggvorbisstr" % [FIXTURE_DIR, cue_id]
		fixture_paths.append(fixture_ogg_path)
		fixture_paths.append("%s.import" % fixture_ogg_path)
		var source_ogg_bytes := FileAccess.get_file_as_bytes(source_path)
		_expect(not source_ogg_bytes.is_empty(), "Menu OGG source fixture could not be read: %s" % source_path)
		var fixture_ogg := FileAccess.open(fixture_ogg_path, FileAccess.WRITE)
		_expect(fixture_ogg != null, "Could not create menu OGG fixture: %s" % fixture_ogg_path)
		if fixture_ogg != null:
			fixture_ogg.store_buffer(source_ogg_bytes)
			fixture_ogg.close()
		_write_import_metadata(fixture_ogg_path, missing_ogg_payload_path)
		_expect(not FileAccess.file_exists(missing_ogg_payload_path), "Cold-cache OGG payload unexpectedly exists: %s" % missing_ogg_payload_path)
		_expect(RuntimeAudioLoaderScript.imported_payload_path(fixture_ogg_path) == missing_ogg_payload_path, "OGG fixture did not expose its stale import destination.")
		var source_ogg_fallback := RuntimeAudioLoaderScript.load_stream(fixture_ogg_path)
		_expect(source_ogg_fallback is AudioStreamOggVorbis, "Missing imported payload did not fall back to present source OGG bytes: %s" % cue_id)
		menu_cues[cue_id] = {
			"path": fixture_ogg_path,
			"role": "cold-cache %s" % cue_id,
			"duration_msec": 8000,
			"volume_db": -28.0,
		}

	MusicAudio.validation_reset()
	MusicAudio.set("_music_runtime_manifest_loaded", true)
	MusicAudio.set("_music_runtime_manifest", {
		"schema": "music_runtime_asset_manifest_v1",
		"cues": menu_cues,
	})
	var menu_record: Dictionary = MusicAudio.sync_context("menu", "validation_cold_cache_menu", {"scenario_id": "cold-cache-menu"})
	var menu_layers: Array = menu_record.get("layers", []) if menu_record.get("layers", []) is Array else []
	_expect(bool(menu_record.get("played", false)), "Cold-cache menu music must play through source OGG fallback.")
	_expect(int(menu_record.get("active_player_count", 0)) == MusicAudio.MAX_ACTIVE_PLAYERS, "Cold-cache menu music must start all three players: %s" % menu_record)
	_expect(menu_layers.size() == MusicAudio.MAX_ACTIVE_PLAYERS, "Cold-cache menu music must retain all three layer records: %s" % [menu_layers])
	var source_ogg_layer_count := 0
	for layer_value in menu_layers:
		if not (layer_value is Dictionary):
			continue
		var layer: Dictionary = layer_value
		if String(layer.get("playback_source", "")) == "imported_ogg" and int(layer.get("imported_asset_count", 0)) == 1 and int(layer.get("generated_fallback_count", -1)) == 0:
			source_ogg_layer_count += 1
	_expect(source_ogg_layer_count == MusicAudio.MAX_ACTIVE_PLAYERS, "Cold-cache menu music did not load every layer from source OGG bytes: %s" % [menu_layers])
	MusicAudio.validation_reset()
	MusicAudio.set("_music_runtime_manifest_loaded", saved_manifest_loaded)
	MusicAudio.set("_music_runtime_manifest", saved_manifest)
	if original_music_volume <= 0:
		_expect(bool(SettingsService.set_music_volume_percent(original_music_volume).get("ok", false)), "Could not restore music volume after the cold-cache menu test.")
	if original_master_volume <= 0:
		_expect(bool(SettingsService.set_master_volume_percent(original_master_volume).get("ok", false)), "Could not restore master volume after the cold-cache menu test.")

	_cleanup_fixture(fixture_path)
	_cleanup_fixture("%s.import" % fixture_path)
	_cleanup_fixture("%s.import" % absent_source_path)
	for fixture_cleanup_path in fixture_paths:
		_cleanup_fixture(fixture_cleanup_path)
	DirAccess.remove_absolute(fixture_root)
	var report := {
		"report_id": REPORT_ID,
		"ok": _errors.is_empty(),
		"source_fallback_loaded": source_fallback is AudioStreamWAV,
		"menu_source_ogg_layer_count": source_ogg_layer_count,
		"menu_player_count": int(menu_record.get("active_player_count", 0)),
		"missing_pair_returned_null": unavailable == null,
		"errors": _errors,
	}
	print("%s %s" % [REPORT_ID, JSON.stringify(report)])
	get_tree().quit(0 if _errors.is_empty() else 1)

func _write_import_metadata(source_path: String, imported_path: String) -> void:
	var metadata := FileAccess.open("%s.import" % source_path, FileAccess.WRITE)
	_expect(metadata != null, "Could not create import metadata for %s." % source_path)
	if metadata == null:
		return
	metadata.store_string('[remap]\npath="%s"\n\n[deps]\ndest_files=["%s"]\n' % [imported_path, imported_path])
	metadata.close()

func _cleanup_fixture(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(absolute)

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_errors.append(message)
	push_error(message)
