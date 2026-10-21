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
##
## A capture also holds the content the port reads (the unit, hero, faction and spell rows by id and the files it
## loads) and its objects as markers: a RandomNumberGenerator as {"__g1_rng__": [seed, state]}, another object (the
## session) as {"__g1_object__": {property: blob id}} for the properties the port reads. battle_port_replay keeps the
## content resident and decodes a property that is also an argument as the same container.
##
## An entry of a function that writes (into its arguments or the memos) also holds the memos as they were before it,
## GDScript's static vars (_STATICS), and a signature of them after it. A memo container that is one of the entry's
## arguments, their "stacks" or presentation queue or a stack in it is {"__g1_arg__": path}; one that is none of
## them, where the port only asks whether it is one (the scope's battle, the queue last written, a scoring memo
## entry's stacks), is an empty placeholder; the specialty catalog built from the content is {"__g1_content__": path}
## and {"__g1_catalog_index__": path}. The board-read cache only grows inside a scope, so an entry holds the keys added
## since the last entry: [serial of the cache object, keys before, {added keys}]. The arena plays each side's
## BattleAiRules as its own compiled copy behind a router at the script's path, so a BattleAiRules wrapper hands over
## its copy's scoring memos; any other entry, which does not reach them, holds the path's or empty ones.

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
static var _content_bytes := PackedByteArray()

## The session properties the port reads (gd::member).
const _OBJECT_PROPERTIES := ["battle", "day", "difficulty", "session_id"]
## ContentService rows the port reads (gd::content_row), by table, and the files it loads (gd::content_file).
const _CONTENT_TABLES := {
	"unit": ["res://content/units.json", "get_unit"],
	"hero": ["res://content/heroes.json", "get_hero"],
	"faction": ["res://content/factions.json", "get_faction"],
	"spell": ["res://content/spells.json", "get_spell"],
}
const _CONTENT_FILES := ["res://content/hero_specialties.json"]
const _BATTLE_RULES := "res://scripts/core/BattleRules.gd"
const _BATTLE_AI_RULES := "res://scripts/core/BattleAiRules.gd"
const _HERO_PROGRESSION_RULES := "res://scripts/core/HeroProgressionRules.gd"
const _SPECIALTIES_PATH := "res://content/hero_specialties.json"
## The memos the port reads and writes, in the order of an entry's statics (battle_port_replay's kStatics).
const _STATICS := [
	[_BATTLE_RULES, "_presentation_queue_written"],
	[_BATTLE_RULES, "_board_read_scope_depth"],
	[_BATTLE_RULES, "_board_read_scope_battle"],
	[_BATTLE_RULES, "_validation_board_read_cache_disabled"],
	[_BATTLE_RULES, "_board_read_cache_hits"],
	[_BATTLE_RULES, "_board_read_scope_cache"],
	[_BATTLE_RULES, "_hero_payload_cache"],
	[_BATTLE_AI_RULES, "_scoring_scope_depth"],
	[_BATTLE_AI_RULES, "_scoring_living"],
	[_BATTLE_AI_RULES, "_scoring_stack_terms"],
	[_HERO_PROGRESSION_RULES, "_catalog_source"],
	[_HERO_PROGRESSION_RULES, "_catalog_index"],
]
static var _scripts := {}
static var _statics_id := -1
static var _ai_memos = null
static var _cache_ref = null
static var _cache_serial := 0
static var _cache_count := 0


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
		_cache_ref = null
		_cache_serial = 0
		_cache_count = 0
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
			"content": _content(),
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


## Mode "capture": the arguments of an outermost entry, as blob ids; for a writing function also the memos, with
## BattleAiRules' scoring memos as its wrapper hands them over ([depth, living, stack terms]).
static func capture_args(args: Array, writes := false, ai_memos = null) -> Array:
	depth = 1
	var ids: Array = []
	for value in args:
		ids.append(_blob(value))
	_ai_memos = ai_memos
	_statics_id = _statics_blob(args) if writes else -1
	return ids


