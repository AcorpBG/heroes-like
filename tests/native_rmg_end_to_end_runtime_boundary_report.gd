extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const NativeRandomMapPackageSessionBridgeScript = preload("res://scripts/persistence/NativeRandomMapPackageSessionBridge.gd")
const OverworldRulesScript = preload("res://scripts/core/OverworldRules.gd")
const ArtifactRulesScript = preload("res://scripts/core/ArtifactRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const REPORT_ID := "NATIVE_RMG_END_TO_END_RUNTIME_BOUNDARY_REPORT"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ClassDB.class_exists("MapPackageService"):
		_fail("MapPackageService native class is not available.")
		return
	var service: Variant = ClassDB.instantiate("MapPackageService")
	if not _validate_supported_workflow_matrix(service):
		return
	var zero_road_projection := _validate_zero_road_projection(service)
	if not bool(zero_road_projection.get("ok", false)):
		_fail("Zero-road native payload projection failed: %s" % JSON.stringify(zero_road_projection))
		return
	var live_proxy_projection := _validate_live_proxy_site_projection(service)
	if not bool(live_proxy_projection.get("ok", false)):
		_fail("Live proxy site projection failed: %s" % JSON.stringify(live_proxy_projection))
		return

	var medium := _generate_and_validate(
		service,
		_config("medium", 72, 1, "land", "10"),
		79333,
		1326
	)
	if not bool(medium.get("ok", false)):
		_fail("Medium public generation boundary failed: %s" % JSON.stringify(medium))
		return
	var medium_guard_projection := _validate_guard_control_projection(medium.get("generated", {}))
	if not bool(medium_guard_projection.get("ok", false)):
		_fail("Medium guard control projection failed: %s" % JSON.stringify(medium_guard_projection))
		return
	var medium_guard_live_behavior := _validate_guard_live_behavior(service, medium.get("generated", {}))
	if not bool(medium_guard_live_behavior.get("ok", false)):
		_fail("Medium guard control live behavior failed: %s" % JSON.stringify(medium_guard_live_behavior))
		return
	var ordinal_95 := _generate_and_validate(
		service,
		_config("medium", 72, 1, "land", "165429308", "weak", 4),
		76831,
		1283
	)
	if not bool(ordinal_95.get("ok", false)):
		_fail("Medium ordinal 95 exact-mask start boundary failed: %s" % JSON.stringify(ordinal_95))
		return
	var ordinal_95_generated: Dictionary = ordinal_95.get("generated", {})
	var ordinal_95_scenario: Variant = ordinal_95_generated.get("scenario_document", null)
	var ordinal_95_contract: Dictionary = ordinal_95_scenario.get_start_contract() if ordinal_95_scenario != null else {}
	var ordinal_95_player_start := _player_owned_start(ordinal_95_contract)
	var ordinal_95_runtime_start: Dictionary = ordinal_95_player_start.get("runtime_start_tile", {}) if ordinal_95_player_start.get("runtime_start_tile", {}) is Dictionary else {}
	var ordinal_95_adoption: Dictionary = service.convert_generated_payload(ordinal_95_generated, {"feature_gate": REPORT_ID})
	var ordinal_95_session = NativeRandomMapPackageSessionBridgeScript.build_session_from_adoption(ordinal_95_adoption)
	var ordinal_95_hero_position: Dictionary = ordinal_95_session.overworld.get("hero_position", {}) if ordinal_95_session != null and ordinal_95_session.overworld.get("hero_position", {}) is Dictionary else {}
	var ordinal_95_player_move := _execute_legal_player_step(ordinal_95_session)
	if String(ordinal_95_generated.get("final_payload_fnv1a32", "")) != "1744e025" \
			or int(ordinal_95_player_start.get("x", -1)) != 31 \
			or int(ordinal_95_player_start.get("y", -1)) != 10 \
			or ordinal_95_runtime_start.is_empty() \
			or (int(ordinal_95_runtime_start.get("x", -1)) == 31 and int(ordinal_95_runtime_start.get("y", -1)) == 10) \
			or int(ordinal_95_runtime_start.get("selection_package_road_reachable_steps", -1)) <= 0 \
			or ordinal_95_hero_position != {"x": int(ordinal_95_runtime_start.get("x", -1)), "y": int(ordinal_95_runtime_start.get("y", -1))} \
			or not bool(ordinal_95_player_move.get("ok", false)):
		_fail("Medium ordinal 95 did not preserve its payload/town anchor while moving the runtime start: %s" % JSON.stringify(ordinal_95_player_start))
		return
	var xlarge := _generate_and_validate(
		service,
		_config("homm3_extra_large", 144, 2, "normal_water", "77"),
		365777,
		2779
	)
	if not bool(xlarge.get("ok", false)):
		_fail("XLarge public generation boundary failed: %s" % JSON.stringify(xlarge))
		return

	var round_trip := _validate_round_trip(service, medium.get("generated", {}))
	if not bool(round_trip.get("ok", false)):
		_fail("Native package round trip failed: %s" % JSON.stringify(round_trip))
		return
	var startup := _validate_session_startup()
	if not bool(startup.get("ok", false)):
		_fail("Generated session startup failed: %s" % JSON.stringify(startup))
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"workflow_shape_count": 24,
		"zero_road_projection": zero_road_projection,
		"live_proxy_projection": live_proxy_projection,
		"medium": medium.get("summary", {}),
		"medium_guard_projection": medium_guard_projection,
		"medium_guard_live_behavior": medium_guard_live_behavior,
		"medium_ordinal_95": ordinal_95.get("summary", {}),
		"medium_ordinal_95_town_anchor": {"x": 31, "y": 10},
		"medium_ordinal_95_runtime_start": ordinal_95_runtime_start,
		"medium_ordinal_95_hero_position": ordinal_95_hero_position,
		"medium_ordinal_95_player_move": ordinal_95_player_move,
		"xlarge": xlarge.get("summary", {}),
		"round_trip": round_trip,
		"startup": startup,
	})])
	get_tree().quit(0)

