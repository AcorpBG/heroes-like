extends Node

const REPORT_ID := "TOWN_CAPITAL_PROJECT_IDENTITY_RUNTIME_REPORT"
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const CAPITAL_CASES := [
	{
		"scenario_id": "lockmarsh-surge",
		"placement_id": "highwater_keep",
		"town_id": "town_highwater_keep",
		"project_id": "building_charter_bastion",
	},
	{
		"scenario_id": "nightglass-redoubt",
		"placement_id": "nightglass_redoubt",
		"town_id": "town_nightglass_redoubt",
		"project_id": "building_nightglass_dominion",
	},
	{
		"scenario_id": "glassfen-breakers",
		"placement_id": "prismhearth_array",
		"town_id": "town_prismhearth",
		"project_id": "building_daybreak_matrix",
	},
]

const PROJECT_ABSENT_CASES := [
	{
		"scenario_id": "mireford-skirmish",
		"placement_id": "graftroot_bridgehead",
		"town_id": "town_thornwake_graftroot_caravan",
	},
	{
		"scenario_id": "orevein-contract",
		"placement_id": "orevein_gantry",
		"town_id": "town_brasshollow_orevein_gantry",
	},
]

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ContentService.clear_cache()
	var save_version_before := int(SessionStateStore.SAVE_VERSION)
	var capital_rows := []
	for fixture in CAPITAL_CASES:
		var row := _capital_identity_case(fixture)
		if row.is_empty():
			return
		capital_rows.append(row)
	var absent_rows := []
	for fixture in PROJECT_ABSENT_CASES:
		var row := _project_absent_case(fixture)
		if row.is_empty():
			return
		absent_rows.append(row)
	if save_version_before != 9 or int(SessionStateStore.SAVE_VERSION) != save_version_before:
		_fail("Capital-project identity correction changed save version 9.")
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"report_id": REPORT_ID,
		"capital_rows": capital_rows,
		"project_absent_rows": absent_rows,
		"authored_project_count": capital_rows.size(),
		"save_version": save_version_before,
		"session_authority_exact": true,
	})])
	get_tree().quit(0)

