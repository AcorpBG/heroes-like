extends RefCounted
## The native battle engine's switch (docs/native-rules-engine-transition.md,
## Phase 1). HEROES_NATIVE_BATTLE picks who runs the battle functions ported
## so far (src/gdextension/rules/core/port/registry.cpp):
## - gdscript, the default: their GDScript bodies, renamed <name>__gd.
## - native: the native ports.
## - shadow: the GDScript bodies, with every call checked against the native
##   port: the result with its types, key order and container identities, and
##   for a function that writes into its arguments, the arguments afterwards.
## Mismatches and native failures print a SCRIPT ERROR (the first 20), which
## fails rules_parity runs and the core suite, and, with HEROES_NATIVE_BATTLE_LOG
## set to a folder, go with every function's counts into shadow_<pid>.json there.
## tools/native_battle_switch.py writes the switch into each ported function.

const NativeRules = preload("res://scripts/core/NativeRules.gd")

const GDSCRIPT := 0
const NATIVE := 1
const SHADOW := 2
const MODES := {"gdscript": GDSCRIPT, "native": NATIVE, "shadow": SHADOW}

static var mode: int = _mode_from_environment()

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
	return NativeRules.api().port_call(name, args, false)

## The native port of a function that writes into its arguments, writing into them.
static func native_writing(name: StringName, args: Array) -> Variant:
	return NativeRules.api().port_call(name, args, true)

## Shadow: checks GDScript's result against the native port's.
static func check(name: StringName, args: Array, result: Variant) -> void:
	NativeRules.api().port_check(name, args, result)

## Shadow, for a function that writes into its arguments: a copy of them as the
## GDScript call finds them. A container reached twice is one copy, and a
## RandomNumberGenerator or a session is copied too, so the native run changes
## nothing GDScript holds.
static func before_writing(args: Array) -> Array:
	return NativeRules.api().port_copy(args)

## Shadow: runs the native port on before and checks that it returns GDScript's
## result and leaves before as the GDScript call left args.
static func check_writing(name: StringName, before: Array, args: Array, result: Variant) -> void:
	var native_result: Variant = NativeRules.api().port_call(name, before, true)
	var mismatch := _first_difference(native_result, result, "result")
	if mismatch != "":
		mismatch = "result: " + mismatch
	else:
		mismatch = _first_difference(before, args, "args")
		if mismatch != "":
			mismatch = "arguments afterwards: " + mismatch
	NativeRules.api().port_report(name, mismatch)

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
	# Objects are copies on the native side: a RandomNumberGenerator matches by
	# seed and state, a session by its script variables.
	if native_value is RandomNumberGenerator and gdscript_value is RandomNumberGenerator:
		if native_value.seed != gdscript_value.seed or native_value.state != gdscript_value.state:
			return "%s: native seed %d state %d, GDScript seed %d state %d" % [path, native_value.seed, native_value.state, gdscript_value.seed, gdscript_value.state]
		return ""
	if native_value is Object and gdscript_value is Object and native_value.get_script() != null and native_value.get_script() == gdscript_value.get_script():
		for property in native_value.get_property_list():
			if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
				var found := _first_difference(native_value.get(property.name), gdscript_value.get(property.name), "%s.%s" % [path, property.name])
				if found != "":
					return found
		return ""
	return "%s: native %s, GDScript %s" % [path, str(native_value), str(gdscript_value)]