func _validate_live_proxy_site_projection(service: Variant) -> Dictionary:
	var config := _config("small", 36, 1, "land", "1", "weak", 3)
	var first: Dictionary = service.generate_random_map(config, {"startup_path": "live_proxy_projection_first"})
	var second: Dictionary = service.generate_random_map(config, {"startup_path": "live_proxy_projection_repeat"})
	var map_document: Variant = first.get("map_document", null)
	var second_map: Variant = second.get("map_document", null)
	if map_document == null or second_map == null:
		return {"ok": false, "reason": "missing_map_document"}
	var exact_identity := []
	var repeat_identity := []
	var mine_count := 0
	var mine_subtypes := {}
	var mine_rows_exact := true
	var campfire_count := 0
	var campfire_rows_exact := true
	var creature_generator_count := 0
	var unsupported_creature_rows_exact := true
	var creature_bank_count := 0
	var unsupported_bank_rows_exact := true
	var artifact_proxy_count := 0
	var artifact_proxy_rows_exact := true
	var artifact_proxy_placement_ids := {}
	var resource_proxy_count := 0
	var resource_proxy_rows_exact := true
	var resource_proxy_subtypes := {}
	var expected_mines := {
		0: {"object_id": "object_brightwood_sawmill", "resource_id": "wood", "catalog_id": "mine_wood_sawmill_proxy"},
		1: {"object_id": "object_marsh_peat_yard", "resource_id": "gold", "catalog_id": "mine_alchemist_proxy"},
		2: {"object_id": "object_ridge_quarry", "resource_id": "ore", "catalog_id": "mine_ore_pit_proxy"},
		3: {"object_id": "object_floodplain_sluice_camp", "resource_id": "gold", "catalog_id": "mine_sulfur_proxy"},
		4: {"object_id": "object_cinder_ore_face", "resource_id": "gold", "catalog_id": "mine_crystal_proxy"},
		5: {"object_id": "object_badlands_coin_sluice", "resource_id": "gold", "catalog_id": "mine_gems_proxy"},
		6: {"object_id": "object_reef_coin_assay", "resource_id": "gold", "catalog_id": "mine_gold_proxy"},
	}
	var expected_artifacts := {
		67: {"artifact_id": "artifact_waymark_compass", "catalog_id": "reward_random_minor_artifact_proxy"},
		68: {"artifact_id": "artifact_warcrest_pennon", "catalog_id": "reward_random_major_artifact_proxy"},
	}
	var expected_resources := {
		0: {"object_id": "object_wood_wagon", "site_id": "site_wood_wagon", "resource_id": "wood", "catalog_id": "reward_resource_wood_build_proxy"},
		1: {"object_id": "object_marsh_peat_yard", "site_id": "site_peatwax_reed_yard", "resource_id": "peatwax", "catalog_id": "reward_resource_mercury_peatwax_proxy"},
		2: {"object_id": "object_ore_crates", "site_id": "site_ore_crates", "resource_id": "ore", "catalog_id": "reward_resource_ore_build_proxy"},
		3: {"object_id": "object_floodplain_sluice_camp", "site_id": "site_embergrain_warm_granary", "resource_id": "embergrain", "catalog_id": "reward_resource_sulfur_embergrain_proxy"},
		4: {"object_id": "object_cinder_ore_face", "site_id": "site_aetherglass_lens_house", "resource_id": "aetherglass", "catalog_id": "reward_resource_crystal_aetherglass_proxy"},
		5: {"object_id": "object_badlands_coin_sluice", "site_id": "site_memory_salt_pan", "resource_id": "memory_salt", "catalog_id": "reward_resource_gems_memory_salt_proxy"},
		6: {"object_id": "object_reef_coin_assay", "site_id": "site_reef_coin_assay", "resource_id": "gold", "catalog_id": "reward_resource_gold_reef_coin_proxy"},
	}
	for object_index in range(int(map_document.get_object_count())):
		var object: Dictionary = map_document.get_object_by_index(object_index)
		exact_identity.append(_proxy_projection_object_authority(object))
		var type_id := int(object.get("h3m_type_id", -1))
		var subtype := int(object.get("h3m_subtype", -1))
		if String(object.get("kind", "")) == "mine":
			mine_count += 1
			mine_subtypes[subtype] = true
			var expected: Dictionary = expected_mines.get(subtype, {}) if expected_mines.get(subtype, {}) is Dictionary else {}
			if expected.is_empty() \
					or String(object.get("object_id", "")) != String(expected.get("object_id", "")) \
					or String(object.get("native_proxy_object_id", "")) != String(expected.get("object_id", "")) \
					or String(object.get("resource_id", "")) != String(expected.get("resource_id", "")) \
					or String(object.get("homm3_re_reward_object_catalog_id", "")) != String(expected.get("catalog_id", "")) \
					or not _live_proxy_provenance_exact(object):
				mine_rows_exact = false
		elif type_id == 12:
			campfire_count += 1
			if String(object.get("kind", "")) != "reward_reference" \
					or String(object.get("object_id", "")) != "object_waystone_cache" \
					or String(object.get("site_id", "")) != "site_waystone_cache" \
					or String(object.get("homm3_re_reward_object_catalog_id", "")) != "reward_campfire_minor_proxy" \
					or not _live_proxy_provenance_exact(object):
				campfire_rows_exact = false
		elif type_id == 17:
			creature_generator_count += 1
			if String(object.get("kind", "")) != "h3m_object" \
					or String(object.get("object_id", "")) != "" \
					or String(object.get("homm3_re_reward_object_catalog_id", "")) != "":
				unsupported_creature_rows_exact = false
		elif type_id == 16:
			creature_bank_count += 1
			if String(object.get("kind", "")) != "h3m_object" \
					or String(object.get("object_id", "")) != "" \
					or String(object.get("homm3_re_reward_object_catalog_id", "")) != "":
				unsupported_bank_rows_exact = false
		elif type_id in [67, 68]:
			artifact_proxy_count += 1
			artifact_proxy_placement_ids[String(object.get("placement_id", ""))] = true
			var expected_artifact: Dictionary = expected_artifacts.get(type_id, {}) if expected_artifacts.get(type_id, {}) is Dictionary else {}
			if expected_artifact.is_empty() \
					or String(object.get("kind", "")) != "reward_reference" \
					or String(object.get("artifact_id", "")) != String(expected_artifact.get("artifact_id", "")) \
					or String(object.get("object_id", "")) != String(expected_artifact.get("artifact_id", "")) \
					or String(object.get("native_proxy_object_id", "")) != String(expected_artifact.get("artifact_id", "")) \
					or String(object.get("site_id", "")) != "" \
					or String(object.get("homm3_re_reward_object_catalog_id", "")) != String(expected_artifact.get("catalog_id", "")) \
					or not _live_proxy_provenance_exact(object):
				artifact_proxy_rows_exact = false
		elif type_id == 79:
			resource_proxy_count += 1
			resource_proxy_subtypes[subtype] = true
			var expected_resource: Dictionary = expected_resources.get(subtype, {}) if expected_resources.get(subtype, {}) is Dictionary else {}
			if expected_resource.is_empty() \
					or String(object.get("kind", "")) != "reward_reference" \
					or String(object.get("object_id", "")) != String(expected_resource.get("object_id", "")) \
					or String(object.get("site_id", "")) != String(expected_resource.get("site_id", "")) \
					or String(object.get("resource_id", "")) != String(expected_resource.get("resource_id", "")) \
					or String(object.get("homm3_re_reward_object_catalog_id", "")) != String(expected_resource.get("catalog_id", "")) \
					or not _live_proxy_provenance_exact(object):
				resource_proxy_rows_exact = false
	for object_index in range(int(second_map.get_object_count())):
		repeat_identity.append(_proxy_projection_object_authority(second_map.get_object_by_index(object_index)))
	var adoption: Dictionary = service.convert_generated_payload(first, {"feature_gate": REPORT_ID})
	var session = NativeRandomMapPackageSessionBridgeScript.build_session_from_adoption(adoption)
	var expected_site_by_subtype := {
		0: "site_brightwood_sawmill",
		1: "site_peatwax_reed_yard",
		2: "site_ridge_quarry",
		3: "site_embergrain_warm_granary",
		4: "site_aetherglass_lens_house",
		5: "site_memory_salt_pan",
		6: "site_reef_coin_assay",
	}
	var live_mine_count := 0
	var live_mine_sites_exact := true
	var live_campfires := []
	var live_artifacts := []
	var artifact_resource_node_count := 0
	var live_resource_proxy_count := 0
	var live_resource_proxy_rows_exact := true
	var selected_rare_resource := {}
	if session != null:
		var resource_nodes: Array = session.overworld.get("resource_nodes", []) if session.overworld.get("resource_nodes", []) is Array else []
		var package_source_objects: Dictionary = session.overworld.get("package_source_objects_by_id", {}) if session.overworld.get("package_source_objects_by_id", {}) is Dictionary else {}
		for node_index in range(resource_nodes.size()):
			var node_value: Variant = resource_nodes[node_index]
			if not (node_value is Dictionary):
				continue
			var node: Dictionary = node_value
			var source: Dictionary = package_source_objects.get(String(node.get("placement_id", "")), {}) if package_source_objects.get(String(node.get("placement_id", "")), {}) is Dictionary else {}
			if int(source.get("h3m_type_id", -1)) == 53:
				live_mine_count += 1
				if String(node.get("site_id", "")) != String(expected_site_by_subtype.get(int(source.get("h3m_subtype", -1)), "")):
					live_mine_sites_exact = false
			elif int(source.get("h3m_type_id", -1)) == 12:
				live_campfires.append({"index": node_index, "node": node.duplicate(true)})
			elif int(source.get("h3m_type_id", -1)) in [67, 68]:
				artifact_resource_node_count += 1
			elif int(source.get("h3m_type_id", -1)) == 79:
				live_resource_proxy_count += 1
				var expected_resource: Dictionary = expected_resources.get(int(source.get("h3m_subtype", -1)), {}) if expected_resources.get(int(source.get("h3m_subtype", -1)), {}) is Dictionary else {}
				if expected_resource.is_empty() \
						or String(node.get("object_id", "")) != String(expected_resource.get("object_id", "")) \
						or String(node.get("site_id", "")) != String(expected_resource.get("site_id", "")) \
						or String(node.get("resource_id", "")) != String(expected_resource.get("resource_id", "")):
					live_resource_proxy_rows_exact = false
				if int(source.get("h3m_subtype", -1)) == 3 and selected_rare_resource.is_empty():
					selected_rare_resource = {"index": node_index, "node": node.duplicate(true)}
		var artifact_nodes: Array = session.overworld.get("artifact_nodes", []) if session.overworld.get("artifact_nodes", []) is Array else []
		for artifact_index in range(artifact_nodes.size()):
			var artifact_value: Variant = artifact_nodes[artifact_index]
			if not (artifact_value is Dictionary):
				continue
			var artifact_node: Dictionary = artifact_value
			if artifact_proxy_placement_ids.has(String(artifact_node.get("placement_id", ""))):
				live_artifacts.append({"index": artifact_index, "node": artifact_node.duplicate(true)})
	var interaction := {}
	if session != null and not live_campfires.is_empty():
		var campfire_result: Dictionary = live_campfires[0]
		var campfire: Dictionary = campfire_result.get("node", {}) if campfire_result.get("node", {}) is Dictionary else {}
		var resources_before: Dictionary = session.overworld.get("resources", {}).duplicate(true)
		var claim: Dictionary = OverworldRulesScript._collect_resource_node_result(session, campfire_result, false)
		var claimed_nodes: Array = session.overworld.get("resource_nodes", []) if session.overworld.get("resource_nodes", []) is Array else []
		var claimed_node: Dictionary = claimed_nodes[int(campfire_result.get("index", -1))] if int(campfire_result.get("index", -1)) >= 0 and int(campfire_result.get("index", -1)) < claimed_nodes.size() and claimed_nodes[int(campfire_result.get("index", -1))] is Dictionary else {}
		interaction = {
			"ok": bool(claim.get("ok", false)) and bool(claimed_node.get("collected", false)) and session.overworld.get("resources", {}) != resources_before,
			"placement_id": campfire.get("placement_id", ""),
			"site_id": campfire.get("site_id", ""),
			"claim_ok": claim.get("ok", false),
			"collected": claimed_node.get("collected", false),
			"resources_changed": session.overworld.get("resources", {}) != resources_before,
		}
	var artifact_interaction := {}
	if session != null and not live_artifacts.is_empty():
		var artifact_result: Dictionary = live_artifacts[0]
		var artifact_node: Dictionary = artifact_result.get("node", {}) if artifact_result.get("node", {}) is Dictionary else {}
		var artifact_id := String(artifact_node.get("artifact_id", ""))
		var owned_before: Array = ArtifactRulesScript.owned_artifact_ids(session.overworld.get("hero", {}))
		var claim: Dictionary = OverworldRulesScript._collect_artifact_node_result(session, artifact_result, false)
		var claimed_artifacts: Array = session.overworld.get("artifact_nodes", []) if session.overworld.get("artifact_nodes", []) is Array else []
		var claimed_node: Dictionary = claimed_artifacts[int(artifact_result.get("index", -1))] if int(artifact_result.get("index", -1)) >= 0 and int(artifact_result.get("index", -1)) < claimed_artifacts.size() and claimed_artifacts[int(artifact_result.get("index", -1))] is Dictionary else {}
		var owned_after: Array = ArtifactRulesScript.owned_artifact_ids(session.overworld.get("hero", {}))
		var restored = SessionStateStoreScript.SessionData.new()
		restored.from_dict(session.to_dict())
		var restored_artifacts: Array = restored.overworld.get("artifact_nodes", []) if restored.overworld.get("artifact_nodes", []) is Array else []
		var restored_node: Dictionary = restored_artifacts[int(artifact_result.get("index", -1))] if int(artifact_result.get("index", -1)) >= 0 and int(artifact_result.get("index", -1)) < restored_artifacts.size() and restored_artifacts[int(artifact_result.get("index", -1))] is Dictionary else {}
		artifact_interaction = {
			"ok": bool(claim.get("ok", false)) \
					and not owned_before.has(artifact_id) \
					and owned_after.has(artifact_id) \
					and bool(claimed_node.get("collected", false)) \
					and restored_node == claimed_node,
			"placement_id": artifact_node.get("placement_id", ""),
			"artifact_id": artifact_id,
			"claim_ok": claim.get("ok", false),
			"owned_before": owned_before.has(artifact_id),
			"owned_after": owned_after.has(artifact_id),
			"collected": claimed_node.get("collected", false),
			"save_round_trip_exact": restored_node == claimed_node,
		}
	var rare_resource_interaction := {}
	if session != null and not selected_rare_resource.is_empty():
		var resources_before: Dictionary = session.overworld.get("resources", {}).duplicate(true)
		var claim: Dictionary = OverworldRulesScript._collect_resource_node_result(session, selected_rare_resource, false)
		var resources_after: Dictionary = session.overworld.get("resources", {}).duplicate(true)
		var restored = SessionStateStoreScript.SessionData.new()
		restored.from_dict(session.to_dict())
		var restored_nodes: Array = restored.overworld.get("resource_nodes", []) if restored.overworld.get("resource_nodes", []) is Array else []
		var restored_node: Dictionary = restored_nodes[int(selected_rare_resource.get("index", -1))] if int(selected_rare_resource.get("index", -1)) >= 0 and int(selected_rare_resource.get("index", -1)) < restored_nodes.size() and restored_nodes[int(selected_rare_resource.get("index", -1))] is Dictionary else {}
		var claimed_nodes: Array = session.overworld.get("resource_nodes", []) if session.overworld.get("resource_nodes", []) is Array else []
		var claimed_node: Dictionary = claimed_nodes[int(selected_rare_resource.get("index", -1))] if int(selected_rare_resource.get("index", -1)) >= 0 and int(selected_rare_resource.get("index", -1)) < claimed_nodes.size() and claimed_nodes[int(selected_rare_resource.get("index", -1))] is Dictionary else {}
		var other_rare_exact := true
		for resource_id in ["aetherglass", "brass_scrip", "memory_salt", "peatwax", "verdant_grafts"]:
			if resources_after.get(resource_id, 0) != resources_before.get(resource_id, 0):
				other_rare_exact = false
		rare_resource_interaction = {
			"ok": bool(claim.get("ok", false)) \
					and int(resources_after.get("embergrain", 0)) == int(resources_before.get("embergrain", 0)) + 1 \
					and int(resources_after.get("gold", 0)) == int(resources_before.get("gold", 0)) + 120 \
					and other_rare_exact \
					and restored_node == claimed_node \
					and restored.overworld.get("resources", {}) == resources_after,
			"site_id": claimed_node.get("site_id", ""),
			"resource_id": claimed_node.get("resource_id", ""),
			"claim_ok": claim.get("ok", false),
			"embergrain_delta": int(resources_after.get("embergrain", 0)) - int(resources_before.get("embergrain", 0)),
			"gold_delta": int(resources_after.get("gold", 0)) - int(resources_before.get("gold", 0)),
			"other_rare_exact": other_rare_exact,
			"save_round_trip_exact": restored_node == claimed_node and restored.overworld.get("resources", {}) == resources_after,
		}
	var exact_repeat: bool = bool(second.get("ok", false)) \
			and first.get("final_payload_fnv1a32", "") == second.get("final_payload_fnv1a32", "") \
			and first.get("final_payload_byte_count", -1) == second.get("final_payload_byte_count", -2) \
			and exact_identity == repeat_identity
	return {
		"ok": bool(first.get("ok", false)) \
				and mine_count == 18 \
				and mine_subtypes.size() == 7 \
				and mine_rows_exact \
				and campfire_count == 2 \
				and campfire_rows_exact \
				and creature_generator_count == 2 \
				and unsupported_creature_rows_exact \
				and creature_bank_count == 2 \
				and unsupported_bank_rows_exact \
				and artifact_proxy_count == 3 \
				and artifact_proxy_rows_exact \
				and resource_proxy_count == 28 \
				and resource_proxy_subtypes.size() == 6 \
				and resource_proxy_subtypes.has(0) \
				and resource_proxy_subtypes.has(2) \
				and resource_proxy_subtypes.has(3) \
				and resource_proxy_subtypes.has(4) \
				and resource_proxy_subtypes.has(5) \
				and resource_proxy_subtypes.has(6) \
				and resource_proxy_rows_exact \
				and bool(adoption.get("ok", false)) \
				and session != null \
				and live_mine_count == mine_count \
				and live_mine_sites_exact \
				and live_campfires.size() == campfire_count \
				and bool(interaction.get("ok", false)) \
				and artifact_resource_node_count == 0 \
				and live_artifacts.size() == artifact_proxy_count \
				and bool(artifact_interaction.get("ok", false)) \
				and live_resource_proxy_count == resource_proxy_count \
				and live_resource_proxy_rows_exact \
				and bool(rare_resource_interaction.get("ok", false)) \
				and exact_repeat,
		"payload_hash": first.get("final_payload_fnv1a32", ""),
		"payload_bytes": first.get("final_payload_byte_count", -1),
		"objects": first.get("runtime_object_count", -1),
		"mine_count": mine_count,
		"mine_subtypes": mine_subtypes.keys(),
		"mine_rows_exact": mine_rows_exact,
		"campfire_count": campfire_count,
		"campfire_rows_exact": campfire_rows_exact,
		"creature_generator_count": creature_generator_count,
		"unsupported_creature_rows_exact": unsupported_creature_rows_exact,
		"creature_bank_count": creature_bank_count,
		"unsupported_bank_rows_exact": unsupported_bank_rows_exact,
		"artifact_proxy_count": artifact_proxy_count,
		"artifact_proxy_rows_exact": artifact_proxy_rows_exact,
		"artifact_resource_node_count": artifact_resource_node_count,
		"live_artifact_count": live_artifacts.size(),
		"resource_proxy_count": resource_proxy_count,
		"resource_proxy_subtypes": resource_proxy_subtypes.keys(),
		"resource_proxy_rows_exact": resource_proxy_rows_exact,
		"live_resource_proxy_count": live_resource_proxy_count,
		"live_resource_proxy_rows_exact": live_resource_proxy_rows_exact,
		"live_mine_count": live_mine_count,
		"live_mine_sites_exact": live_mine_sites_exact,
		"live_campfire_count": live_campfires.size(),
		"interaction": interaction,
		"artifact_interaction": artifact_interaction,
		"rare_resource_interaction": rare_resource_interaction,
		"exact_repeat": exact_repeat,
	}