func _capital_identity_case(fixture: Dictionary) -> Dictionary:
	var session: SessionStateStoreScript.SessionData = ScenarioFactory.create_session(
		String(fixture.get("scenario_id", "")),
		"normal",
		SessionStateStoreScript.LAUNCH_MODE_SKIRMISH
	)
	if session == null:
		_fail("ScenarioFactory returned null for %s." % String(fixture.get("scenario_id", "")))
		return {}
	OverworldRules.normalize_overworld_state(session)
	var authority_before: Dictionary = session.to_dict()
	var town := _town_by_placement(session, String(fixture.get("placement_id", "")))
	var town_id := String(fixture.get("town_id", ""))
	var project_id := String(fixture.get("project_id", ""))
	if String(town.get("town_id", "")) != town_id:
		_fail("Capital fixture did not materialize %s: %s" % [town_id, JSON.stringify(town)])
		return {}
	var explicit_ids := _explicit_project_ids(town_id)
	var runtime_ids: Array = OverworldRules._town_capital_project_ids(town)
	if explicit_ids != [project_id] or runtime_ids != explicit_ids:
		_fail("Capital project identity mismatch for %s: explicit=%s runtime=%s" % [town_id, JSON.stringify(explicit_ids), JSON.stringify(runtime_ids)])
		return {}
	var project := ContentService.get_building(project_id)
	var project_metadata: Dictionary = project.get("capital_project", {})
	var dependencies: Array = _string_array(project.get("requires", []))
	if project_metadata.is_empty() or dependencies.is_empty():
		_fail("Capital fixture lacks authored metadata or dependencies for %s." % project_id)
		return {}
	var initial_state: Dictionary = OverworldRules.town_capital_project_state(town, session)
	var initial_built: Array = _string_array(town.get("built_buildings", []))
	var initial_dependency_complete := 0
	var expected_next_label := ""
	for dependency_id in dependencies:
		if dependency_id in initial_built:
			initial_dependency_complete += 1
		elif expected_next_label == "":
			expected_next_label = String(ContentService.get_building(String(dependency_id)).get("name", dependency_id))
	if expected_next_label == "":
		expected_next_label = String(project.get("name", project_id))
	if not _inactive_state_exact(initial_state, project_id, dependencies.size() + 1, initial_dependency_complete, expected_next_label):
		_fail("Initial capital state counted an ordinary building for %s: %s" % [town_id, JSON.stringify(initial_state)])
		return {}
	var initial_summary := _town_summary_for(session, String(fixture.get("placement_id", "")), false, dependencies, "")
	if initial_summary == "" or not initial_summary.contains("Capital project %d/%d" % [initial_dependency_complete, dependencies.size() + 1]) or not initial_summary.contains("Next %s" % expected_next_label):
		_fail("Initial TownRules summary did not name the exact authored capital dependency for %s: %s" % [town_id, initial_summary])
		return {}
	if initial_summary.contains("Next Market Square") and expected_next_label != "Market Square":
		_fail("Initial TownRules summary retained the false ordinary Market Square project for %s." % town_id)
		return {}
	var active_session: SessionStateStoreScript.SessionData = _session_with_completed_project(session, String(fixture.get("placement_id", "")), dependencies, project_id)
	if active_session == null:
		return {}
	var active_town := _town_by_placement(active_session, String(fixture.get("placement_id", "")))
	var active_state: Dictionary = OverworldRules.town_capital_project_state(active_town, active_session)
	var active_checks := _active_state_checks(active_state, project_id, project_metadata, dependencies.size() + 1)
	if not _all_checks_true(active_checks):
		_fail("Completed capital state did not expose only authored project values for %s: checks=%s state=%s" % [town_id, JSON.stringify(active_checks), JSON.stringify(active_state)])
		return {}
	if not _vulnerability_exact(active_state, project_metadata):
		_fail("Completed capital vulnerability did not derive from authored project support for %s: %s" % [town_id, JSON.stringify(active_state)])
		return {}
	var active_summary := _town_summary_for(active_session, String(fixture.get("placement_id", "")), true, [], project_id)
	if active_summary == "" or not active_summary.contains("Capital project online %d/%d" % [dependencies.size() + 1, dependencies.size() + 1]) or not active_summary.contains(String(project_metadata.get("summary", ""))):
		_fail("Completed TownRules summary did not expose the exact authored project for %s: %s" % [town_id, active_summary])
		return {}
	var normalized := SessionStateStoreScript.new_session_data()
	normalized.from_dict(active_session.to_dict().duplicate(true))
	var normalized_town := _town_by_placement(normalized, String(fixture.get("placement_id", "")))
	var normalized_state: Dictionary = OverworldRules.town_capital_project_state(normalized_town, normalized)
	if normalized_state != active_state:
		_fail("Save normalization changed capital project state for %s: before=%s after=%s" % [town_id, JSON.stringify(active_state), JSON.stringify(normalized_state)])
		return {}
	if session.to_dict() != authority_before:
		_fail("Capital-project readers changed source session authority for %s." % town_id)
		return {}
	return {
		"scenario_id": String(fixture.get("scenario_id", "")),
		"placement_id": String(fixture.get("placement_id", "")),
		"town_id": town_id,
		"project_ids": runtime_ids,
		"initial_active": false,
		"initial_quality_bonus": int(initial_state.get("quality_bonus", -1)),
		"initial_progress": [int(initial_state.get("progress_complete", -1)), int(initial_state.get("progress_total", -1))],
		"initial_next_label": String(initial_state.get("next_label", "")),
		"active_ids": active_state.get("active_ids", []),
		"active_quality_bonus": int(active_state.get("quality_bonus", -1)),
		"active_progress": [int(active_state.get("progress_complete", -1)), int(active_state.get("progress_total", -1))],
		"save_normalization_exact": true,
		"town_summary_exact": true,
	}

