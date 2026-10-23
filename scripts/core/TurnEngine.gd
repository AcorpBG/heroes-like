extends RefCounted
## The native AI turn (docs/native-rules-engine-transition.md, Phase 4):
## EnemyTurnRules.run_enemy_turn runs the computer players' whole day in the
## rules library (src/gdextension/rules/core/port/turn_registry.cpp), every
## faction turn and battle in it. The functions of the AI turn's scripts that
## GDScript outside the turn still calls (the UI, day processing, battles,
## tests) are wrappers that call their native port here; the turn's other
## functions have no GDScript of their own, or keep a GDScript copy for their
## callers outside the turn (slice 4.4).
## A session reaches the native port as a view: a Dictionary of its fields, the
## very overworld, battle and flags Dictionaries among them, its metadata under
## "meta", the session itself under "object" and its instance id under
## "instance_id". After a native call the session takes the view's fields back.
## A path the port does not cover (none the game reaches) is a native failure:
## it prints a SCRIPT ERROR, and the session keeps the state the call started
## from. HEROES_NATIVE_TURN_LOG, set to a folder, collects the port's call
## counts there.

const NativeRules = preload("res://scripts/core/NativeRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

## The session fields a view carries, in SessionData's order.
const SESSION_FIELDS := [
	"save_version", "session_id", "scenario_id", "hero_id", "day", "difficulty", "launch_mode",
	"game_state", "scenario_status", "scenario_summary", "overworld", "battle", "flags",
]
const META := "meta"
const OBJECT := "object"
## session.get_instance_id(), which the read scopes key their caches by.
const INSTANCE_ID := "instance_id"

## The native port of a function that may write into its arguments, writing
## into them; a session takes its view's fields back.
static func native_writing(name: StringName, args: Array) -> Variant:
	var views := _views(args)
	var result: Variant = NativeRules.api().port_call(name, views, true)
	_take_views(args, views)
	return result

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
	view[OBJECT] = session
	view[INSTANCE_ID] = session.get_instance_id()
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