func _live_proxy_provenance_exact(object: Dictionary) -> bool:
	return String(object.get("homm3_re_reward_object_catalog_path", "")) == "res://content/homm3_re_reward_object_proxy_catalog.json" \
			and String(object.get("homm3_re_reward_object_catalog_schema", "")) == "homm3_re_reward_object_proxy_catalog_v1" \
			and String(object.get("homm3_re_art_asset_policy", "")) == "provenance_only_original_proxy_art" \
			and int(object.get("homm3_re_object_type_id", -1)) == int(object.get("h3m_type_id", -2)) \
			and int(object.get("homm3_re_object_subtype", -1)) == int(object.get("h3m_subtype", -2)) \
			and String(object.get("homm3_re_object_def_ref", "")) != ""

func _proxy_projection_object_authority(object: Dictionary) -> Dictionary:
	return {
		"placement_id": object.get("placement_id", ""),
		"h3m_type_id": object.get("h3m_type_id", -1),
		"h3m_subtype": object.get("h3m_subtype", -1),
		"h3m_definition_index": object.get("h3m_definition_index", -1),
		"h3m_def_name": object.get("h3m_def_name", ""),
		"h3m_serialization_pass": object.get("h3m_serialization_pass", -1),
		"h3m_payload_offset": object.get("h3m_payload_offset", -1),
		"h3m_payload_byte_count": object.get("h3m_payload_byte_count", -1),
		"primary_tile": object.get("primary_tile", {}),
		"body_tiles": object.get("body_tiles", []),
		"package_block_tiles": object.get("package_block_tiles", []),
		"package_visit_tiles": object.get("package_visit_tiles", []),
		"kind": object.get("kind", ""),
		"object_id": object.get("object_id", ""),
		"site_id": object.get("site_id", ""),
		"resource_id": object.get("resource_id", ""),
		"artifact_id": object.get("artifact_id", ""),
		"catalog_id": object.get("homm3_re_reward_object_catalog_id", ""),
	}

