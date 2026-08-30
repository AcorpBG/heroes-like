extends "res://tests/eight_neutral_dwelling_musters_report.gd"

const AbilityRuntimeReportScript = preload("res://tests/unit_ability_runtime_report.gd")

const BATCH_REPORT_ID := "SIX_SOVEREIGN_WILD_HABITATS_SMOKE"
const BATCH_OUTPUT_DIR := "res://.artifacts/six_sovereign_wild_habitats_smoke"
const BATCH_ATLAS_PATH := "res://art/overworld/runtime/objects/resource_sites/sovereign_wild_habitats/sovereign_wild_habitats_atlas.png"
const BATCH_CASES := [
	{"scenario_id":"rainledger-cinder-convergence","site_id":"site_ashcrown_cinderfold","placement_id":"rainledger_ashcrown_cinderfold","guard_id":"rainledger_ashcrown_cinderfold_watch","encounter_id":"encounter_ashcrown_cinderfold_watch","unit_id":"unit_neutral_ashcrown_kilnelk","tier":6,"ability_ids":["reach","bloodrush"],"objective_id":"ashcrown_cinderfold_ring","objective_type":"breach_point","unclaimed":"mapobj_ashcrown_cinderfold","claimed":"resource_site_neutral_ashcrown_cinderfold_controlled","region":Rect2(48,0,48,48),"identity_asset_id":"encounter_sovereign_wild_ashcrown_cinderfold_watch","artifact_id":"artifact_ashcrown_crownring","artifact_icon":"res://art/artifacts/runtime/ashcrown_crownring.png","artifact_bonuses":{"battle_attack":1,"battle_defense":1}},
	{"scenario_id":"fenwake-bogbell-convergence","site_id":"site_miremoon_crownmere","placement_id":"fenwake_miremoon_crownmere","guard_id":"fenwake_miremoon_crownmere_watch","encounter_id":"encounter_miremoon_crownmere_watch","unit_id":"unit_neutral_miremoon_crownmaws","tier":6,"ability_ids":["brace","shielding"],"objective_id":"miremoon_crownmere_pool","objective_type":"hazard_zone","unclaimed":"mapobj_miremoon_crownmere","claimed":"resource_site_neutral_miremoon_crownmere_controlled","region":Rect2(144,0,48,48),"identity_asset_id":"encounter_sovereign_wild_miremoon_crownmere_watch","artifact_id":"artifact_miremoon_crown_tooth","artifact_icon":"res://art/artifacts/runtime/miremoon_crown_tooth.png","artifact_bonuses":{"battle_initiative":1,"scouting_radius":1}},
	{"scenario_id":"halometer-icehook-convergence","site_id":"site_noonshard_prism_aviary","placement_id":"halometer_noonshard_prism_aviary","guard_id":"halometer_noonshard_prism_aviary_watch","encounter_id":"encounter_noonshard_prism_aviary_watch","unit_id":"unit_neutral_noonshard_prism_kites","tier":6,"ability_ids":["harry","volley"],"objective_id":"noonshard_aviary_focus","objective_type":"lane_battery","unclaimed":"mapobj_noonshard_prism_aviary","claimed":"resource_site_neutral_noonshard_prism_aviary_controlled","region":Rect2(240,0,48,48),"identity_asset_id":"encounter_sovereign_wild_noonshard_prism_aviary_watch","artifact_id":"artifact_noonshard_facet_pinion","artifact_icon":"res://art/artifacts/runtime/noonshard_facet_pinion.png","artifact_bonuses":{"battle_spell_resistance_pct":10,"battle_initiative":1}},
	{"scenario_id":"graftsibyl-lantern-convergence","site_id":"site_rootvault_heartwood_hollow","placement_id":"graftsibyl_rootvault_heartwood_hollow","guard_id":"graftsibyl_rootvault_heartwood_watch","encounter_id":"encounter_rootvault_heartwood_watch","unit_id":"unit_neutral_rootvault_barkhulks","tier":7,"ability_ids":["brace","shielding"],"objective_id":"rootvault_heartwood_line","objective_type":"obstruction_line","unclaimed":"mapobj_rootvault_heartwood_hollow","claimed":"resource_site_neutral_rootvault_heartwood_hollow_controlled","region":Rect2(336,0,48,48),"identity_asset_id":"encounter_sovereign_wild_rootvault_heartwood_hollow_watch","artifact_id":"artifact_rootvault_heartgrain_mantle","artifact_icon":"res://art/artifacts/runtime/rootvault_heartgrain_mantle.png","artifact_bonuses":{"battle_defense":2,"overworld_movement":1}},
	{"scenario_id":"debtrune-default-convergence","site_id":"site_quenchbell_pressure_den","placement_id":"debtrune_quenchbell_pressure_den","guard_id":"debtrune_quenchbell_pressure_den_watch","encounter_id":"encounter_quenchbell_pressure_den_watch","unit_id":"unit_neutral_quenchbell_ironbacks","tier":7,"ability_ids":["reach","bloodrush"],"objective_id":"quenchbell_pressure_gate","objective_type":"ritual_pylon","unclaimed":"mapobj_quenchbell_pressure_den","claimed":"resource_site_neutral_quenchbell_pressure_den_controlled","region":Rect2(432,0,48,48),"identity_asset_id":"encounter_sovereign_wild_quenchbell_pressure_den_watch","artifact_id":"artifact_quenchbell_red_gauge_plate","artifact_icon":"res://art/artifacts/runtime/quenchbell_red_gauge_plate.png","artifact_bonuses":{"battle_attack":1,"battle_defense":2}},
	{"scenario_id":"nightchart-meridian-convergence","site_id":"site_saltwake_belldeep","placement_id":"nightchart_saltwake_belldeep","guard_id":"nightchart_saltwake_belldeep_watch","encounter_id":"encounter_saltwake_belldeep_watch","unit_id":"unit_neutral_saltwake_bellwhales","tier":7,"ability_ids":["harry","volley"],"objective_id":"saltwake_belldeep_sounding","objective_type":"signal_beacon","unclaimed":"mapobj_saltwake_belldeep","claimed":"resource_site_neutral_saltwake_belldeep_controlled","region":Rect2(528,0,48,48),"identity_asset_id":"encounter_sovereign_wild_saltwake_belldeep_watch","artifact_id":"artifact_saltwake_resonance_bell","artifact_icon":"res://art/artifacts/runtime/saltwake_resonance_bell.png","artifact_bonuses":{"scouting_radius":2,"overworld_movement":1}},
]


