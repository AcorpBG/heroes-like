extends Node
## The same seed gives the same generated map: the native generator
## (MapPackageService) run twice on one config gives the same map, scenario and
## new game, and another seed gives another map.

const SessionBridgeScript = preload("res://scripts/persistence/NativeRandomMapPackageSessionBridge.gd")
const REPORT_ID := "RANDOM_MAP_SEEDED_GENERATOR_CORE_REPORT"
const SEED := "10184"
const OTHER_SEED := "10185"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ClassDB.class_exists("MapPackageService"):
		_fail("The native MapPackageService is not loaded.")
		return
	var service: Variant = ClassDB.instantiate("MapPackageService")
	var first := _generate(service, SEED)
	var second := _generate(service, SEED)
	var other := _generate(service, OTHER_SEED)
	if first.is_empty() or second.is_empty() or other.is_empty():
		return
	for key in ["map_hash", "scenario_hash", "object_count", "game"]:
		if first[key] != second[key]:
			_fail("The same seed gave another %s." % key)
			return
	if first["map_hash"] == other["map_hash"]:
		_fail("Another seed gave the same map.")
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"map_hash": first["map_hash"],
		"other_seed_map_hash": other["map_hash"],
		"object_count": first["object_count"],
	})])
	get_tree().quit(0)

## One generation's map and scenario hashes, object count and new game.
func _generate(service: Variant, seed: String) -> Dictionary:
	var generated: Dictionary = service.generate_random_map(_config(seed), {"startup_path": REPORT_ID})
	if not bool(generated.get("ok", false)):
		_fail("Seed %s did not generate: %s" % [seed, String(generated.get("message", generated.get("status", "")))])
		return {}
	var adoption: Dictionary = service.convert_generated_payload(generated, {"feature_gate": REPORT_ID})
	if not bool(adoption.get("ok", false)):
		_fail("Seed %s did not convert into packages." % seed)
		return {}
	var session = SessionBridgeScript.build_session_from_adoption(adoption)
	if session == null or session.scenario_id == "":
		_fail("Seed %s did not start a game." % seed)
		return {}
	var identity: Dictionary = adoption.get("generated_identity", {})
	return {
		"map_hash": String(identity.get("map_hash", "")),
		"scenario_hash": String(identity.get("scenario_hash", "")),
		"object_count": int(adoption.get("map_document").get_object_count()),
		"game": JSON.stringify(session.to_dict()),
	}

func _config(seed: String) -> Dictionary:
	return {
		"seed": seed,
		"size": {"width": 36, "height": 36, "level_count": 1, "water_mode": "land", "size_class_id": "homm3_small"},
		"monster_strength": "normal",
		"player_constraints": {"human_count": 1, "computer_count": 2, "player_count": 3, "human_team_count": 1, "computer_team_count": 0},
	}

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