func _validate_guard_control_projection(generated: Dictionary) -> Dictionary:
	var map_document: Variant = generated.get("map_document", null)
	if map_document == null:
		return {"ok": false, "reason": "missing_map_document"}
	var width := int(map_document.get_width())
	var height := int(map_document.get_height())
	var level_count := int(map_document.get_level_count())
	var guard_count := 0
	var guard_control_tile_count := 0
	var union_keys := {}
	var exact_rows := true
	for object_index in range(int(map_document.get_object_count())):
		var object: Dictionary = map_document.get_object_by_index(object_index)
		if String(object.get("kind", "")) != "guard":
			continue
		guard_count += 1
		var origins: Array = object.get("package_visit_tiles", []) if object.get("package_visit_tiles", []) is Array else []
		if origins.is_empty():
			var primary: Dictionary = object.get("primary_tile", {}) if object.get("primary_tile", {}) is Dictionary else {}
			if not primary.is_empty():
				origins = [primary]
		var expected := []
		var expected_keys := {}
		for origin_value in origins:
			if not (origin_value is Dictionary):
				continue
			var origin: Dictionary = origin_value
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var x := int(origin.get("x", -1)) + dx
					var y := int(origin.get("y", -1)) + dy
					var level := int(origin.get("level", -1))
					if x < 0 or y < 0 or level < 0 or x >= width or y >= height or level >= level_count:
						continue
					var key := "%d,%d,%d" % [x, y, level]
					if expected_keys.has(key):
						continue
					expected_keys[key] = true
					expected.append({"x": x, "y": y, "level": level})
					union_keys[key] = true
		var control: Array = object.get("package_guard_control_zone_tiles", []) if object.get("package_guard_control_zone_tiles", []) is Array else []
		var engagement: Array = object.get("package_guard_engagement_tiles", []) if object.get("package_guard_engagement_tiles", []) is Array else []
		guard_control_tile_count += control.size()
		if control != expected \
				or engagement != expected \
				or int(object.get("package_guard_control_zone_tile_count", -1)) != expected.size() \
				or int(object.get("package_guard_engagement_tile_count", -1)) != expected.size() \
				or String(object.get("package_guard_control_zone_pathing_policy", "")) != "h3m_guard_control_forces_engagement_guard_body_remains_blocking_surface" \
				or String(object.get("package_guard_engagement_policy", "")) != "h3m_guard_control_forces_engagement":
			exact_rows = false
	return {
		"ok": guard_count == 41 \
				and guard_control_tile_count == 369 \
				and union_keys.size() == 365 \
				and exact_rows,
		"guard_count": guard_count,
		"guard_control_tile_count": guard_control_tile_count,
		"guard_control_union_tile_count": union_keys.size(),
		"exact_rows": exact_rows,
		"payload_bytes": generated.get("final_payload_byte_count", -1),
		"object_count": generated.get("runtime_object_count", -1),
		"payload_hash": generated.get("final_payload_fnv1a32", ""),
	}