func _validate_case(view: Control, case: Dictionary) -> void:
	await super._validate_case(view, case)
	var unit_id := String(case.get("unit_id", ""))
	var unit := ContentService.get_unit(unit_id)
	_expect(String(unit.get("content_status", "")) == "sovereign_wilds_live", "%s is not marked as live sovereign-wild content." % unit_id)
	_expect(int(unit.get("tier", 0)) == int(case.get("tier", 0)), "%s tier changed." % unit_id)
	_expect(_ability_ids(unit.get("abilities", [])) == case.get("ability_ids", []), "%s ability identity changed." % unit_id)
	var art := ContentService.get_unit_art(unit_id)
	var animation := ContentService.get_unit_animation(unit_id)
	for art_key in ["portrait", "battle_icon", "battle_standee", "overworld_icon"]:
		var art_path := String(art.get(art_key, ""))
		_expect(art_path != "" and load(art_path) is Texture2D, "%s lost its %s runtime art." % [unit_id, art_key])
	var animation_path := String(animation.get("sprite_sheet", ""))
	_expect(animation_path != "" and load(animation_path) is Texture2D, "%s lost its runtime animation sheet." % unit_id)
	_expect(String(art.get("curated_source_sha256", "")) != "" and art.get("curated_source_sha256") == animation.get("curated_source_sha256"), "%s runtime art provenance changed." % unit_id)

	var probe = AbilityRuntimeReportScript.new()
	var ability_results := {}
	for ability_id_value in case.get("ability_ids", []):
		var ability_id := String(ability_id_value)
		var result: Dictionary = probe.call("_runtime_consequence_for_ability", unit_id, ability_id)
		ability_results[ability_id] = result
		_expect(bool(result.get("ok", false)), "%s %s did not execute its live combat consequence: %s" % [unit_id, ability_id, JSON.stringify(result)])
	probe.free()

	var session = ScenarioFactory.create_session(String(case.get("scenario_id", "")), "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var guard := _encounter(session, String(case.get("guard_id", "")))
	var battle := BattleRules.create_battle_payload(session, guard)
	var battle_has_unit := false
	for stack_value in battle.get("stacks", []):
		if stack_value is Dictionary and String(stack_value.get("side", "")) == "enemy" and String(stack_value.get("unit_id", "")) == unit_id:
			battle_has_unit = true
	_expect(battle_has_unit, "%s did not field %s in its production battle." % [String(case.get("encounter_id", "")), unit_id])
	var encounter := ContentService.get_encounter(String(case.get("encounter_id", "")))
	var objectives: Array = encounter.get("field_objectives", [])
	var objective: Dictionary = objectives[0] if not objectives.is_empty() else {}
	_expect(String(objective.get("id", "")) == String(case.get("objective_id", "")) and String(objective.get("type", "")) == String(case.get("objective_type", "")), "%s objective identity changed." % String(case.get("encounter_id", "")))
	var presentation: Dictionary = view.call("validation_encounter_presentation_payload", guard)
	var identity_asset_id := String(case.get("identity_asset_id", ""))
	var expected_identity_path := String(art.get("overworld_icon", ""))
	_expect(String(presentation.get("identity_encounter_asset_id", "")) == identity_asset_id and String(presentation.get("identity_encounter_path", "")) == expected_identity_path and bool(presentation.get("uses_identity_encounter_sprite", false)), "%s lost its exact creature encounter identity." % String(case.get("encounter_id", "")))

	var artifact_id := String(case.get("artifact_id", ""))
	var artifact_icon := String(case.get("artifact_icon", ""))
	var artifact := ContentService.get_artifact(artifact_id)
	_expect(_artifact_bonus_values_exact(artifact.get("bonuses", {}), case.get("artifact_bonuses", {})), "%s live trophy bonuses changed." % artifact_id)
	_expect(String(artifact.get("family", "")) == "sovereign_wild_trophies" and artifact.get("source_tags", []) == ["dwelling"], "%s is not an exact sovereign dwelling trophy." % artifact_id)
	_expect(ArtifactRules.artifact_icon_path(artifact_id) == artifact_icon and load(artifact_icon) is Texture2D, "%s lost its exact runtime icon." % artifact_id)
	var trophy_session = ScenarioFactory.create_session(String(case.get("scenario_id", "")), "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(trophy_session)
	_resolve_guard(trophy_session, String(case.get("guard_id", "")))
	var bonuses_before := ArtifactRules.aggregate_bonuses(trophy_session.overworld.get("hero", {}))
	var trophy_claim := OverworldRules._collect_resource_node_result(trophy_session, _resource_node_result(trophy_session, String(case.get("placement_id", ""))), true)
	var trophy_node_after: Dictionary = _resource_node_result(trophy_session, String(case.get("placement_id", ""))).get("node", {})
	var trophy_location := ArtifactRules.locate_artifact(trophy_session.overworld.get("hero", {}), artifact_id)
	var bonuses_after := ArtifactRules.aggregate_bonuses(trophy_session.overworld.get("hero", {}))
	_expect(bool(trophy_claim.get("ok", false)) and artifact_id in ArtifactRules.owned_artifact_ids(trophy_session.overworld.get("hero", {})), "%s habitat claim did not grant %s." % [String(case.get("site_id", "")), artifact_id])
	_expect(String(trophy_location.get("location", "")) == "equipped", "%s was not auto-equipped from the live habitat claim: %s" % [artifact_id, JSON.stringify(trophy_location)])
	_expect(_artifact_bonus_delta_exact(bonuses_before, bonuses_after, case.get("artifact_bonuses", {})), "%s equipped bonus did not apply exactly." % artifact_id)
	_expect(String(trophy_node_after.get("artifact_reward_id", "")) == artifact_id and String(trophy_node_after.get("artifact_reward_table_id", "")) == "artifact_source_sovereign_wild_trophies" and String(trophy_node_after.get("artifact_reward_claimed_by_faction_id", "")) == "player", "%s lost its exact habitat reward provenance." % artifact_id)
	var trophy_authority := trophy_session.to_dict()
	var trophy_repeat := OverworldRules._collect_resource_node_result(trophy_session, _resource_node_result(trophy_session, String(case.get("placement_id", ""))), true)
	_expect(not bool(trophy_repeat.get("ok", true)) and trophy_session.to_dict() == trophy_authority, "%s repeated habitat claim mutated trophy authority." % artifact_id)
	var trophy_restored := _clone_session(trophy_session)
	_expect(trophy_restored.to_dict() == trophy_session.to_dict() and artifact_id in ArtifactRules.owned_artifact_ids(trophy_restored.overworld.get("hero", {})), "%s did not round-trip through save version %d." % [artifact_id, SessionStateStoreScript.SAVE_VERSION])
	if not _rows.is_empty():
		_rows[-1]["unit_id"] = unit_id
		_rows[-1]["unit_tier"] = int(unit.get("tier", 0))
		_rows[-1]["ability_results"] = ability_results
		_rows[-1]["battle_fields_exact_unit"] = battle_has_unit
		_rows[-1]["objective_id"] = String(objective.get("id", ""))
		_rows[-1]["exact_identity_art"] = String(presentation.get("identity_encounter_asset_id", "")) == identity_asset_id
		_rows[-1]["artifact_id"] = artifact_id
		_rows[-1]["artifact_icon"] = artifact_icon
		_rows[-1]["artifact_auto_equipped"] = String(trophy_location.get("location", "")) == "equipped"
		_rows[-1]["artifact_bonus_exact"] = _artifact_bonus_delta_exact(bonuses_before, bonuses_after, case.get("artifact_bonuses", {}))
		_rows[-1]["artifact_provenance_exact"] = String(trophy_node_after.get("artifact_reward_id", "")) == artifact_id
		_rows[-1]["artifact_save_round_trip_exact"] = trophy_restored.to_dict() == trophy_session.to_dict()


func _ability_ids(abilities: Variant) -> Array:
	var result := []
	if abilities is Array:
		for ability_value in abilities:
			if ability_value is Dictionary:
				result.append(String(ability_value.get("id", "")))
	return result


func _artifact_bonus_delta_exact(before: Dictionary, after: Dictionary, expected_value: Variant) -> bool:
	if not (expected_value is Dictionary):
		return false
	var expected: Dictionary = expected_value
	for key_value in expected.keys():
		var key := String(key_value)
		if int(after.get(key, 0)) - int(before.get(key, 0)) != int(expected.get(key_value, 0)):
			return false
	return true


func _artifact_bonus_values_exact(actual_value: Variant, expected_value: Variant) -> bool:
	if not (actual_value is Dictionary) or not (expected_value is Dictionary):
		return false
	var actual: Dictionary = actual_value
	var expected: Dictionary = expected_value
	for key_value in expected.keys():
		if int(actual.get(key_value, 0)) != int(expected.get(key_value, 0)):
			return false
	return true


func _report_id() -> String:
	return BATCH_REPORT_ID


func _output_dir() -> String:
	return BATCH_OUTPUT_DIR


func _atlas_path() -> String:
	return BATCH_ATLAS_PATH


func _capture_environment_name() -> String:
	return "SOVEREIGN_WILD_HABITAT_CAPTURE_DIR"


func _cases() -> Array:
	return BATCH_CASES
