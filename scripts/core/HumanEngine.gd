extends RefCounted
## The human seat's native port (docs/native-rules-engine-transition.md, Phase
## 7): the rules the screens call for the human player, moving to C++ slice by
## slice (src/gdextension/rules/core/port/human_registry.cpp). On a slice's
## branch HEROES_NATIVE_HUMAN picks who runs them (owner decision D-d, 2026-10-23):
## - native, the default (an unknown value too, with an error): the native ports.
## - gdscript: their GDScript bodies, renamed <name>__gd.
## - shadow: the GDScript bodies, with every call checked against the native
##   port, as DayEngine's shadow checks the day.
## The slice's merge deletes the GDScript bodies and their switches: the
## functions become thin wrappers over their native port (the registry's NATIVE
## entries, 7.1's since merge 1a), and no switch on main reads the mode. A
## session reaches the native
## port as DayEngine's view. A path the port leaves out is a native failure (a
## SCRIPT ERROR), in native and shadow mode. HEROES_NATIVE_HUMAN_LOG, set to a
## folder, collects every function's counts and mismatches there.
## tools/native_battle_switch.py writes the switch into each ported function.

const DayEngine = preload("res://scripts/core/DayEngine.gd")
const NativeRules = preload("res://scripts/core/NativeRules.gd")

const GDSCRIPT := DayEngine.GDSCRIPT
const NATIVE := DayEngine.NATIVE
const SHADOW := DayEngine.SHADOW

static var mode: int = _mode_from_environment()

static func _mode_from_environment() -> int:
	var name := OS.get_environment("HEROES_NATIVE_HUMAN").strip_edges().to_lower()
	if name == "":
		name = "native"
	elif not DayEngine.MODES.has(name):
		push_error("HEROES_NATIVE_HUMAN=%s is none of gdscript, native, shadow; running native." % name)
		name = "native"
	if name != "gdscript":
		NativeRules.available()
	return int(DayEngine.MODES[name])

## The native port's result.
static func native(name: StringName, args: Array) -> Variant:
	return DayEngine.native(name, args)

## The native port of a function that writes into its arguments (the caches in
## the session's metadata and the scripts' static vars), writing into them.
static func native_writing(name: StringName, args: Array) -> Variant:
	return DayEngine.native_writing(name, args)

## Shadow: checks GDScript's result against the native port's.
static func check(name: StringName, args: Array, result: Variant) -> void:
	DayEngine.check(name, args, result)

## Shadow: runs the native port first, on the arguments themselves, writing
## nothing back. The handle goes to check_writing.
static func before_writing(name: StringName, args: Array) -> int:
	return DayEngine.before_writing(name, args)

## Shadow: checks that GDScript returned the native port's result and left the
## arguments and static vars as the native port would have.
static func check_writing(name: StringName, before: int, args: Array, result: Variant) -> void:
	DayEngine.check_writing(name, before, args, result)