func _validate_guard_live_behavior(service: Variant, generated: Dictionary) -> Dictionary:
	var map_document: Variant = generated.get("map_document", null)
	if map_document == null:
		return {"ok": false, "reason": "missing_map_document"}
	var control_owners := {}
	var guards := []
	for object_index in range(int(map_document.get_object_count())):
		var object: Dictionary = map_document.get_object_by_index(object_index)
		if String(object.get("kind", "")) != "guard":
			continue
		guards.append(object)
		var tiles: Array = object.get("package_guard_engagement_tiles", []) if object.get("package_guard_engagement_tiles", []) is Array else []
		for tile_value in tiles:
			if not (tile_value is Dictionary):
				continue
			var tile: Dictionary = tile_value
			var key := "%d,%d,%d" % [int(tile.get("x", -1)), int(tile.get("y", -1)), int(tile.get("level", -1))]
			control_owners[key] = int(control_owners.get(key, 0)) + 1
	var selected_guard := {}
	var selected_tile := {}
	for guard_value in guards:
		if not (guard_value is Dictionary):
			continue
		var guard: Dictionary = guard_value
		var primary: Dictionary = guard.get("primary_tile", {}) if guard.get("primary_tile", {}) is Dictionary else {}
		var tiles: Array = guard.get("package_guard_engagement_tiles", []) if guard.get("package_guard_engagement_tiles", []) is Array else []
		for tile_value in tiles:
			if not (tile_value is Dictionary):
				continue
			var tile: Dictionary = tile_value
			var key := "%d,%d,%d" % [int(tile.get("x", -1)), int(tile.get("y", -1)), int(tile.get("level", -1))]
			if int(control_owners.get(key, 0)) == 1 and tile != primary:
				selected_guard = guard
				selected_tile = tile
				break
		if not selected_guard.is_empty():
			break
	if selected_guard.is_empty() or selected_tile.is_empty():
		return {"ok": false, "reason": "missing_unique_non_body_guard_control_tile"}
	var adoption: Dictionary = service.convert_generated_payload(generated, {"feature_gate": REPORT_ID})
	var action_session = NativeRandomMapPackageSessionBridgeScript.build_session_from_adoption(adoption)
	var clear_session = NativeRandomMapPackageSessionBridgeScript.build_session_from_adoption(adoption)
	if action_session == null or clear_session == null:
		return {"ok": false, "reason": "session_adoption_failed"}
	_set_fixture_hero_position(action_session, selected_tile)
	var context_before: Dictionary = OverworldRulesScript.get_active_context(action_session)
	var action_ids := []
	for action_value in OverworldRulesScript.get_context_actions(action_session):
		if action_value is Dictionary:
			action_ids.append(String(action_value.get("id", "")))
	var move_from := {}
	var move_delta := Vector2i.ZERO
	var control_position := Vector2i(int(selected_tile.get("x", -1)), int(selected_tile.get("y", -1)))
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var delta := Vector2i(dx, dy)
			var from := control_position - delta
			if from.x < 0 or from.y < 0 or from.x >= int(map_document.get_width()) or from.y >= int(map_document.get_height()):
				continue
			_set_fixture_hero_position(action_session, {"x": from.x, "y": from.y})
			if OverworldRulesScript.tile_is_blocked(action_session, from.x, from.y) \
					or OverworldRulesScript.tile_has_route_interaction(action_session, from.x, from.y) \
					or OverworldRulesScript.tile_step_cuts_blocked_corner(action_session, from, control_position):
				continue
			move_from = {"x": from.x, "y": from.y}
			move_delta = delta
			break
		if not move_from.is_empty():
			break
	var battle_start := {}
	if not move_from.is_empty():
		_set_fixture_hero_position(action_session, move_from)
		battle_start = OverworldRulesScript.try_move(action_session, move_delta.x, move_delta.y)
	_set_fixture_hero_position(clear_session, selected_tile)
	var resolved: Array = clear_session.overworld.get("resolved_encounters", []) if clear_session.overworld.get("resolved_encounters", []) is Array else []
	resolved.append(String(selected_guard.get("placement_id", "")))
	clear_session.overworld["resolved_encounters"] = resolved
	var context_after: Dictionary = OverworldRulesScript.get_active_context(clear_session)
	var guard_after: Dictionary = OverworldRulesScript.guard_engagement_encounter_at_tile(
		clear_session,
		int(selected_tile.get("x", -1)),
		int(selected_tile.get("y", -1))
	)
	var ok: bool = bool(adoption.get("ok", false)) \
			and String(context_before.get("type", "")) == "encounter" \
			and String(context_before.get("encounter", {}).get("placement_id", "")) == String(selected_guard.get("placement_id", "")) \
			and action_ids.has("enter_battle") \
			and not move_from.is_empty() \
			and bool(battle_start.get("ok", false)) \
			and String(battle_start.get("route", "")) == "battle" \
			and not action_session.battle.is_empty() \
			and String(context_after.get("type", "")) != "encounter" \
			and guard_after.is_empty()
	return {
		"ok": ok,
		"placement_id": selected_guard.get("placement_id", ""),
		"primary_tile": selected_guard.get("primary_tile", {}),
		"control_tile": selected_tile,
		"control_tile_is_non_body": selected_tile != selected_guard.get("primary_tile", {}),
		"control_tile_owner_count": control_owners.get("%d,%d,%d" % [int(selected_tile.get("x", -1)), int(selected_tile.get("y", -1)), int(selected_tile.get("level", -1))], 0),
		"context_before": context_before.get("type", ""),
		"action_ids": action_ids,
		"move_from": move_from,
		"move_delta": {"x": move_delta.x, "y": move_delta.y},
		"battle_started": not action_session.battle.is_empty(),
		"battle_route": battle_start.get("route", ""),
		"battle_message": battle_start.get("message", ""),
		"context_after_clear": context_after.get("type", ""),
		"guard_after_clear_empty": guard_after.is_empty(),
	}

