extends RefCounted
## Runtime of the battle port's G1 projection (tools/battle_port_g1/g1.py; docs/native-rules-engine-transition.md,
## Phase 1, "Checkpoint G1"). g1.py copies the game at the branch point, puts this script beside it and wraps:
##
## - BattleAutoResolveRules.resolve_active_battle: begin_resolve/end_resolve time each resolve;
## - the _finalize_* functions and _resolve_result (the payload): pause/resume leave them out of T_gd;
## - the ported functions, mode "ported": add() takes the outermost entry's inclusive time (T_gd_ported);
## - the ported functions, mode "capture": capture_args/capture_end keep the outermost entry's arguments and result.
##
## HEROES_G1_MODE picks the mode ("resolve", "ported" or "capture"), HEROES_G1_OUT the folder and
## HEROES_G1_CAPTURE_EVERY the share of resolves captured (those whose start digest is a multiple of it). Each process
## writes g1_<pid>.jsonl there, one line per resolve, and cap_<key>.bin per captured resolve.

static var mode: String = OS.get_environment("HEROES_G1_MODE")
static var out_dir: String = OS.get_environment("HEROES_G1_OUT")
static var capture_every: int = maxi(1, int(OS.get_environment("HEROES_G1_CAPTURE_EVERY")))

## Inside a resolve and outside its payload and finalize: ported entries count.
static var on := false
## Inside an outermost ported entry: the calls it makes are not entries.
static var depth := 0
## Capturing the current resolve.
static var capturing := false
## Wrappers reached inside an outermost entry, through a call the instrumenter could not point at the raw body (a
## function outside the set in between): timed with that entry, not counted as one.
static var reentries := 0
static var _reentered := {}

static var _resolve_depth := 0
static var _nested_resolves := 0
static var _active := false
static var _key := ""
static var _t0 := 0
static var _pause_depth := 0
static var _pause_t0 := 0
static var _paused_us := 0
static var _paused := false
static var _ported_us := 0
static var _entries := 0
static var _per_fn := {}
static var _blob_ids := {}
static var _blobs: Array = []
static var _cap_entries: Array = []
static var _start_bytes := PackedByteArray()
static var _end_bytes := PackedByteArray()
static var _seen := {}
static var _file: FileAccess = null


static func begin_resolve(session) -> void:
	_resolve_depth += 1
	if _resolve_depth > 1:
		_nested_resolves += 1
		return
	_active = mode != "" and session != null and not session.battle.is_empty()
	if not _active:
		return
	var bytes := var_to_bytes(session.battle)
	var digest := hash(bytes)
	var seen := int(_seen.get(digest, 0))
	_seen[digest] = seen + 1
	_key = "%d_%d" % [digest, seen]
	_pause_depth = 0
	_paused = false
	_paused_us = 0
	_ported_us = 0
	_entries = 0
	reentries = 0
	_reentered = {}
	_per_fn = {}
	capturing = mode == "capture" and posmod(digest, capture_every) == 0
	if capturing:
		_start_bytes = bytes
		_end_bytes = PackedByteArray()
		_blob_ids = {}
		_blobs = []
		_cap_entries = []
	on = true
	_t0 = Time.get_ticks_usec()


static func end_resolve(session) -> void:
	_resolve_depth -= 1
	if _resolve_depth > 0 or not _active:
		return
	var total := Time.get_ticks_usec() - _t0
	on = false
	_active = false
	var line := {
		"key": _key,
		"t_gd": total - _paused_us,
		"t_paused": _paused_us,
		"t_ported": _ported_us,
		"entries": _entries,
		"reentries": reentries,
		"reentered": _reentered,
		"nested_resolves": _nested_resolves,
		"per_fn": _per_fn,
	}
	if _file == null:
		DirAccess.make_dir_recursive_absolute(out_dir)
		_file = FileAccess.open(out_dir.path_join("g1_%d.jsonl" % OS.get_process_id()), FileAccess.WRITE)
		if mode == "ported":
			_file.store_line(JSON.stringify({"timer_overhead_us": _timer_overhead()}))
	if capturing:
		capturing = false
		if _end_bytes.is_empty() and session != null:
			_end_bytes = var_to_bytes(session.battle)
		line["captured"] = _cap_entries.size()
		var capture := FileAccess.open(out_dir.path_join("cap_%s.bin" % _key), FileAccess.WRITE)
		capture.store_buffer(var_to_bytes({
			"key": _key,
			"start": _start_bytes,
			"end": _end_bytes,
			"entries": _cap_entries,
			"blobs": _blobs,
		}))
		capture.close()
		_blob_ids = {}
		_blobs = []
		_cap_entries = []
	_file.store_line(JSON.stringify(line))
	_file.flush()


## A finalize function or the result payload: not part of T_gd. The first one sees the battle as the resolve leaves
## it, before a finalize clears it.
static func pause(session) -> void:
	_pause_depth += 1
	if _pause_depth != 1 or not on:
		return
	if capturing and _end_bytes.is_empty() and session != null and not session.battle.is_empty():
		_end_bytes = var_to_bytes(session.battle)
	on = false
	_paused = true
	_pause_t0 = Time.get_ticks_usec()


static func resume() -> void:
	_pause_depth -= 1
	if _pause_depth == 0 and _paused:
		_paused_us += Time.get_ticks_usec() - _pause_t0
		_paused = false
		on = true


## Mode "ported": one outermost entry of `name` took `usec`, timer included.
static func add(name: StringName, usec: int) -> void:
	depth = 0
	_entries += 1
	_ported_us += usec
	var slot = _per_fn.get(name)
	if slot == null:
		_per_fn[name] = [1, usec]
	else:
		slot[0] += 1
		slot[1] += usec


static func reentry(name: StringName) -> void:
	reentries += 1
	_reentered[name] = int(_reentered.get(name, 0)) + 1


## Mode "capture": the arguments of an outermost entry, as blob ids.
static func capture_args(args: Array) -> Array:
	depth = 1
	var ids: Array = []
	for value in args:
		ids.append(_blob(value))
	return ids


## Mode "capture": the entry's result and, for a function that writes into its arguments, the arguments after it.
static func capture_end(name: StringName, ids: Array, result, after: Array) -> void:
	var after_ids: Array = []
	for value in after:
		after_ids.append(_blob(value))
	_cap_entries.append([String(name), ids, _blob(result), after_ids])
	_entries += 1
	depth = 0


static func _blob(value) -> int:
	var bytes := var_to_bytes(value)
	var id: int = _blob_ids.get(bytes, -1)
	if id < 0:
		id = _blobs.size()
		_blobs.append(bytes)
		_blob_ids[bytes] = id
	return id


## What the timing adds to each measured entry: one clock read and the assignment around it.
static func _timer_overhead() -> float:
	var rounds := 200000
	var total := 0
	for _index in rounds:
		var t0 := Time.get_ticks_usec()
		total += Time.get_ticks_usec() - t0
	return float(total) / float(rounds)
