class_name ProfileLog
extends RefCounted

const GENERAL_PROFILE_LOG_PATH := "user://debug/heroes_profile.jsonl"
const OVERWORLD_PROFILE_ENV := "HEROES_OVERWORLD_PROFILE_LOG"
const GENERAL_PROFILE_ENV := "HEROES_PROFILE_LOG"

static func begin_usec() -> int:
	return Time.get_ticks_usec()

static func elapsed_ms(started_usec: int) -> float:
	return snapped(float(maxi(0, Time.get_ticks_usec() - started_usec)) / 1000.0, 0.001)

static func env_enabled(name: String) -> bool:
	var value := OS.get_environment(name).strip_edges().to_lower()
	return value in ["1", "true", "yes", "on", "enabled"]

static func general_enabled() -> bool:
	return env_enabled(GENERAL_PROFILE_ENV) or env_enabled(OVERWORLD_PROFILE_ENV)

static func emit_general(
	surface: String,
	phase: String,
	event: String,
	total_ms: float,
	buckets_ms: Dictionary = {},
	metadata: Dictionary = {},
	session: Variant = null
) -> void:
	if not general_enabled():
		return
	var record := {
		"schema": "heroes_like.profile.v1",
		"timestamp_utc": Time.get_datetime_string_from_system(true),
		"monotonic_msec": Time.get_ticks_msec(),
		"surface": surface,
		"phase": phase,
		"event": event,
		"total_ms": snapped(maxf(0.0, total_ms), 0.001),
		"buckets_ms": _number_dictionary(buckets_ms),
		"metadata": metadata.duplicate(true),
		"session": session_metadata(session),
	}
	_append_jsonl(GENERAL_PROFILE_LOG_PATH, record)

static func emit_general_record(record: Dictionary) -> void:
	if not general_enabled():
		return
	var normalized := record.duplicate(true)
	if not normalized.has("schema"):
		normalized["schema"] = "heroes_like.profile.v1"
	if not normalized.has("timestamp_utc"):
		normalized["timestamp_utc"] = Time.get_datetime_string_from_system(true)
	if not normalized.has("monotonic_msec"):
		normalized["monotonic_msec"] = Time.get_ticks_msec()
	_append_jsonl(GENERAL_PROFILE_LOG_PATH, normalized)

static func session_metadata(session: Variant) -> Dictionary:
	if session == null:
		return {}
	var metadata := {
		"session_id": String(session.get("session_id") if session is Object else ""),
		"scenario_id": String(session.get("scenario_id") if session is Object else ""),
		"hero_id": String(session.get("hero_id") if session is Object else ""),
		"day": int(session.get("day") if session is Object else 0),
		"difficulty": String(session.get("difficulty") if session is Object else ""),
		"launch_mode": String(session.get("launch_mode") if session is Object else ""),
		"game_state": String(session.get("game_state") if session is Object else ""),
		"scenario_status": String(session.get("scenario_status") if session is Object else ""),
	}
	if session is Object:
		var flags = session.get("flags")
		var overworld = session.get("overworld")
		var battle = session.get("battle")
		if flags is Dictionary:
			metadata["generated_random_map"] = bool(flags.get("generated_random_map", false))
			var provenance: Dictionary = flags.get("generated_random_map_provenance", {}) if flags.get("generated_random_map_provenance", {}) is Dictionary else {}
			if not provenance.is_empty():
				metadata["generated_provenance"] = {
					"normalized_seed": String(provenance.get("normalized_seed", "")),
					"template_id": String(provenance.get("template_id", "")),
					"profile_id": String(provenance.get("profile_id", "")),
					"size_class_id": String(provenance.get("size_class_id", "")),
				}
		if overworld is Dictionary:
			var map_size := _map_size_metadata(overworld)
			if not map_size.is_empty():
				metadata["map_size"] = map_size
			metadata["town_count"] = _array_count(overworld.get("towns", []))
			metadata["resource_node_count"] = _array_count(overworld.get("resource_nodes", []))
			metadata["artifact_count"] = _array_count(overworld.get("artifacts", []))
			metadata["encounter_count"] = _array_count(overworld.get("encounters", []))
		if battle is Dictionary:
			metadata["battle_active"] = not battle.is_empty()
			metadata["battle_stack_count"] = _array_count(battle.get("stacks", []))
	return metadata