func _set_fixture_hero_position(session: Variant, tile: Dictionary) -> void:
	var position := {"x": int(tile.get("x", -1)), "y": int(tile.get("y", -1))}
	session.overworld["hero_position"] = position.duplicate(true)
	var active_hero: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	active_hero["position"] = position.duplicate(true)
	session.overworld["hero"] = active_hero
	var heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and bool(heroes[index].get("is_active", false)):
			var hero: Dictionary = heroes[index]
			hero["position"] = position.duplicate(true)
			heroes[index] = hero
	session.overworld["player_heroes"] = heroes

func _validate_zero_road_projection(service: Variant) -> Dictionary:
	var config := ScenarioSelectRulesScript.build_random_map_player_config(
		"owner-corpus-small-random-players-land-10184",
		"",
		"",
		3,
		"land",
		false,
		"homm3_small",
		ScenarioSelectRulesScript.RANDOM_MAP_TEMPLATE_SELECTION_MODE_CATALOG_AUTO
	)
	config["monster_strength"] = "weak"
	var first: Dictionary = service.generate_random_map(config, {"startup_path": "zero_road_projection_first"})
	var second: Dictionary = service.generate_random_map(config, {"startup_path": "zero_road_projection_repeat"})
	var first_map: Variant = first.get("map_document", null)
	var first_scenario: Variant = first.get("scenario_document", null)
	var terrain_layers: Dictionary = first_map.get_terrain_layers() if first_map != null else {}
	var roads: Array = terrain_layers.get("roads", []) if terrain_layers.get("roads", []) is Array else []
	var map_validation: Dictionary = service.validate_map_document(first_map) if first_map != null else {"ok": false}
	var scenario_validation: Dictionary = service.validate_scenario_document(first_scenario, first_map) if first_map != null and first_scenario != null else {"ok": false}
	var exact_repeat := String(first.get("final_payload_fnv1a32", "")) != "" \
			and String(first.get("final_payload_fnv1a32", "")) == String(second.get("final_payload_fnv1a32", "")) \
			and int(first.get("final_payload_byte_count", -1)) == int(second.get("final_payload_byte_count", -2)) \
			and int(first.get("runtime_object_count", -1)) == int(second.get("runtime_object_count", -2))
	return {
		"ok": bool(first.get("ok", false)) and bool(second.get("ok", false)) \
				and int(first.get("runtime_road_cell_count", -1)) == 0 \
				and int(terrain_layers.get("road_unique_tile_count", -1)) == 0 \
				and roads.is_empty() \
				and bool(map_validation.get("ok", false)) \
				and bool(scenario_validation.get("ok", false)) \
				and exact_repeat,
		"payload_hash": first.get("final_payload_fnv1a32", ""),
		"payload_bytes": first.get("final_payload_byte_count", -1),
		"objects": first.get("runtime_object_count", -1),
		"road_cells": first.get("runtime_road_cell_count", -1),
		"road_overlay_count": roads.size(),
		"map_validation": map_validation.get("ok", false),
		"scenario_validation": scenario_validation.get("ok", false),
		"exact_repeat": exact_repeat,
	}