## Mode "capture": the entry's result and, for a writing function, the arguments and the memos' signature after it.
static func capture_end(name: StringName, ids: Array, result, after: Array) -> void:
	var after_ids: Array = []
	for value in after:
		after_ids.append(_blob(value))
	var signature := _blob(_memo_signature()) if _statics_id >= 0 else -1
	_cap_entries.append([String(name), ids, _blob(result), after_ids, _statics_id, signature])
	_entries += 1
	depth = 0


static func _static(path: String, name: String):
	var script = _scripts.get(path)
	if script == null:
		script = load(path)
		_scripts[path] = script
	return script.get(name)


## The memos before an entry, as the blob id of their blob ids in _STATICS order.
static func _statics_blob(args: Array) -> int:
	var candidates := _alias_candidates(args)
	var items = ContentService.load_json(_SPECIALTIES_PATH).get("items")
	var catalog_warm: bool = items is Array and is_same(_static(_HERO_PROGRESSION_RULES, "_catalog_source"), items)
	var ids: Array = []
	for pair in _STATICS:
		var value = _ai_memo(pair[1]) if pair[0] == _BATTLE_AI_RULES else _static(pair[0], pair[1])
		match pair[1]:
			"_presentation_queue_written", "_board_read_scope_battle":
				var marker = _alias(value, candidates)
				if marker != null:
					value = marker
				else:
					value = [] if value is Array else {}
			"_board_read_scope_cache":
				value = _cache_delta(value)
			"_scoring_living":
				value = _mark_living(value, candidates)
			"_scoring_stack_terms":
				value = _mark_terms(value, candidates)
			"_catalog_source":
				if catalog_warm:
					value = {"__g1_content__": [_SPECIALTIES_PATH, "items"]}
				elif value is Array:
					value = []
			"_catalog_index":
				if catalog_warm:
					value = {"__g1_catalog_index__": _SPECIALTIES_PATH}
		ids.append(_blob(value))
	return _blob(ids)


## A scoring memo: the one the wrapper handed over, else the script's at its path, else an empty one.
static func _ai_memo(name: String):
	var index := ["_scoring_scope_depth", "_scoring_living", "_scoring_stack_terms"].find(name)
	if _ai_memos is Array:
		return _ai_memos[index]
	var value = _static(_BATTLE_AI_RULES, name)
	if index == 0:
		return value if value is int else 0
	return value if value is Dictionary else {}


## The containers a memo may hold of an entry's arguments, with their paths: each argument and the session's battle,
## a Dictionary's "stacks" and presentation queue, and each stack in its "stacks".
static func _alias_candidates(args: Array) -> Array:
	var found: Array = []
	for index in args.size():
		var arg = args[index]
		if arg is Object and not (arg is RandomNumberGenerator) and "battle" in arg:
			_add_candidates(found, arg.battle, [index, "battle"])
		else:
			_add_candidates(found, arg, [index])
	return found


static func _add_candidates(found: Array, value, path: Array) -> void:
	if not (value is Dictionary or value is Array):
		return
	found.append([value, path])
	if not (value is Dictionary):
		return
	for field in ["stacks", "battle_presentation_events"]:
		var inner = value.get(field)
		if not (inner is Array):
			continue
		found.append([inner, path + [field]])
		if field == "stacks":
			for item_index in inner.size():
				if inner[item_index] is Dictionary:
					found.append([inner[item_index], path + [field, item_index]])


static func _alias(value, candidates: Array):
	if not (value is Dictionary or value is Array):
		return null
	for candidate in candidates:
		if is_same(candidate[0], value):
			return {"__g1_arg__": candidate[1]}
	return null