func _project_absent_case(fixture: Dictionary) -> Dictionary:
	var session: SessionStateStoreScript.SessionData = ScenarioFactory.create_session(
		String(fixture.get("scenario_id", "")),
		"normal",
		SessionStateStoreScript.LAUNCH_MODE_SKIRMISH
	)
	if session == null:
		_fail("ScenarioFactory returned null for project-absent %s." % String(fixture.get("scenario_id", "")))
		return {}
	OverworldRules.normalize_overworld_state(session)
	var authority_before: Dictionary = session.to_dict()
	var placement_id := String(fixture.get("placement_id", ""))
	var town_id := String(fixture.get("town_id", ""))
	var town := _town_by_placement(session, placement_id)
	if String(town.get("town_id", "")) != town_id:
		_fail("Project-absent fixture did not materialize %s." % town_id)
		return {}
	var explicit_ids := _explicit_project_ids(town_id)
	var runtime_ids: Array = OverworldRules._town_capital_project_ids(town)
	var state: Dictionary = OverworldRules.town_capital_project_state(town, session)
	if not explicit_ids.is_empty() or not runtime_ids.is_empty() or not _absent_state_exact(state):
		_fail("Project-absent town exposed capital state for %s: explicit=%s runtime=%s state=%s" % [town_id, JSON.stringify(explicit_ids), JSON.stringify(runtime_ids), JSON.stringify(state)])
		return {}
	var summary := _town_summary_for(session, placement_id, false, [], "")
	if summary == "" or summary.contains("Capital project"):
		_fail("Project-absent TownRules summary exposed capital text for %s: %s" % [town_id, summary])
		return {}
	if session.to_dict() != authority_before:
		_fail("Project-absent readers changed source session authority for %s." % town_id)
		return {}
	return {
		"scenario_id": String(fixture.get("scenario_id", "")),
		"placement_id": placement_id,
		"town_id": town_id,
		"project_ids": runtime_ids,
		"state_total": int(state.get("total", -1)),
		"capital_summary_absent": true,
		"session_authority_exact": true,
	}

func _explicit_project_ids(town_id: String) -> Array:
	var output := []
	var template := ContentService.get_town(town_id)
	for building_id_value in template.get("buildable_building_ids", []):
		var building_id := String(building_id_value)
		var building := ContentService.get_building(building_id)
		if not building.has("capital_project"):
			continue
		var metadata: Variant = building.get("capital_project", null)
		if metadata is Dictionary and not metadata.is_empty():
			output.append(building_id)
	return output

func _inactive_state_exact(state: Dictionary, project_id: String, progress_total: int, progress_complete: int, next_label: String) -> bool:
	return int(state.get("total", -1)) == 1 \
		and not bool(state.get("active", true)) \
		and state.get("active_ids", null) == [] \
		and String(state.get("primary_project_id", "")) == project_id \
		and int(state.get("progress_total", -1)) == progress_total \
		and int(state.get("progress_complete", -1)) == progress_complete \
		and String(state.get("next_label", "")) == next_label \
		and _zero_project_effects(state)

func _active_state_checks(state: Dictionary, project_id: String, metadata: Dictionary, progress_total: int) -> Dictionary:
	return {
		"total": int(state.get("total", -1)) == 1,
		"active": bool(state.get("active", false)),
		"active_ids": state.get("active_ids", null) == [project_id],
		"primary": String(state.get("primary_project_id", "")) == project_id,
		"progress_total": int(state.get("progress_total", -1)) == progress_total,
		"progress_complete": int(state.get("progress_complete", -1)) == progress_total,
		"next_label": String(state.get("next_label", "not-empty")) == "",
		"quality_bonus": int(state.get("quality_bonus", -1)) == 12,
		"pressure_bonus": int(state.get("pressure_bonus", -1)) == int(metadata.get("pressure_bonus", -2)),
		"defense_bonus": int(state.get("defense_bonus", -1)) == int(metadata.get("defense_bonus", -2)),
		"raid_threshold_reduction": int(state.get("raid_threshold_reduction", -1)) == int(metadata.get("raid_threshold_reduction", -2)),
		"max_active_raids_bonus": int(state.get("max_active_raids_bonus", -1)) == int(metadata.get("max_active_raids_bonus", -2)),
		"recovery_guard": int(state.get("recovery_guard", -1)) == int(metadata.get("recovery_guard", -2)),
		"summary": String(state.get("summary", "")) == String(metadata.get("summary", "")),
		"support_requirements": _integer_dictionary_exact(state.get("support_requirements", null), metadata.get("support_requirements", null)),
	}

func _all_checks_true(checks: Dictionary) -> bool:
	for value in checks.values():
		if not bool(value):
			return false
	return true

func _integer_dictionary_exact(actual: Variant, expected: Variant) -> bool:
	if not (actual is Dictionary) or not (expected is Dictionary) or actual.size() != expected.size():
		return false
	for key in expected.keys():
		if not actual.has(key) or int(actual.get(key, -1)) != int(expected.get(key, -2)):
			return false
	return true