func _validate_supported_workflow_matrix(service: Variant) -> bool:
	var supported_count := 0
	for size_record in [["small", 36], ["medium", 72], ["large", 108], ["homm3_extra_large", 144]]:
		for level_count in [1, 2]:
			for water_mode in ["land", "normal_water", "islands"]:
				var normalized: Dictionary = service.normalize_random_map_config(
					_config(String(size_record[0]), int(size_record[1]), level_count, water_mode, "1")
				)
				if not bool(normalized.get("supported_parity_config", false)):
					_fail("Supported workflow shape was rejected: %s" % JSON.stringify(normalized))
					return false
				if String(normalized.get("h3maped_strict_scope", "")).begins_with("unsupported"):
					_fail("Supported workflow shape has unsupported strict-scope metadata: %s" % JSON.stringify(normalized))
					return false
				supported_count += 1
	if supported_count != 24:
		_fail("Supported workflow matrix count mismatch: %d" % supported_count)
		return false
	var unsupported: Dictionary = service.generate_random_map(
		_config("homm3_extra_large", 144, 2, "normal_water", "77", "impossible")
	)
	if bool(unsupported.get("ok", true)) \
			or String(unsupported.get("error_code", "")) != "native_rmg_monster_strength_unsupported":
		_fail("Unsupported monster strength did not fail closed: %s" % JSON.stringify(unsupported))
		return false
	return true

func _generate_and_validate(
	service: Variant,
	config: Dictionary,
	expected_payload_bytes: int,
	expected_object_count: int
) -> Dictionary:
	var generated: Dictionary = service.generate_random_map(config, {"startup_path": "completion_boundary"})
	var map_document: Variant = generated.get("map_document", null)
	var scenario_document: Variant = generated.get("scenario_document", null)
	var map_validation: Dictionary = service.validate_map_document(map_document) if map_document != null else {"ok": false}
	var scenario_validation: Dictionary = service.validate_scenario_document(
		scenario_document,
		map_document
	) if map_document != null and scenario_document != null else {"ok": false}
	var start_contract: Dictionary = scenario_document.get_start_contract() if scenario_document != null else {}
	var starts: Array = start_contract.get("player_starts", []) if start_contract.get("player_starts", []) is Array else []
	var expected_player_count := int(config.get("player_constraints", {}).get("player_count", 0))
	var start_bindings_ok := starts.size() == expected_player_count
	var start_binding_details := []
	for start_value in starts:
		if not (start_value is Dictionary):
			start_bindings_ok = false
			continue
		var start: Dictionary = start_value
		var placement_id := String(start.get("town_placement_id", ""))
		var town: Dictionary = map_document.get_object_by_placement_id(placement_id) if map_document != null else {}
		var hero_start: Dictionary = start.get("hero_start_tile", {}) if start.get("hero_start_tile", {}) is Dictionary else {}
		var runtime_start: Dictionary = start.get("runtime_start_tile", {}) if start.get("runtime_start_tile", {}) is Dictionary else {}
		var runtime_start_usable := _runtime_start_tile_is_usable(map_document, runtime_start)
		start_binding_details.append({
			"player_slot": start.get("player_slot", 0),
			"town_placement_id": placement_id,
			"town_kind": town.get("kind", ""),
			"town_owner_slot": town.get("owner_slot", 0),
			"start_owner_slot": start.get("owner_slot", -1),
			"hero_start": hero_start,
			"runtime_start": runtime_start,
			"tiles_match": hero_start == runtime_start,
			"runtime_start_usable": runtime_start_usable,
		})
		if placement_id == "" \
				or String(town.get("kind", "")) != "town" \
				or int(town.get("owner_slot", 0)) != int(start.get("owner_slot", -1)) \
				or hero_start.is_empty() \
				or hero_start != runtime_start \
				or not runtime_start_usable:
			start_bindings_ok = false
	var ok := bool(generated.get("ok", false)) \
			and String(generated.get("generation_status", "")) == "native_rmg_complete" \
			and bool(generated.get("native_runtime_authoritative", false)) \
			and bool(generated.get("runtime_payload_projection_complete", false)) \
			and int(generated.get("final_payload_byte_count", -1)) == expected_payload_bytes \
			and int(generated.get("runtime_object_count", -1)) == expected_object_count \
			and map_document != null \
			and scenario_document != null \
			and int(map_document.get_object_count()) == expected_object_count \
			and bool(map_validation.get("ok", false)) \
			and bool(scenario_validation.get("ok", false)) \
			and int(start_contract.get("start_count", -1)) == expected_player_count \
			and int(start_contract.get("start_town_count", -1)) == expected_player_count \
			and start_bindings_ok
	return {
		"ok": ok,
		"generated": generated,
		"summary": {
			"payload_bytes": generated.get("final_payload_byte_count", -1),
			"objects": generated.get("runtime_object_count", -1),
			"starts": start_contract.get("start_count", -1),
			"start_bindings_ok": start_bindings_ok,
			"start_binding_details": start_binding_details,
		},
		"map_validation": map_validation,
		"scenario_validation": scenario_validation,
	}

