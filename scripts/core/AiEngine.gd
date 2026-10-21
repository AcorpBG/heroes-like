extends RefCounted
## The native AI targets' switch (docs/native-rules-engine-transition.md,
## Phase 3). HEROES_NATIVE_AI picks who runs the AI functions ported so far
## (src/gdextension/rules/core/port/ai_registry.cpp):
## - gdscript, the default: their GDScript bodies, renamed <name>__gd.
## - native: the native ports. A path a port leaves to GDScript
##   (not_ported()) runs the GDScript body instead.
## - shadow: the GDScript bodies, each call checked against the native port.
##   The native port runs first, on the arguments themselves, and writes
##   nothing back; then the GDScript body runs, and the check compares its
##   result, every container the native port loaded and every static var it
##   read or set with what the native port would have left
##   (AurelionRules.port_validate_begin and port_validate_end). Copying a
##   session for every call would cost more than the game.
## A session reaches the native port as a view: a Dictionary of its fields, the
## very overworld, battle and flags Dictionaries among them, and its metadata
## under "meta". After a native call the session takes the view's fields back.
## Mismatches and native failures print a SCRIPT ERROR (the first 20), which
## fails rules_parity runs and the core suite, and, with HEROES_NATIVE_AI_LOG
## set to a folder, go with every function's counts into shadow_<pid>.json there.
## tools/native_battle_switch.py writes the switch into each ported function.

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

static var mode: int = _mode_from_environment()

static func _mode_from_environment() -> int:
	var name := OS.get_environment("HEROES_NATIVE_AI").strip_edges().to_lower()
	if name == "":
		return GDSCRIPT
	if not MODES.has(name):
		push_error("HEROES_NATIVE_AI=%s is none of gdscript, native, shadow; running GDScript." % name)
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
	if not NativeRules.api().port_not_ported():
		_take_views(args, views)
	return result

## Whether the last native call reached a path the port leaves to GDScript.
static func not_ported() -> bool:
	return NativeRules.api().port_not_ported()

## Shadow: checks GDScript's result against the native port's.
static func check(name: StringName, args: Array, result: Variant) -> void:
	NativeRules.api().port_check(name, _views(args), result)

## Shadow, for a function that writes into its arguments: runs the native port
## first, writing nothing back. The handle goes to check_writing.
static func before_writing(name: StringName, args: Array) -> int:
	return NativeRules.api().port_validate_begin(name, _views(args))

## Shadow: checks that GDScript returned the native port's result and left
## the arguments and static vars as the native port would have.
static func check_writing(_name: StringName, before: int, args: Array, result: Variant) -> void:
	NativeRules.api().port_validate_end(before, result, _views(args))

## The arguments with each session as its view (one view per session).
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

static func _view(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var view := {}
	for field in SESSION_FIELDS:
		view[field] = session.get(field)
	var meta := {}
	for key in session.get_meta_list():
		meta[key] = session.get_meta(key)
	view[META] = meta
	return view

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
