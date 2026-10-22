extends RefCounted
## The native AI turn's switch (docs/native-rules-engine-transition.md, Phase
## 4). HEROES_NATIVE_TURN picks who runs the computer players' day
## (src/gdextension/rules/core/port/turn_registry.cpp):
## - gdscript, the default: the GDScript bodies, renamed <name>__gd.
## - native: EnemyTurnRules.run_enemy_turn runs native, every faction turn in
##   it. The turn's other switched functions run their GDScript bodies for
##   their callers outside the turn.
## - shadow: the GDScript bodies, with run_enemy_turn and the turn's switched
##   functions checked against their native ports: the native port runs first,
##   on the arguments themselves and writing nothing back, then the GDScript
##   body, and the check compares the result and everything the native port
##   loaded or set (AurelionRules.port_validate_begin and port_validate_end).
## A session reaches the native port as a view: a Dictionary of its fields, the
## very overworld, battle and flags Dictionaries among them, its metadata under
## "meta" and the session itself under "object". After a native call the
## session takes the view's fields back. In shadow mode every open check reads
## one view per session, brought up to date before each check and host point.
## Host calls: the turn's battles stay GDScript until Phase 1's merge. The
## native port calls them through host_call, which hands the target the session
## itself. In shadow mode the native port stops there, and the target's wrapper
## checks it (host_point).
## A path the port leaves to GDScript (state::NotPorted) runs the whole day in
## GDScript, if no host call came first; after one it is a native failure.
## Mismatches and native failures print a SCRIPT ERROR (the first 20), which
## fails rules_parity runs and the core suite, and, with HEROES_NATIVE_TURN_LOG
## set to a folder, go with every function's counts into shadow_<pid>.json there.
## tools/native_battle_switch.py writes the switch into each switched function.

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
const OBJECT := "object"
## The host functions the native ports call; their first argument names the
## target (turn_registry.cpp lists the targets).
const HOST_CALL := &"TurnEngine.host_call"
const PURE_HOST_CALL := &"TurnEngine.pure_host_call"
## The host targets that change nothing the native call holds (pure_host_call).
const PURE_TARGETS := [&"AiHeroRules._simulate_battle"]

static var mode: int = _mode_from_environment()
## Shadow: the view of each session the open checks read, by the session's
## instance id, and the open checks' views by their handles.
static var _shared_views := {}
static var _open_checks := []

static func _mode_from_environment() -> int:
	var name := OS.get_environment("HEROES_NATIVE_TURN").strip_edges().to_lower()
	if name == "":
		return GDSCRIPT
	if not MODES.has(name):
		push_error("HEROES_NATIVE_TURN=%s is none of gdscript, native, shadow; running GDScript." % name)
		return GDSCRIPT
	# Without the library every native call fails loudly; available() says why.
	NativeRules.available()
	return int(MODES[name])

## The native port's result.
static func native(name: StringName, args: Array) -> Variant:
	return NativeRules.api().port_call(name, _views(args), false)

## The native port of a function that writes into its arguments, writing into
## them; a session takes its view's fields back.
static func native_writing(name: StringName, args: Array) -> Variant:
	var views := _views(args)
	var result: Variant = NativeRules.api().port_call(name, views, true)
	if not not_ported():
		_take_views(args, views)
	return result

## Whether the last native call reached a path the port leaves to GDScript.
static func not_ported() -> bool:
	return NativeRules.api().port_not_ported()

## Shadow: checks GDScript's result against the native port's.
static func check(name: StringName, args: Array, result: Variant) -> void:
	NativeRules.api().port_check(name, _shared(args), result)

## Shadow: runs the native port first, on the arguments themselves, writing
## nothing back. The handle goes to check_writing.
static func before_writing(name: StringName, args: Array) -> int:
	var views := _shared(args)
	var handle: int = NativeRules.api().port_validate_begin(name, views)
	if handle >= 0:
		if _open_checks.size() <= handle:
			_open_checks.resize(handle + 1)
		_open_checks[handle] = args
	return handle

## Shadow: checks that GDScript returned the native port's result and left the
## arguments and static vars as the native port would have.
static func check_writing(_name: StringName, before: int, args: Array, result: Variant) -> void:
	NativeRules.api().port_validate_end(before, result, _shared(args))
	if before >= 0:
		_open_checks.resize(before)
	if _open_checks.is_empty():
		_shared_views.clear()

## Shadow, in a host target's wrapper just before its body runs: every open
## check whose native run stopped at this host call is checked here
## (port_validate_point), as the native port calls it: host_call with the
## target's name, the session's view and the arguments.
static func host_point(name: StringName, args: Array) -> void:
	for open in _open_checks:
		if open is Array:
			_shared(open)
	var views := _shared(args)
	var session_view: Variant = null
	for index in range(args.size()):
		if args[index] is SessionStateStoreScript.SessionData:
			session_view = views[index]
			break
	NativeRules.api().port_validate_point(PURE_HOST_CALL if PURE_TARGETS.has(name) else HOST_CALL, [name, session_view, views])

## A host call of a native port: the session takes its view's fields, the
## target runs with the session in its view's place, and the view takes the
## session's fields back.
static func host_call(name: StringName, view: Variant, args: Array) -> Variant:
	var session: SessionStateStoreScript.SessionData = view.get(OBJECT) if view is Dictionary else null
	if session != null:
		_take_view(session, view)
	var call_args := []
	for value in args:
		call_args.append(session if session != null and value is Dictionary and is_same(value, view) else value)
	var dot := String(name).find(".")
	var script: Script = load("res://scripts/core/%s.gd" % String(name).substr(0, dot))
	var result: Variant = script.callv(String(name).substr(dot + 1), call_args)
	if session != null:
		_refresh_view(view, session)
	return result

## host_call of a target that changes nothing the native call holds: it reads
## the session's day and copies of its arguments and returns new containers,
## so the native call reads nothing again afterwards (PURE_TARGETS).
static func pure_host_call(name: StringName, view: Variant, args: Array) -> Variant:
	return host_call(name, view, args)

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
	view[OBJECT] = session
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
		if args[index] is SessionStateStoreScript.SessionData:
			_take_view(args[index], views[index])

static func _take_view(session: SessionStateStoreScript.SessionData, view: Dictionary) -> void:
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
