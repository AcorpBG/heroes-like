extends Node

const REPORT_ID := "PROFILE_LOG_GENERAL_SURFACE_REGRESSION"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var previous_general := OS.get_environment("HEROES_PROFILE_LOG")
	OS.set_environment("HEROES_PROFILE_LOG", "1")
	SaveService.validation_clear_general_profile_log()

	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var town := _first_player_town(session)
	if town.is_empty():
		_fail("No player town was available for profile logging regression.")
		return
	_move_active_hero_to_town(session, town)
	var visit_result: Dictionary = OverworldRules.set_active_town_visit(session, String(town.get("placement_id", "")))
	if not bool(visit_result.get("ok", false)):
		_fail("Could not prepare active town visit.", visit_result)
		return
	SessionState.set_active_session(session)
	session = SessionState.ensure_active_session()

	var save_result: Dictionary = SaveService.save_runtime_autosave_session(session, false)
	if not bool(save_result.get("ok", false)):
		_fail("Autosave failed while profile logging was enabled.", save_result)
		return

	var town_shell = load("res://scenes/town/TownShell.tscn").instantiate()
	add_child(town_shell)
	await get_tree().process_frame
	await get_tree().process_frame

	var snapshot: Dictionary = SaveService.validation_general_profile_log_snapshot()
	if int(snapshot.get("record_count", 0)) < 2:
		_fail("General profile log did not receive save and town records.", snapshot)
		return
	var records: Array = SaveService.validation_general_profile_log_last_records(20)
	if not _assert_json_valid_records(records):
		return
	var save_record := _find_record(records, "save", "autosave", "runtime_save")
	if save_record.is_empty():
		_fail("General profile log did not include a runtime autosave record.", records)
		return
	if not _assert_save_record(save_record):
		return
	var town_record := _find_surface_phase(records, "town", "entry")
	if town_record.is_empty():
		_fail("General profile log did not include a town entry record.", records)
		return
	if not _assert_town_record(town_record):
		return

	SaveService.validation_clear_general_profile_log()
	OS.set_environment("HEROES_PROFILE_LOG", previous_general)
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"log_path": String(snapshot.get("path", "")),
		"absolute_path": String(snapshot.get("absolute_path", "")),
		"save_buckets": save_record.get("buckets_ms", {}),
		"town_buckets": town_record.get("buckets_ms", {}),
	})])
	get_tree().quit(0)

func _assert_json_valid_records(records: Array) -> bool:
	for record in records:
		if not (record is Dictionary):
			_fail("General profile log returned a non-dictionary record.", {"record": record})
			return false
		var encoded := JSON.stringify(record)
		var parsed = JSON.parse_string(encoded)
		if not (parsed is Dictionary):
			_fail("General profile record was not JSON round-trip safe.", {"record": record})
			return false
		for key in ["schema", "timestamp_utc", "monotonic_msec", "surface", "phase", "event", "total_ms", "buckets_ms", "metadata", "session"]:
			if not (record as Dictionary).has(key):
				_fail("General profile record missing required key %s." % key, record)
				return false
	return true

func _assert_save_record(record: Dictionary) -> bool:
	if String(record.get("schema", "")) != "heroes_like.profile.v1":
		_fail("Save profile record used the wrong schema.", record)
		return false
	var buckets: Dictionary = record.get("buckets_ms", {}) if record.get("buckets_ms", {}) is Dictionary else {}
	for key in ["to_dict", "restore_normalize", "save_normalize", "stringify", "write"]:
		if not buckets.has(key):
			_fail("Save profile record missing bucket %s." % key, record)
			return false
	var metadata: Dictionary = record.get("metadata", {}) if record.get("metadata", {}) is Dictionary else {}
	if String(metadata.get("slot_type", "")) != "autosave":
		_fail("Save profile record did not identify the autosave slot type.", record)
		return false
	if bool(metadata.get("include_summary", true)):
		_fail("Save profile record should preserve include_summary=false for this regression.", record)
		return false
	return true

func _assert_town_record(record: Dictionary) -> bool:
	var buckets: Dictionary = record.get("buckets_ms", {}) if record.get("buckets_ms", {}) is Dictionary else {}
	for key in ["normalize_overworld", "configure_save_surface", "first_refresh"]:
		if not buckets.has(key):
			_fail("Town entry profile record missing bucket %s." % key, record)
			return false
	var metadata: Dictionary = record.get("metadata", {}) if record.get("metadata", {}) is Dictionary else {}
	if not bool(metadata.get("first_render", false)):
		_fail("Town entry profile record did not mark first_render.", record)
		return false
	if String(metadata.get("town_placement_id", "")) == "":
		_fail("Town entry profile record did not include the town placement id.", record)
		return false
	return true

func _find_record(records: Array, surface: String, phase: String, event: String) -> Dictionary:
	for record in records:
		if record is Dictionary and String(record.get("surface", "")) == surface and String(record.get("phase", "")) == phase and String(record.get("event", "")) == event:
			return record
	return {}

func _find_surface_phase(records: Array, surface: String, phase: String) -> Dictionary:
	for record in records:
		if record is Dictionary and String(record.get("surface", "")) == surface and String(record.get("phase", "")) == phase:
			return record
	return {}

func _first_player_town(session) -> Dictionary:
	for candidate in session.overworld.get("towns", []):
		if candidate is Dictionary and String(candidate.get("owner", "")) == "player":
			return candidate
	return {}

func _move_active_hero_to_town(session, town: Dictionary) -> void:
	var position := {"x": int(town.get("x", 0)), "y": int(town.get("y", 0))}
	session.overworld["hero_position"] = position.duplicate(true)
	var active_hero = session.overworld.get("hero", {})
	if active_hero is Dictionary:
		active_hero["position"] = position.duplicate(true)
		session.overworld["hero"] = active_hero
	var heroes = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		var hero = heroes[index]
		if hero is Dictionary and String(hero.get("id", "")) == String(session.overworld.get("active_hero_id", "")):
			hero["position"] = position.duplicate(true)
			heroes[index] = hero
	session.overworld["player_heroes"] = heroes

func _fail(message: String, details: Variant = {}) -> void:
	push_error("%s: %s %s" % [REPORT_ID, message, JSON.stringify(details)])
	get_tree().quit(1)
