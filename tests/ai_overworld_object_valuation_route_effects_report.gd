extends Node

const SCENARIO_ID := "river-pass"
const FACTION_ID := "faction_mireclaw"
const ORIGIN := {"x": 8, "y": 2}
const OBJECTIVE_GUARD := "river_pass_reed_totemists"
const ROUTE_BLOCK := "river_pass_hollow_mire"
const SCORE_LEAK_TOKENS := [
	"base_value",
	"object_metadata_value",
	"object_route_pressure_value",
	"priority_without_object_metadata",
	"priority_with_object_metadata",
	"final_priority",
	"final_score",
	"route_pressure_value",
	"guard_target_value",
	"clearance_value",
	"passability_value",
	"shape_mask_value",
]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var session = ScenarioFactory.create_session(
		SCENARIO_ID,
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	OverworldRules.normalize_overworld_state(session)
	var config := _enemy_config()
	if config.is_empty():
		return

	var report := EnemyAdventureRules.neutral_encounter_object_route_pressure_report(session, config, ORIGIN, FACTION_ID, 0)
	var targets: Array = report.get("targets", [])
	var objective_guard := _target_by_id(targets, OBJECTIVE_GUARD)
	var route_block := _target_by_id(targets, ROUTE_BLOCK)
	if objective_guard.is_empty():
		_fail("Missing object valuation target %s" % OBJECTIVE_GUARD)
		return
	if route_block.is_empty():
		_fail("Missing object valuation target %s" % ROUTE_BLOCK)
		return

	_assert_object_backed_route_pressure(objective_guard, true)
	_assert_object_backed_route_pressure(route_block, false)
	if _failed:
		return

	var public_event := _public_assignment_event(session, config, objective_guard)
	var public_leak_check := EnemyAdventureRules.commander_role_public_leak_check([public_event])
	if not bool(public_leak_check.get("ok", false)):
		_fail(String(public_leak_check.get("error", "public leak check failed")))
		return
	var event_text := JSON.stringify(public_event)
	for token in SCORE_LEAK_TOKENS:
		if event_text.contains(String(token)):
			_fail("Public object valuation event leaked score/debug token %s: %s" % [token, event_text])
			return

	var payload := {
		"ok": true,
		"scenario_id": SCENARIO_ID,
		"faction_id": FACTION_ID,
		"report_schema": String(report.get("schema", "")),
		"target_count": int(report.get("target_count", 0)),
		"top_targets": targets.slice(0, min(4, targets.size())),
		"objective_guard": objective_guard,
		"route_block": route_block,
		"public_assignment_event": public_event,
		"public_leak_check": public_leak_check,
		"case_pass_criteria": [
			"Object-backed neutral encounter metadata contributes positive internal valuation.",
			"Route-block and scenario-objective guard links produce route/objective reason codes.",
			"Body tiles and visit offsets overlap in the inside-footprint shape-mask contract.",
			"Public event output omits internal score fields.",
		],
	}
	print("AI_OVERWORLD_OBJECT_VALUATION_ROUTE_EFFECTS_REPORT %s" % JSON.stringify(payload))
	get_tree().quit(0)

var _failed := false

func _assert_object_backed_route_pressure(target: Dictionary, require_separate_shape_mask: bool) -> void:
	if not bool(target.get("object_backed", false)):
		_fail("%s was not object-backed in valuation report" % target.get("placement_id", ""))
		return
	if int(target.get("object_metadata_value", 0)) <= 0:
		_fail("%s did not receive positive object metadata value" % target.get("placement_id", ""))
		return
	if int(target.get("priority_with_object_metadata", 0)) <= int(target.get("priority_without_object_metadata", 0)):
		_fail("%s object metadata did not raise valuation: %s" % [target.get("placement_id", ""), target])
		return
	var reason_codes: Array = target.get("reason_codes", [])
	if "route_pressure" not in reason_codes and "objective_front" not in reason_codes:
		_fail("%s missed route/objective reason codes: %s" % [target.get("placement_id", ""), reason_codes])
		return
	if String(target.get("public_reason", "")) in SCORE_LEAK_TOKENS:
		_fail("%s public reason leaked score token %s" % [target.get("placement_id", ""), target.get("public_reason", "")])
		return
	if require_separate_shape_mask:
		var shape_mask: Dictionary = target.get("shape_mask_contract", {})
		if not bool(shape_mask.get("body_tiles_overlap_visit_offsets", false)):
			_fail("%s did not preserve inside-footprint body/visit overlap: %s" % [target.get("placement_id", ""), shape_mask])

func _public_assignment_event(session, config: Dictionary, target: Dictionary) -> Dictionary:
	var actor := {
		"placement_id": "object_valuation_probe",
		"name": "Object valuation probe",
		"target_kind": "encounter",
		"target_placement_id": String(target.get("placement_id", "")),
		"target_label": String(target.get("target_label", "")),
		"target_x": int(target.get("target_x", 0)),
		"target_y": int(target.get("target_y", 0)),
		"target_public_reason": String(target.get("public_reason", "")),
		"target_reason_codes": target.get("reason_codes", []),
		"target_public_importance": String(target.get("public_importance", "medium")),
		"target_debug_reason": String(target.get("debug_reason", "")),
	}
	return EnemyAdventureRules.ai_target_assignment_event(session, config, actor, {})

func _target_by_id(targets: Array, placement_id: String) -> Dictionary:
	for target in targets:
		if target is Dictionary and String(target.get("placement_id", "")) == placement_id:
			return target
	return {}

func _enemy_config() -> Dictionary:
	var scenario := ContentService.get_scenario(SCENARIO_ID)
	for config in scenario.get("enemy_factions", []):
		if config is Dictionary and String(config.get("faction_id", "")) == FACTION_ID:
			return config
	_fail("Could not find enemy config for %s" % FACTION_ID)
	return {}

func _fail(message: String) -> void:
	_failed = true
	var payload := {
		"ok": false,
		"scenario_id": SCENARIO_ID,
		"faction_id": FACTION_ID,
		"error": message,
	}
	push_error(message)
	print("AI_OVERWORLD_OBJECT_VALUATION_ROUTE_EFFECTS_REPORT %s" % JSON.stringify(payload))
	get_tree().quit(1)
