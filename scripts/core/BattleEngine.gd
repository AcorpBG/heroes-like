extends RefCounted
## The native battle engine's switch (docs/native-rules-engine-transition.md,
## Phase 1). HEROES_NATIVE_BATTLE picks who runs the battle functions ported
## so far (src/gdextension/rules/core/port/registry.cpp):
## - gdscript, the default: their GDScript bodies, renamed <name>__gd.
## - native: the native ports.
## - shadow: the GDScript bodies, with every call checked against the native
##   port: the result with its types, key order and container identities, and
##   for a function that writes into its arguments, the arguments afterwards.
## Mismatches go to push_error (the first 20) and, with HEROES_NATIVE_BATTLE_LOG
## set to a folder, with every function's counts into shadow_<pid>.json there.
## tools/native_battle_switch.py writes the switch into each ported function.

const NativeRules = preload("res://scripts/core/NativeRules.gd")

const GDSCRIPT := 0
const NATIVE := 1
const SHADOW := 2
const MODES := {"gdscript": GDSCRIPT, "native": NATIVE, "shadow": SHADOW}
const REPORTED_MISMATCHES := 20

static var mode: int = _mode_from_environment()
static var _reported := 0

static func _mode_from_environment() -> int:
	var name := OS.get_environment("HEROES_NATIVE_BATTLE").strip_edges().to_lower()
	if name == "":
		return GDSCRIPT
	if not MODES.has(name):
		push_error("HEROES_NATIVE_BATTLE=%s is none of gdscript, native, shadow; running GDScript." % name)
		return GDSCRIPT
	# Without the library every native call fails loudly; available() says why.
	NativeRules.available()
	return int(MODES[name])

## The native port's result.
static func native(name: StringName, args: Array) -> Variant:
	return NativeRules.api().battle_port_call(name, args, false)

## The native port of a function that writes into its arguments, writing into them.
static func native_writing(name: StringName, args: Array) -> Variant:
	return NativeRules.api().battle_port_call(name, args, true)

## Shadow: checks GDScript's result against the native port's.
static func check(name: StringName, args: Array, result: Variant) -> void:
	var mismatch: String = NativeRules.api().battle_port_check(name, args, result)
	if mismatch != "":
		_report(name, mismatch)

## Shadow, for a function that writes into its arguments: a copy of them as the
## GDScript call finds them.
static func before_writing(args: Array) -> Array:
	return args.duplicate(true)

## Shadow: runs the native port on before and checks that it returns GDScript's
## result and leaves before as the GDScript call left args.
static func check_writing(name: StringName, before: Array, args: Array, result: Variant) -> void:
	var native_result: Variant = NativeRules.api().battle_port_call(name, before, true)
	var mismatch := ""
	if var_to_bytes(native_result) != var_to_bytes(result):
		mismatch = "result: " + _first_difference(native_result, result, "result")
	elif var_to_bytes(before) != var_to_bytes(args):
		mismatch = "arguments afterwards: " + _first_difference(before, args, "args")
	NativeRules.api().battle_port_report(name, mismatch)
	if mismatch != "":
		_report(name, mismatch)

static func _report(name: StringName, mismatch: String) -> void:
	_reported += 1
	if _reported <= REPORTED_MISMATCHES:
		push_error("Battle shadow mismatch in %s: %s" % [name, mismatch])

static func _first_difference(native_value: Variant, gdscript_value: Variant, path: String) -> String:
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
	if var_to_bytes(native_value) != var_to_bytes(gdscript_value):
		return "%s: native %s, GDScript %s" % [path, str(native_value), str(gdscript_value)]
	return ""
