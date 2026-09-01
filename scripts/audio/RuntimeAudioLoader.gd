extends RefCounted

## Loads manifest-owned audio without assuming Godot's generated import cache is
## already complete. Fresh project copies can retain a valid .import remap while
## its destination is still being created; calling load() in that state emits a
## hard resource error before the generated-audio fallback can run.

static func load_stream(path: String) -> AudioStream:
	var normalized := path.strip_edges()
	if normalized == "":
		return null
	var imported_path := imported_payload_path(normalized)
	if imported_path != "" and FileAccess.file_exists(imported_path):
		var resource := ResourceLoader.load(normalized)
		if resource is AudioStream:
			return resource
	return _load_source_stream(normalized)

static func imported_payload_path(path: String) -> String:
	var import_metadata_path := "%s.import" % path.strip_edges()
	if not FileAccess.file_exists(import_metadata_path):
		return ""
	var metadata := ConfigFile.new()
	if metadata.load(import_metadata_path) != OK:
		return ""
	var remapped := String(metadata.get_value("remap", "path", "")).strip_edges()
	if remapped != "":
		return remapped
	var destinations = metadata.get_value("deps", "dest_files", [])
	if destinations is PackedStringArray or destinations is Array:
		for destination_value in destinations:
			var destination := String(destination_value).strip_edges()
			if destination != "":
				return destination
	return ""

static func _load_source_stream(path: String) -> AudioStream:
	if not FileAccess.file_exists(path):
		return null
	match path.get_extension().to_lower():
		"ogg":
			var ogg_stream := AudioStreamOggVorbis.load_from_file(path)
			return ogg_stream if ogg_stream is AudioStream else null
		"wav":
			var wav_stream := AudioStreamWAV.load_from_file(path)
			return wav_stream if wav_stream is AudioStream else null
		_:
			return null
