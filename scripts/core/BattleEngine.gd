extends RefCounted
## The native battle engine's switch (docs/native-rules-engine-transition.md,
## Phase 1). HEROES_NATIVE_BATTLE picks who runs the battle functions
## (src/gdextension/rules/core/port/registry.cpp):
## - native, the default: the native ports.
## - gdscript: their GDScript bodies, renamed <name>__gd. Until the Phase 2
##   battle tool, the battle AI arena and its tuner run them (their router
##   swaps the GDScript BattleAiRules), and a battle change goes into both
##   copies (AGENTS.md).
## - shadow: the GDScript bodies, with every call checked against the native
##   port: the result with its types, key order and container identities, and
##   for a function that writes into its arguments or a memo, what it leaves.
##   Such a writing function's native port runs first, on the arguments
##   themselves and writing nothing back, so that it finds the memos (static
##   vars) as GDScript's call does; then the GDScript body runs, and the check
##   compares its result, every container the native port loaded, every static
##   var it read or set and every RandomNumberGenerator it rolled with what the
##   native port would have left (AurelionRules.port_validate_begin and
##   port_validate_end).
## Host calls: a native port calls a function the phase leaves in GDScript (the
## battle ends, the HOST lines of registry.cpp) by name, and in native mode it
## runs as GDScript with what the native call changed written back first. In
## shadow mode the native port stops at a host call, and the host function's
## wrapper checks it there instead (host_point).
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
		name = "native"
	if not MODES.has(name):
		push_error("HEROES_NATIVE_BATTLE=%s is none of gdscript, native, shadow; running native." % name)
		name = "native"
	if int(MODES[name]) == GDSCRIPT:
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

## Shadow, for a writing function: runs the native port first, writing
## nothing back. The handle goes to check_writing.
static func before_writing(name: StringName, args: Array) -> int:
	return NativeRules.api().port_validate_begin(name, args)

## Shadow: checks that GDScript returned the native port's result and left
## the arguments, static vars and RandomNumberGenerators as the native port
## would have.
static func check_writing(_name: StringName, before: int, args: Array, result: Variant) -> void:
	NativeRules.api().port_validate_end(before, result, args)

## Shadow, in a host function's wrapper just before its body runs: every open
## check whose native run stopped at this host call is checked here, its
## arguments and what GDScript's call has left so far (port_validate_point).
static func host_point(name: StringName, args: Array) -> void:
	NativeRules.api().port_validate_point(name, args)