static func clear_general_log() -> Dictionary:
	_ensure_debug_directory()
	var file := FileAccess.open(GENERAL_PROFILE_LOG_PATH, FileAccess.WRITE)
	if file != null:
		file.close()
	return general_log_snapshot()

static func general_log_snapshot() -> Dictionary:
	return {
		"enabled": general_enabled(),
		"path": GENERAL_PROFILE_LOG_PATH,
		"absolute_path": ProjectSettings.globalize_path(GENERAL_PROFILE_LOG_PATH),
		"record_count": record_count(GENERAL_PROFILE_LOG_PATH),
	}

static func last_general_records(limit: int = 5) -> Array:
	return last_records(GENERAL_PROFILE_LOG_PATH, limit)

static func record_count(path: String) -> int:
	if not FileAccess.file_exists(path):
		return 0
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return 0
	var count := 0
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line != "":
			count += 1
	file.close()
	return count

static func last_records(path: String, limit: int = 5) -> Array:
	var records := []
	if limit <= 0 or not FileAccess.file_exists(path):
		return records
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return records
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line == "":
			continue
		var parsed = JSON.parse_string(line)
		if parsed is Dictionary:
			records.append(parsed)
			while records.size() > limit:
				records.pop_front()
	file.close()
	return records

static func _append_jsonl(path: String, record: Dictionary) -> void:
	_ensure_debug_directory()
	if not FileAccess.file_exists(path):
		var created := FileAccess.open(path, FileAccess.WRITE)
		if created == null:
			push_warning("Unable to create profile log at %s: %s" % [path, error_string(FileAccess.get_open_error())])
			return
		created.close()
	var file := FileAccess.open(path, FileAccess.READ_WRITE)
	if file == null:
		push_warning("Unable to append profile log at %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return
	file.seek_end()
	file.store_string("%s\n" % JSON.stringify(json_safe(record)))
	file.close()

static func _ensure_debug_directory() -> void:
	var dir := DirAccess.open("user://")
	if dir != null:
		dir.make_dir_recursive("debug")

static func _number_dictionary(value: Dictionary) -> Dictionary:
	var result := {}
	for key_value in value.keys():
		var key := String(key_value)
		var raw = value.get(key_value)
		if raw is int or raw is float:
			result[key] = snapped(maxf(0.0, float(raw)), 0.001)
		else:
			result[key] = raw
	return result

static func _map_size_metadata(overworld: Dictionary) -> Dictionary:
	var size = overworld.get("map_size", {})
	if size is Dictionary:
		var width := int(size.get("width", size.get("x", 0)))
		var height := int(size.get("height", size.get("y", 0)))
		if width > 0 and height > 0:
			return {"width": width, "height": height, "x": width, "y": height}
	var map = overworld.get("map", {})
	if map is Dictionary:
		var rows = map.get("rows", [])
		if rows is Array and not rows.is_empty():
			var first_row = rows[0]
			return {"width": String(first_row).length(), "height": rows.size(), "x": String(first_row).length(), "y": rows.size()}
	return {}

static func _array_count(value: Variant) -> int:
	return (value as Array).size() if value is Array else 0

static func json_safe(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var result := {}
			var dictionary: Dictionary = value
			for key_value in dictionary.keys():
				result[String(key_value)] = json_safe(dictionary.get(key_value))
			return result
		TYPE_ARRAY:
			var result := []
			var array: Array = value
			for item in array:
				result.append(json_safe(item))
			return result
		TYPE_VECTOR2I:
			var tile: Vector2i = value
			return {"x": tile.x, "y": tile.y}
		TYPE_VECTOR2:
			var vector: Vector2 = value
			return {"x": vector.x, "y": vector.y}
		TYPE_COLOR:
			var color: Color = value
			return {"r": color.r, "g": color.g, "b": color.b, "a": color.a}
		_:
			return value
