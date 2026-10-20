extends RefCounted
## The native rules library (src/gdextension/rules, docs/native-rules-engine-transition.md).
## One AurelionRules instance per process, reached by name, so the scripts still
## compile in a checkout that has not registered the extension yet. A checkout
## registers it with one `godot --headless --path . --import`.

const CLASS_NAME := "AurelionRules"
const REGISTER_HINT := "run `godot --headless --path . --import` once in this checkout to register src/gdextension/rules.gdextension"

static var _api: Object = null

## The AurelionRules instance. Null, with an error naming the fix, when the
## extension is not registered; the caller's next call on it then fails loudly.
static func api() -> Object:
	if _api == null:
		if not ClassDB.class_exists(CLASS_NAME):
			push_error("The native rules library is not loaded: %s." % REGISTER_HINT)
			return null
		_api = ClassDB.instantiate(CLASS_NAME)
	return _api

## For runners and tools before they start: false, with the fix printed, when
## the extension is not registered.
static func available() -> bool:
	if ClassDB.class_exists(CLASS_NAME):
		return true
	printerr("The native rules library is not loaded: %s." % REGISTER_HINT)
	return false

## {api, source_tree, godot_cpp, compiler, flavour} of the loaded library, or {}.
static func build_info() -> Dictionary:
	var rules := api()
	return rules.get_build_info() if rules != null else {}
