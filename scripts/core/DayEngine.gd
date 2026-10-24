extends RefCounted
## The native day engine (docs/native-rules-engine-transition.md, Phase 5):
## the day-processing functions run as their native ports
## (src/gdextension/rules/core/port/day_registry.cpp). Since Phase 7's merge 3
## (owner decision D-d, 2026-10-24) there is no switch and no GDScript day:
## each is a thin wrapper over native() or native_writing(), and a path the
## port leaves out is a native failure (a SCRIPT ERROR).
## HumanEngine's switch, on a Phase 7 slice's branch, borrows the modes, the
## views and the shadow checks below:
## - shadow: the GDScript bodies, with every call checked against the native
##   port: the result with its types, key order and container identities. A
##   function that writes into its arguments has its native port run first, on
##   the arguments themselves and writing nothing back, then the GDScript body,
##   and the check compares the result and everything the native port loaded or
##   set (AurelionRules.port_validate_begin and port_validate_end).
## A session reaches the native port as a view: a Dictionary of its fields, the
## very overworld, battle and flags Dictionaries among them, its metadata
## under "meta" and its instance id under "instance_id". After a native call
## the session takes the view's fields back.
## In shadow mode every open check reads one view per session, brought up to
## date before each check.
## Mismatches and native failures print a SCRIPT ERROR (the first 20), which
## fails rules_parity runs and the core suite, and, with the subsystem's log
## folder set (HEROES_NATIVE_HUMAN_LOG), go with every function's counts into
## shadow_<pid>.json there.
## tools/native_battle_switch.py writes the wrappers and switches.

const NativeRules = preload("res://scripts/core/NativeRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const GDSCRIPT := 0
const NATIVE := 1
const SHADOW := 2
const MODES := {"gdscript": GDSCRIPT, "native": NATIVE, "shadow": SHADOW}
## The session fields a view carries, in SessionData's order.
const SESSION_FIELDS := [
	"save_version", "session_id", "scenario_id", "hero_id", "day", "difficulty", "launch_mode",
	"game_state", "scenario_status", "scenario_summary", "overworld", "battle", "flags",
]
const META := "meta"
## session.get_instance_id(), which the read scopes key their caches by.
const INSTANCE_ID := "instance_id"

## Shadow: the view of each session the checks read, by the session's instance
## id, kept while a check is open: the open checks' handles are below
## _open_handles (the other subsystems' checks share the numbering).
static var _shared_views := {}
static var _open_handles := 0
## Native mode: the functions whose calls keep the session's nodes from one
## call to the next (AurelionRules.port_session_call), so a call reads only
## what GDScript changed since. The AI match runner puts its day here, and
## between days changes the session only where it says so
## (port_session_reread).
static var session_calls := {}

## The native port's result.
static func native(name: StringName, args: Array) -> Variant:
	return NativeRules.api().port_call(name, _views(args), false)

## The native port of a function that writes into its arguments, writing into
## them; a session takes its view's fields back. A name in session_calls runs
## on the native session kept across calls.
static func native_writing(name: StringName, args: Array) -> Variant:
	var views := _views(args)
	var result: Variant
	if session_calls.has(name):
		result = NativeRules.api().port_session_call(name, views)
	else:
		result = NativeRules.api().port_call(name, views, true)
	_take_views(args, views)
	return result

## Shadow: checks GDScript's result against the native port's.
static func check(name: StringName, args: Array, result: Variant) -> void:
	NativeRules.api().port_check(name, _shared(args), result)

## Shadow: runs the native port first, on the arguments themselves, writing
## nothing back. The handle goes to check_writing.
static func before_writing(name: StringName, args: Array) -> int:
	var handle: int = NativeRules.api().port_validate_begin(name, _shared(args))
	_open_handles = maxi(_open_handles, handle + 1)
	return handle

## Shadow: checks that GDScript returned the native port's result and left the
## arguments and static vars as the native port would have.
static func check_writing(_name: StringName, before: int, args: Array, result: Variant) -> void:
	NativeRules.api().port_validate_end(before, result, _shared(args))
	if before >= 0:
		_open_handles = before
	if _open_handles == 0:
		_shared_views.clear()

## The arguments with each session as a new view (one view per session).
static func _views(args: Array) -> Array:
	var out := []
	var made := {}
	for value in args:
		if value is SessionStateStoreScript.SessionData:
			var id: int = value.get_instance_id()
			if not made.has(id):
				made[id] = _view(value)
			out.append(made[id])
		else:
			out.append(value)
	return out

## Shadow: the arguments with each session as its shared view, brought up to
## date with the session.
static func _shared(args: Array) -> Array:
	var out := []
	for value in args:
		if value is SessionStateStoreScript.SessionData:
			var id: int = value.get_instance_id()
			if _shared_views.has(id):
				_refresh_view(_shared_views[id], value)
			else:
				_shared_views[id] = _view(value)
			out.append(_shared_views[id])
		else:
			out.append(value)
	return out

static func _view(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var view := {}
	for field in SESSION_FIELDS:
		view[field] = session.get(field)
	var meta := {}
	for key in session.get_meta_list():
		meta[key] = session.get_meta(key)
	view[META] = meta
	view[INSTANCE_ID] = session.get_instance_id()
	return view

## The view takes the session's fields and metadata, in place.
static func _refresh_view(view: Dictionary, session: SessionStateStoreScript.SessionData) -> void:
	for field in SESSION_FIELDS:
		var value: Variant = session.get(field)
		if not is_same(view[field], value):
			view[field] = value
	var meta: Dictionary = view[META]
	var keys := session.get_meta_list()
	var same := meta.size() == keys.size()
	if same:
		var index := 0
		for key in meta:
			if StringName(key) != keys[index] or not is_same(meta[key], session.get_meta(keys[index])):
				same = false
				break
			index += 1
	if not same:
		meta.clear()
		for key in keys:
			meta[key] = session.get_meta(key)

## Each session takes its view's fields and metadata back.
static func _take_views(args: Array, views: Array) -> void:
	for index in range(args.size()):
		var session: Variant = args[index]
		if not (session is SessionStateStoreScript.SessionData):
			continue
		var view: Dictionary = views[index]
		for field in SESSION_FIELDS:
			if not is_same(session.get(field), view[field]):
				session.set(field, view[field])
		var meta: Dictionary = view[META]
		for key in session.get_meta_list():
			if not meta.has(key):
				session.remove_meta(key)
		for key in meta:
			if not session.has_meta(key) or not is_same(session.get_meta(key), meta[key]):
				session.set_meta(key, meta[key])
