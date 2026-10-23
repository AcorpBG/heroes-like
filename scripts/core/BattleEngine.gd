extends RefCounted
## The native battle engine's calls (docs/native-rules-engine-transition.md,
## Phase 2d). Battles run native: the functions of the battle port
## (src/gdextension/rules/core/port/registry.cpp) that GDScript still calls,
## the battle screen, the overworld and the tests, are thin wrappers that call
## their native port by name through native or native_writing. Their GDScript
## bodies and the HEROES_NATIVE_BATTLE switch are gone, so a battle change goes
## into the C++ port only. Native failures print a SCRIPT ERROR, which fails
## rules_parity runs and the core suite.
## Host calls: a native port calls a function the port leaves in GDScript (the
## HOST lines of registry.cpp) by name, with what the native call changed
## written back first.

const NativeRules = preload("res://scripts/core/NativeRules.gd")

## The native port's result.
static func native(name: StringName, args: Array) -> Variant:
	return NativeRules.api().port_call(name, args, false)

## The native port of a function that writes into its arguments, writing into them.
static func native_writing(name: StringName, args: Array) -> Variant:
	return NativeRules.api().port_call(name, args, true)
