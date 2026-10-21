extends RefCounted
## The native day engine's switch (docs/native-rules-engine-transition.md,
## Phase 5). HEROES_NATIVE_DAY picks who runs the day-processing functions
## ported so far (src/gdextension/rules/core/port/day_registry.cpp):
## - gdscript, the default: their GDScript bodies, renamed <name>__gd.
## - native: the native ports.
## - shadow: the GDScript bodies, with every call checked against the native
##   port: the result with its types, key order and container identities, and
##   for a function that writes into its arguments, the arguments afterwards.
## A session reaches the native port as a view: a Dictionary of its fields, the
## very overworld, battle and flags Dictionaries among them, and its metadata
## under "meta". After a native call the session takes the view's fields back.
## Mismatches and native failures print a SCRIPT ERROR (the first 20), which
## fails rules_parity runs and the core suite, and, with HEROES_NATIVE_DAY_LOG
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
	var name := OS.get_environment("HEROES_NATIVE_DAY").strip_edges().to_lower()
	if name == "":
		return GDSCRIPT
	if not MODES.has(name):
		push_error("HEROES_NATIVE_DAY=%s is none of gdscript, native, shadow; running GDScript." % name)
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
	_take_views(args, views)
	return result

## Shadow: checks GDScript's result against the native port's.
static func check(name: StringName, args: Array, result: Variant) -> void:
	NativeRules.api().port_check(name, _views(args), result)

## Shadow, for a function that writes into its arguments: a copy of them as the
## GDScript call finds them, sessions as views. A container reached twice is
## one copy, so the native run changes nothing GDScript holds.
static func before_writing(args: Array) -> Array:
	return NativeRules.api().port_copy(_views(args))

## Shadow: runs the native port on before and checks that it returns GDScript's
## result and leaves before as the GDScript call left args.
static func check_writing(name: StringName, before: Array, args: Array, result: Variant) -> void:
	var native_result: Variant = NativeRules.api().port_call(name, before, true)
	var mismatch := _first_difference(native_result, result, "result")
	if mismatch != "":
		mismatch = "result: " + mismatch
	else:
		mismatch = _first_difference(before, _views(args), "args")
		if mismatch != "":
			mismatch = "arguments afterwards: " + mismatch
	NativeRules.api().port_report(name, mismatch)

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

static func _first_difference(native_value: Variant, gdscript_value: Variant, path: String) -> String:
	if var_to_bytes(native_value) == var_to_bytes(gdscript_value):
		return ""
	if typeof(native_value) != typeof(gdscript_value):
		return "%s: native %s %s, GDScript %s %s" % [path, type_string(typeof(native_value)), str(native_value), type_string(typeof(gdscript_value)), str(gdscript_value)]
	if native_value is Array:
		if native_value.size() != gdscript_value.size():
			return "%s: native %d items, GDScript %d" % [path, native_value.size(), gdscript_value.size()]
		for index in range(native_value.size()):
			var found := _first_difference(native_value[index], gdscript_value[index], "%s[%d]" % [path, index])
			if found != "":
				return found
		return ""
	if native_value is Dictionary:
		var native_keys: Array = native_value.keys()
		var gdscript_keys: Array = gdscript_value.keys()
		if var_to_bytes(native_keys) != var_to_bytes(gdscript_keys):
			return "%s: native keys %s, GDScript %s" % [path, str(native_keys), str(gdscript_keys)]
		for key in native_keys:
			var found := _first_difference(native_value[key], gdscript_value[key], "%s.%s" % [path, str(key)])
			if found != "":
				return found
		return ""
	return "%s: native %s, GDScript %s" % [path, str(native_value), str(gdscript_value)]