## _scoring_living: an entry for the arguments' stacks with its living stacks as aliases; any other as a placeholder.
static func _mark_living(living: Dictionary, candidates: Array) -> Dictionary:
	var out := {}
	for side in living:
		var entries: Array = []
		for entry in living[side]:
			var stacks = _alias(entry[0], candidates)
			if stacks == null:
				entries.append([[], [], entry[2]])
				continue
			var alive: Array = []
			for stack in entry[1]:
				var marker = _alias(stack, candidates)
				alive.append(marker if marker != null else stack)
			entries.append([stacks, alive, entry[2]])
		out[side] = entries
	return out


## _scoring_stack_terms: each entry's stack and battle as aliases, or placeholders, and its value.
static func _mark_terms(terms: Dictionary, candidates: Array) -> Dictionary:
	var out := {}
	for key in terms:
		var entries: Array = []
		for entry in terms[key]:
			var stack = _alias(entry[0], candidates)
			var battle = _alias(entry[1], candidates)
			var marked: Array = [stack if stack != null else {}, battle if battle != null else {}]
			if entry.size() > 2:
				marked.append(entry[2])
			entries.append(marked)
		out[key] = entries
	return out


## The board-read cache's keys added since the last entry: [serial, keys before, {added keys}].
static func _cache_delta(cache: Dictionary) -> Array:
	if not is_same(cache, _cache_ref):
		_cache_ref = cache
		_cache_serial += 1
		_cache_count = 0
	var keys := cache.keys()
	var added := {}
	for index in range(_cache_count, keys.size()):
		added[keys[index]] = cache[keys[index]]
	var delta := [_cache_serial, _cache_count, added]
	_cache_count = keys.size()
	return delta


## After a writing entry: the board-read hits, the board-read cache's size, the term memo's entries and complete
## entries, the living memo's entries.
static func _memo_signature() -> Array:
	var terms := 0
	var complete := 0
	var term_memo: Dictionary = _ai_memo("_scoring_stack_terms")
	for key in term_memo:
		for entry in term_memo[key]:
			terms += 1
			if entry.size() == 3:
				complete += 1
	var living := 0
	var living_memo: Dictionary = _ai_memo("_scoring_living")
	for side in living_memo:
		living += living_memo[side].size()
	var cache: Dictionary = _static(_BATTLE_RULES, "_board_read_scope_cache")
	return [_static(_BATTLE_RULES, "_board_read_cache_hits"), cache.size(), terms, complete, living]


static func _blob(value) -> int:
	var bytes := var_to_bytes(_marked(value))
	var id: int = _blob_ids.get(bytes, -1)
	if id < 0:
		id = _blobs.size()
		_blobs.append(bytes)
		_blob_ids[bytes] = id
	return id


## A value as its blob holds it: an object as its marker.
static func _marked(value):
	if value is RandomNumberGenerator:
		return {"__g1_rng__": [value.seed, value.state]}
	if value is Object:
		var properties := {}
		for name in _OBJECT_PROPERTIES:
			if name in value:
				properties[name] = _blob(value.get(name))
		return {"__g1_object__": properties}
	return value


## The content the port reads, as var_to_bytes, once per process.
static func _content() -> PackedByteArray:
	if _content_bytes.is_empty():
		var content := {}
		for table in _CONTENT_TABLES:
			var source: Array = _CONTENT_TABLES[table]
			var raw: Dictionary = ContentService.load_json(source[0])
			var rows := {}
			for item in raw.get("items", raw.get("entries", [])):
				if item is Dictionary and item.has("id"):
					var id := String(item["id"])
					rows[id] = ContentService.call(source[1], id)
			content[table] = rows
		var files := {}
		for path in _CONTENT_FILES:
			files[path] = ContentService.load_json(path)
		content["files"] = files
		_content_bytes = var_to_bytes(content)
	return _content_bytes


## What the timing adds to each measured entry: one clock read and the assignment around it.
static func _timer_overhead() -> float:
	var rounds := 200000
	var total := 0
	for _index in rounds:
		var t0 := Time.get_ticks_usec()
		total += Time.get_ticks_usec() - t0
	return float(total) / float(rounds)
