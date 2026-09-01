extends Node

const REPORT_ID := "RUNTIME_AUDIO_CACHE_FALLBACK_REPORT"
const RuntimeAudioLoaderScript = preload("res://scripts/audio/RuntimeAudioLoader.gd")
const SOURCE_WAV_PATH := "res://art/audio/runtime/ui/click.wav"
const FIXTURE_DIR := "user://runtime_audio_cache_fallback_report"

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

	_cleanup_fixture(fixture_path)
	_cleanup_fixture("%s.import" % fixture_path)
	_cleanup_fixture("%s.import" % absent_source_path)
	DirAccess.remove_absolute(fixture_root)
	var report := {
		"report_id": REPORT_ID,
		"ok": _errors.is_empty(),
		"source_fallback_loaded": source_fallback is AudioStreamWAV,
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
