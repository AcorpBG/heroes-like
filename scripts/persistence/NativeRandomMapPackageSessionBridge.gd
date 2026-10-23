class_name NativeRandomMapPackageSessionBridge
extends RefCounted

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const HumanEngine = preload("res://scripts/core/HumanEngine.gd")

static func build_session_from_adoption(adoption: Dictionary, difficulty: String = "normal", options: Dictionary = {}) -> SessionStateStoreScript.SessionData:
	return HumanEngine.native_writing(&"NativeRandomMapPackageSessionBridge.build_session_from_adoption", [adoption, difficulty, options])

## HoMM3 boats become boats waiting on their water tiles (WaterTravelRules).
static func boats_from_objects(objects: Array) -> Array:
	return HumanEngine.native_writing(&"NativeRandomMapPackageSessionBridge.boats_from_objects", [objects])
