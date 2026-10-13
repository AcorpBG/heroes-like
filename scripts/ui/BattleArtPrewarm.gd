extends RefCounted
## Loads a battle's board art on worker threads before the battle opens.
##
## Unit pose sheets are large lossless textures; decoding them on the main
## thread during the first board draw cost several hundred milliseconds. The
## overworld requests them when the battle approach starts and AppRouter when
## battle entry begins, so they load during the approach walk and the entry
## autosave. A board load() of a path still in flight waits for that request.
## The battle shell releases the requests once its board has drawn.

const BattleBoardViewScript = preload("res://scenes/battle/BattleBoardView.gd")

static var _requested: Dictionary = {}
static var _validation_force_enabled := false
static var _request_count := 0
static var _released_count := 0


static func request_for_battle(battle: Dictionary) -> int:
	if battle.is_empty() or not _enabled():
		return 0
	var started := 0
	for path in BattleBoardViewScript.art_texture_paths_for_battle(battle):
		if _requested.has(path) or ResourceLoader.has_cached(path):
			continue
		if not ResourceLoader.exists(path, "Texture2D"):
			continue
		if ResourceLoader.load_threaded_request(path, "Texture2D") == OK:
			_requested[path] = Time.get_ticks_msec()
			started += 1
	_request_count += started
	return started


## Collects every request so the loader drops its references; the board keeps
## its own. After the first battle frame the board has already waited for its
## art, so this does not block there.
static func release() -> int:
	var collected := 0
	for path in _requested.keys():
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED or status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			ResourceLoader.load_threaded_get(path)
		collected += 1
	_requested.clear()
	_released_count += collected
	return collected


static func pending_paths() -> PackedStringArray:
	return PackedStringArray(_requested.keys())


static func validation_set_enabled(enabled: bool) -> void:
	_validation_force_enabled = enabled


static func validation_snapshot() -> Dictionary:
	return {
		"enabled": _enabled(),
		"pending_paths": pending_paths(),
		"request_count": _request_count,
		"released_count": _released_count,
	}


static func _enabled() -> bool:
	# Headless runs present nothing; they keep loading on demand.
	return _validation_force_enabled or DisplayServer.get_name() != "headless"