func _vulnerability_exact(state: Dictionary, metadata: Dictionary) -> bool:
	var penalties: Dictionary = metadata.get("vulnerability_penalties", {})
	if not bool(state.get("vulnerable", false)):
		return int(state.get("quality_penalty", -1)) == 0 \
			and int(state.get("readiness_penalty", -1)) == 0 \
			and int(state.get("pressure_penalty", -1)) == 0 \
			and int(state.get("growth_penalty_percent", -1)) == 0
	var quality_base := int(penalties.get("quality_penalty", 0))
	var quality_actual := int(state.get("quality_penalty", -1))
	if quality_base <= 0 or quality_actual <= 0 or quality_actual % quality_base != 0:
		return false
	var steps: int = quality_actual / quality_base
	return int(state.get("readiness_penalty", -1)) == int(penalties.get("readiness_penalty", -2)) * steps \
		and int(state.get("pressure_penalty", -1)) == int(penalties.get("pressure_penalty", -2)) * steps \
		and int(state.get("growth_penalty_percent", -1)) == int(penalties.get("growth_penalty_percent", -2)) * steps

func _zero_project_effects(state: Dictionary) -> bool:
	for key in ["pressure_bonus", "defense_bonus", "quality_bonus", "recovery_guard", "raid_threshold_reduction", "max_active_raids_bonus", "quality_penalty", "readiness_penalty", "pressure_penalty", "growth_penalty_percent"]:
		if int(state.get(key, -1)) != 0:
			return false
	return not bool(state.get("vulnerable", true))

func _absent_state_exact(state: Dictionary) -> bool:
	return int(state.get("total", -1)) == 0 \
		and not bool(state.get("active", true)) \
		and state.get("active_ids", null) == [] \
		and String(state.get("primary_project_id", "not-empty")) == "" \
		and int(state.get("progress_complete", -1)) == 0 \
		and int(state.get("progress_total", -1)) == 0 \
		and String(state.get("next_label", "not-empty")) == "" \
		and _zero_project_effects(state)

func _session_with_completed_project(session: SessionStateStoreScript.SessionData, placement_id: String, dependencies: Array, project_id: String) -> SessionStateStoreScript.SessionData:
	var clone := SessionStateStoreScript.new_session_data()
	clone.from_dict(session.to_dict().duplicate(true))
	var towns: Array = clone.overworld.get("towns", []).duplicate(true)
	var found := false
	for index in range(towns.size()):
		var town = towns[index]
		if not (town is Dictionary) or String(town.get("placement_id", "")) != placement_id:
			continue
		var updated: Dictionary = town.duplicate(true)
		var built: Array = _string_array(updated.get("built_buildings", []))
		for building_id in dependencies + [project_id]:
			if String(building_id) not in built:
				built.append(String(building_id))
		updated["built_buildings"] = built
		updated["owner"] = "player"
		towns[index] = updated
		found = true
		break
	if not found:
		_fail("Could not complete project in town placement %s." % placement_id)
		return null
	clone.overworld["towns"] = towns
	return clone

func _town_summary_for(session: SessionStateStoreScript.SessionData, placement_id: String, project_active: bool, dependencies: Array, project_id: String) -> String:
	var clone := SessionStateStoreScript.new_session_data()
	clone.from_dict(session.to_dict().duplicate(true))
	var towns: Array = clone.overworld.get("towns", []).duplicate(true)
	for index in range(towns.size()):
		var town = towns[index]
		if not (town is Dictionary) or String(town.get("placement_id", "")) != placement_id:
			continue
		var updated: Dictionary = town.duplicate(true)
		updated["owner"] = "player"
		if project_active:
			var built: Array = _string_array(updated.get("built_buildings", []))
			for building_id in dependencies + [project_id]:
				if String(building_id) not in built:
					built.append(String(building_id))
			updated["built_buildings"] = built
		towns[index] = updated
		break
	clone.overworld["towns"] = towns
	clone.flags[OverworldRules.ACTIVE_TOWN_PLACEMENT_KEY] = placement_id
	clone.game_state = "town"
	return TownRules.describe_summary(clone)

func _town_by_placement(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("placement_id", "")) == placement_id:
			return town
	return {}

func _string_array(value: Variant) -> Array:
	var output := []
	if not (value is Array):
		return output
	for entry in value:
		var text := String(entry)
		if text != "" and text not in output:
			output.append(text)
	return output

func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "report_id": REPORT_ID, "error": message})])
	get_tree().quit(1)