func _runtime_start_tile_is_usable(map_document: Variant, tile: Dictionary) -> bool:
	if map_document == null or tile.is_empty():
		return false
	var x := int(tile.get("x", -1))
	var y := int(tile.get("y", -1))
	var level := int(tile.get("level", -1))
	if x < 0 or y < 0 or level < 0 or x >= int(map_document.get_width()) or y >= int(map_document.get_height()) or level >= int(map_document.get_level_count()):
		return false
	var terrain_layers: Dictionary = map_document.get_terrain_layers()
	var terrain: Dictionary = terrain_layers.get("terrain", {}) if terrain_layers.get("terrain", {}) is Dictionary else {}
	var levels: Array = terrain.get("levels", []) if terrain.get("levels", []) is Array else []
	if level >= levels.size() or not (levels[level] is PackedInt32Array):
		return false
	var terrain_values: PackedInt32Array = levels[level]
	var terrain_code := int(terrain_values[y * int(map_document.get_width()) + x]) & 0x3f
	if terrain_code == 8 or terrain_code == 9:
		return false
	var roads: Array = terrain_layers.get("roads", []) if terrain_layers.get("roads", []) is Array else []
	for road_value in roads:
		if not (road_value is Dictionary):
			continue
		var road_tiles: Array = road_value.get("tiles", []) if road_value.get("tiles", []) is Array else []
		for road_tile_value in road_tiles:
			if road_tile_value is Dictionary and int(road_tile_value.get("x", -2)) == x and int(road_tile_value.get("y", -2)) == y and int(road_tile_value.get("level", -2)) == level:
				return false
	for object_index in range(int(map_document.get_object_count())):
		var object: Dictionary = map_document.get_object_by_index(object_index)
		for field in ["package_block_tiles", "package_visit_tiles"]:
			var cells: Array = object.get(field, []) if object.get(field, []) is Array else []
			for cell_value in cells:
				if cell_value is Dictionary and int(cell_value.get("x", -2)) == x and int(cell_value.get("y", -2)) == y and int(cell_value.get("level", -2)) == level:
					return false
	return String(tile.get("selection_source", "")) != ""

func _player_owned_start(start_contract: Dictionary) -> Dictionary:
	var starts: Array = start_contract.get("player_starts", []) if start_contract.get("player_starts", []) is Array else []
	for start_value in starts:
		if start_value is Dictionary and String(start_value.get("owner", "")) == "player":
			return start_value
	return {}

func _execute_legal_player_step(session: Variant) -> Dictionary:
	if session == null:
		return {"ok": false, "reason": "missing_session"}
	var start := OverworldRulesScript.hero_position(session)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var target := start + Vector2i(dx, dy)
			if OverworldRulesScript.tile_is_blocked(session, target.x, target.y) \
					or OverworldRulesScript.tile_has_route_interaction(session, target.x, target.y) \
					or OverworldRulesScript.tile_step_cuts_blocked_corner(session, start, target):
				continue
			var move: Dictionary = OverworldRulesScript.try_move(session, dx, dy)
			var finish := OverworldRulesScript.hero_position(session)
			if bool(move.get("ok", false)) and finish != start:
				return {"ok": true, "from": {"x": start.x, "y": start.y}, "to": {"x": finish.x, "y": finish.y}, "result": move}
	return {"ok": false, "reason": "no_executable_neighbor", "from": {"x": start.x, "y": start.y}}

func _validate_round_trip(service: Variant, generated: Dictionary) -> Dictionary:
	var adoption: Dictionary = service.convert_generated_payload(generated, {"feature_gate": REPORT_ID})
	var map_path := "user://native_rmg_completion_boundary.amap"
	var scenario_path := "user://native_rmg_completion_boundary.ascenario"
	var map_save: Dictionary = service.save_map_package(adoption.get("map_document", null), map_path)
	var scenario_save: Dictionary = service.save_scenario_package(adoption.get("scenario_document", null), scenario_path)
	var map_load: Dictionary = service.load_map_package(map_path)
	var scenario_load: Dictionary = service.load_scenario_package(scenario_path)
	var loaded_map: Variant = map_load.get("map_document", null)
	var loaded_scenario: Variant = scenario_load.get("scenario_document", null)
	var loaded_contract: Dictionary = loaded_scenario.get_start_contract() if loaded_scenario != null else {}
	var ok := bool(adoption.get("ok", false)) \
			and bool(map_save.get("ok", false)) \
			and bool(scenario_save.get("ok", false)) \
			and bool(map_load.get("ok", false)) \
			and bool(scenario_load.get("ok", false)) \
			and loaded_map != null \
			and loaded_scenario != null \
			and int(loaded_map.get_object_count()) == 1326 \
			and int(loaded_contract.get("start_count", -1)) == 2
	DirAccess.remove_absolute(ProjectSettings.globalize_path(map_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scenario_path))
	return {
		"ok": ok,
		"map_saved": map_save.get("ok", false),
		"scenario_saved": scenario_save.get("ok", false),
		"map_loaded": map_load.get("ok", false),
		"scenario_loaded": scenario_load.get("ok", false),
	}

func _validate_session_startup() -> Dictionary:
	var config := ScenarioSelectRulesScript.build_random_map_player_config(
		"10",
		"",
		"",
		2,
		"land",
		false,
		"homm3_medium",
		ScenarioSelectRulesScript.RANDOM_MAP_TEMPLATE_SELECTION_MODE_CATALOG_AUTO
	)
	config["monster_strength"] = "weak"
	var setup: Dictionary = ScenarioSelectRulesScript.build_random_map_skirmish_setup_with_retry(
		config,
		"normal",
		{"max_attempts": 1, "mode": "none"}
	)
	var session = ScenarioSelectRulesScript.start_random_map_skirmish_session_from_setup(setup)
	var package_startup: Dictionary = setup.get("package_startup", {}) if setup.get("package_startup", {}) is Dictionary else {}
	var map_path := String(package_startup.get("map_path", ""))
	var scenario_path := String(package_startup.get("scenario_path", ""))
	var boundary: Dictionary = session.flags.get("generated_random_map_boundary", {}) if session != null and session.flags.get("generated_random_map_boundary", {}) is Dictionary else {}
	var ok := bool(setup.get("ok", false)) \
			and session != null \
			and String(session.scenario_id) != "" \
			and String(boundary.get("adoption_path", "")) == "native_rmg_generated_package_saved_loaded_from_disk"
	if map_path != "":
		DirAccess.remove_absolute(ProjectSettings.globalize_path(map_path))
	if scenario_path != "":
		DirAccess.remove_absolute(ProjectSettings.globalize_path(scenario_path))
	return {
		"ok": ok,
		"setup_ok": setup.get("ok", false),
		"scenario_id": session.scenario_id if session != null else "",
		"adoption_path": boundary.get("adoption_path", ""),
	}

func _config(
	size_class: String,
	dimension: int,
	level_count: int,
	water_mode: String,
	seed: String,
	monster_strength: String = "weak",
	player_count: int = 2
) -> Dictionary:
	return {
		"seed": seed,
		"size": {
			"width": dimension,
			"height": dimension,
			"level_count": level_count,
			"water_mode": water_mode,
			"size_class_id": size_class,
		},
		"monster_strength": monster_strength,
		"player_constraints": {
			"human_count": 1,
			"computer_count": player_count - 1,
			"player_count": player_count,
			"human_team_count": 1,
			"computer_team_count": 0,
		},
	}

func _fail(message: String) -> void:
	push_error("%s: %s" % [REPORT_ID, message])
	get_tree().quit(1)
