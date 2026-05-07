extends Node

const RandomMapGeneratorRulesScript = preload("res://scripts/core/RandomMapGeneratorRules.gd")
const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const REPORT_ID := "RANDOM_MAP_PLAYER_COUNT_RANGE_REPORT"
const SMALL_DEFAULT_TEMPLATE_ID := "translated_rmg_template_049_v1"
const SMALL_DEFAULT_PROFILE_ID := "translated_rmg_profile_049_v1"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var setup_options := ScenarioSelectRulesScript.random_map_player_setup_options()
	var by_template: Dictionary = setup_options.get("player_count_options_by_template", {}) if setup_options.get("player_count_options_by_template", {}) is Dictionary else {}
	var compact_player_counts := ScenarioSelectRulesScript.random_map_player_count_options_for_template("border_gate_compact_v1")
	if not _arrays_equal(compact_player_counts, [3]):
		_fail("Small compact template did not preserve catalog player range [3]: %s" % JSON.stringify(compact_player_counts))
		return
	if not _arrays_equal(by_template.get("translated_rmg_template_043_v1", []), [5, 6, 7, 8]):
		_fail("XL translated template did not expose connected player range 5..8: %s" % JSON.stringify(by_template.get("translated_rmg_template_043_v1", [])))
		return

	var small_defaults := ScenarioSelectRulesScript.random_map_size_class_default("homm3_small")
	if String(small_defaults.get("template_id", "")) != SMALL_DEFAULT_TEMPLATE_ID or String(small_defaults.get("profile_id", "")) != SMALL_DEFAULT_PROFILE_ID:
		_fail("Small size defaults did not select recovered template 049: %s" % JSON.stringify(small_defaults))
		return
	if not _arrays_equal(small_defaults.get("player_counts", []), [2, 3, 4, 5, 6, 7]):
		_fail("Small recovered template did not expose translated player range 2..7: %s" % JSON.stringify(small_defaults))
		return
	var xl_defaults := ScenarioSelectRulesScript.random_map_size_class_default("homm3_extra_large")
	if int(xl_defaults.get("player_count", 0)) != 5:
		_fail("XL size default did not use the minimum connected translated player count 5: %s" % JSON.stringify(xl_defaults))
		return
	if not _arrays_equal(xl_defaults.get("player_counts", []), [5, 6, 7, 8]):
		_fail("XL size defaults did not expose connected translated 5..8 player counts: %s" % JSON.stringify(xl_defaults))
		return

	var compact_over_request := ScenarioSelectRulesScript.build_random_map_player_config(
		"player-count-range-compact-over-request",
		"border_gate_compact_v1",
		"border_gate_compact_profile_v1",
		8,
		"land",
		false,
		"homm3_small"
	)
	if int(compact_over_request.get("player_constraints", {}).get("player_count", 0)) != 3:
		_fail("Compact player-facing config did not clamp to its catalog-supported 3 players: %s" % JSON.stringify(compact_over_request.get("player_constraints", {})))
		return

	var accepted := []
	for player_count in [5, 6, 7, 8]:
		var normalized := RandomMapGeneratorRulesScript.normalize_config(_xl_config(int(player_count)))
		var selection: Dictionary = normalized.get("template_selection", {}) if normalized.get("template_selection", {}) is Dictionary else {}
		var constraints: Dictionary = normalized.get("player_constraints", {}) if normalized.get("player_constraints", {}) is Dictionary else {}
		var assignment: Dictionary = normalized.get("player_assignment", {}) if normalized.get("player_assignment", {}) is Dictionary else {}
		var constraint_report: Dictionary = selection.get("constraint_report", {}) if selection.get("constraint_report", {}) is Dictionary else {}
		if bool(selection.get("rejected", true)) or not bool(constraint_report.get("matches", false)):
			_fail("XL translated template rejected valid player_count=%d: %s" % [int(player_count), JSON.stringify(selection)])
			return
		if int(constraints.get("player_count", 0)) != int(player_count):
			_fail("XL config normalized player_count=%d to %s." % [int(player_count), JSON.stringify(constraints)])
			return
		if assignment.get("player_slots", []).size() != int(player_count):
			_fail("XL generator assignment did not create %d player slots: %s" % [int(player_count), JSON.stringify(assignment)])
			return
		accepted.append(int(player_count))

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"compact_player_counts": compact_player_counts,
		"xl_player_counts": by_template.get("translated_rmg_template_043_v1", []),
		"xl_default_player_count": int(xl_defaults.get("player_count", 0)),
		"accepted_xl_player_counts": accepted,
		"template_id": "translated_rmg_template_043_v1",
		"profile_id": "translated_rmg_profile_043_v1",
	})])
	get_tree().quit(0)

func _xl_config(player_count: int) -> Dictionary:
	return ScenarioSelectRulesScript.build_random_map_player_config(
		"player-count-range-xl-%d" % player_count,
		"translated_rmg_template_043_v1",
		"translated_rmg_profile_043_v1",
		player_count,
		"land",
		false,
		"homm3_extra_large"
	)

func _arrays_equal(left: Variant, right: Array) -> bool:
	if not (left is Array) or left.size() != right.size():
		return false
	for index in range(right.size()):
		if int(left[index]) != int(right[index]):
			return false
	return true

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
