extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const NativeRandomMapPackageSessionBridgeScript = preload("res://scripts/persistence/NativeRandomMapPackageSessionBridge.gd")
const OverworldRulesScript = preload("res://scripts/core/OverworldRules.gd")
const OverworldMapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const ArtifactRulesScript = preload("res://scripts/core/ArtifactRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const REPORT_ID := "NATIVE_RMG_END_TO_END_RUNTIME_BOUNDARY_REPORT"
const CREATURE_GENERATOR_ROWS := {
	59: {
		"source_row": 220,
		"def_ref": "AVGpixie.def",
		"object_id": "object_greenbranch_copse",
		"site_id": "site_greenbranch_copse",
		"catalog_id": "dwelling_creature_generator_pixie_greenbranch_proxy",
		"gold": 105,
		"recruits": {"unit_neutral_greenbranch_cudgels": 2, "unit_neutral_sapwhistle_callers": 1},
	},
	52: {
		"source_row": 190,
		"def_ref": "AVGlich0.def",
		"object_id": "object_lantern_warren",
		"site_id": "site_lantern_warren",
		"catalog_id": "dwelling_creature_generator_lich_lantern_proxy",
		"gold": 90,
		"recruits": {"unit_neutral_tunnel_lanterns": 2, "unit_neutral_glimmercap_needlers": 1},
	},
	22: {
		"source_row": 180,
		"def_ref": "AVGgogs0.def",
		"object_id": "object_cinder_kiln",
		"site_id": "site_cinder_kiln",
		"catalog_id": "dwelling_creature_generator_gog_cinder_kiln_proxy",
		"gold": 75,
		"recruits": {"unit_neutral_kilnward_mallets": 2, "unit_neutral_cinderpot_hurlers": 1},
	},
	0: {
		"source_row": 210,
		"def_ref": "AVGbasl0.def",
		"object_id": "object_bogbell_croft",
		"site_id": "site_bogbell_croft",
		"catalog_id": "dwelling_creature_generator_basilisk_bogbell_proxy",
		"gold": 105,
		"recruits": {"unit_neutral_bogbell_mauls": 2, "unit_neutral_peatflare_jarriers": 1},
	},
	5: {
		"source_row": 163,
		"def_ref": "AVGcavl0.def",
		"object_id": "object_roadward_lodge",
		"site_id": "site_free_company_yard",
		"catalog_id": "dwelling_creature_generator_cavalier_roadward_proxy",
		"gold": 80,
		"recruits": {"unit_neutral_roadwardens": 2, "unit_neutral_hearthbow_carriers": 1},
	},
	50: {
		"source_row": 168,
		"def_ref": "AVGpega0.def",
		"object_id": "object_kite_signal_eyrie",
		"site_id": "site_kite_signal_eyrie",
		"catalog_id": "dwelling_creature_generator_pegasus_kite_signal_eyrie_proxy",
		"gold": 75,
		"recruits": {"unit_neutral_kitehook_runners": 2, "unit_neutral_ridgeflare_shots": 1},
	},
	26: {
		"source_row": 194,
		"def_ref": "AVGharp0.def",
		"object_id": "object_cliffhawk_roost",
		"site_id": "site_cliffhawk_roost",
		"catalog_id": "dwelling_creature_generator_harpy_cliffhawk_roost_proxy",
		"gold": 75,
		"recruits": {"unit_neutral_cliffhawk_wardens": 2, "unit_neutral_windglass_slingers": 1},
	},
}
const LOOSE_RESOURCE_PRESENTATION_ROWS := [
	{"site_id": "site_peatwax_reed_yard", "object_id": "object_marsh_peat_yard", "resource_id": "peatwax", "asset_id": "resource_pickup_peatwax", "mine_asset_id": "mapobj_marsh_peat_yard", "expected_footprint": {"width": 2, "height": 2}, "texture_path": "res://art/overworld/runtime/objects/pickups/peatwax_reed_bundle.png", "rewards": {"gold": 120, "peatwax": 1}, "current_small": false},
	{"site_id": "site_embergrain_warm_granary", "object_id": "object_floodplain_sluice_camp", "resource_id": "embergrain", "asset_id": "resource_pickup_embergrain", "mine_asset_id": "mapobj_floodplain_sluice_camp", "expected_footprint": {"width": 2, "height": 3}, "texture_path": "res://art/overworld/runtime/objects/pickups/embergrain_sack.png", "rewards": {"gold": 120, "embergrain": 1}, "current_small": true},
	{"site_id": "site_aetherglass_lens_house", "object_id": "object_cinder_ore_face", "resource_id": "aetherglass", "asset_id": "resource_pickup_aetherglass", "mine_asset_id": "mapobj_cinder_ore_face", "expected_footprint": {"width": 2, "height": 2}, "texture_path": "res://art/overworld/runtime/objects/pickups/aetherglass_lens_crate.png", "rewards": {"gold": 120, "aetherglass": 1}, "current_small": true},
	{"site_id": "site_memory_salt_pan", "object_id": "object_badlands_coin_sluice", "resource_id": "memory_salt", "asset_id": "resource_pickup_memory_salt", "mine_asset_id": "mapobj_badlands_coin_sluice", "expected_footprint": {"width": 3, "height": 3}, "texture_path": "res://art/overworld/runtime/objects/pickups/memory_salt_reliquary.png", "rewards": {"gold": 120, "memory_salt": 1}, "current_small": true},
	{"site_id": "site_reef_coin_assay", "object_id": "object_reef_coin_assay", "resource_id": "gold", "asset_id": "resource_pickup_gold", "mine_asset_id": "mapobj_reef_coin_assay", "expected_footprint": {"width": 2, "height": 2}, "texture_path": "res://art/overworld/runtime/objects/pickups/reef_coin_coffer.png", "rewards": {"gold": 220}, "current_small": true},
]

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
	var live_proxy_projection: Dictionary = await _validate_live_proxy_site_projection(service)
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
	var medium_creature_generator_projection: Dictionary = _validate_medium_creature_generator_projection(service, medium.get("generated", {}))
	if not bool(medium_creature_generator_projection.get("ok", false)):
		_fail("Medium Creature Generator dwelling projection failed: %s" % JSON.stringify(medium_creature_generator_projection))
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
	var xlarge_creature_generator_projection: Dictionary = _validate_xlarge_creature_generator_projection(service, xlarge.get("generated", {}))
	if not bool(xlarge_creature_generator_projection.get("ok", false)):
		_fail("XLarge Creature Generator dwelling projection failed: %s" % JSON.stringify(xlarge_creature_generator_projection))
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
		"medium_creature_generator_projection": medium_creature_generator_projection,
		"medium_guard_projection": medium_guard_projection,
		"medium_guard_live_behavior": medium_guard_live_behavior,
		"medium_ordinal_95": ordinal_95.get("summary", {}),
		"medium_ordinal_95_town_anchor": {"x": 31, "y": 10},
		"medium_ordinal_95_runtime_start": ordinal_95_runtime_start,
		"medium_ordinal_95_hero_position": ordinal_95_hero_position,
		"medium_ordinal_95_player_move": ordinal_95_player_move,
		"xlarge": xlarge.get("summary", {}),
		"xlarge_creature_generator_projection": xlarge_creature_generator_projection,
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
	var creature_generator_rows_exact := true
	var creature_generator_placement_ids := {}
	var creature_bank_count := 0
	var unsupported_bank_rows_exact := true
	var artifact_proxy_count := 0
	var artifact_proxy_rows_exact := true
	var artifact_proxy_placement_ids := {}
	var resource_proxy_count := 0
	var resource_proxy_rows_exact := true
	var resource_proxy_subtypes := {}
	var spell_scroll_count := 0
	var spell_scroll_rows_exact := true
	var spell_scroll_placement_ids := {}
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
			creature_generator_placement_ids[String(object.get("placement_id", ""))] = true
			var expected_dwelling: Dictionary = CREATURE_GENERATOR_ROWS.get(subtype, {}) if CREATURE_GENERATOR_ROWS.get(subtype, {}) is Dictionary else {}
			if expected_dwelling.is_empty() \
					or String(object.get("kind", "")) != "neutral_dwelling" \
					or String(object.get("object_id", "")) != String(expected_dwelling.get("object_id", "")) \
					or String(object.get("native_proxy_object_id", "")) != String(expected_dwelling.get("object_id", "")) \
					or String(object.get("site_id", "")) != "" \
					or int(object.get("homm3_re_object_source_row", -1)) != int(expected_dwelling.get("source_row", -2)) \
					or String(object.get("homm3_re_object_def_ref", "")) != String(expected_dwelling.get("def_ref", "")) \
					or String(object.get("homm3_re_reward_object_catalog_id", "")) != String(expected_dwelling.get("catalog_id", "")) \
					or not _live_proxy_provenance_exact(object):
				creature_generator_rows_exact = false
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
		elif type_id == 93:
			spell_scroll_count += 1
			spell_scroll_placement_ids[String(object.get("placement_id", ""))] = true
			if subtype != 0 \
					or String(object.get("kind", "")) != "reward_reference" \
					or String(object.get("object_id", "")) != "spell_beacon_path" \
					or String(object.get("native_proxy_object_id", "")) != "spell_beacon_path" \
					or String(object.get("site_id", "")) != "site_beacon_path_scroll" \
					or String(object.get("homm3_re_reward_object_catalog_id", "")) != "reward_spell_scroll_proxy" \
					or String(object.get("homm3_re_object_def_ref", "")) != "AVA0001.def" \
					or not _live_proxy_provenance_exact(object):
				spell_scroll_rows_exact = false
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
	var loose_resource_mine_nodes_by_site := {}
	var live_campfires := []
	var live_creature_generators := []
	var live_artifacts := []
	var artifact_resource_node_count := 0
	var live_resource_proxy_count := 0
	var live_resource_proxy_rows_exact := true
	var loose_resource_nodes_by_site := {}
	var selected_rare_resource := {}
	var live_spell_scrolls := []
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
				var mine_site_id := String(node.get("site_id", ""))
				for presentation_row in LOOSE_RESOURCE_PRESENTATION_ROWS:
					if presentation_row is Dictionary and String(presentation_row.get("site_id", "")) == mine_site_id and not loose_resource_mine_nodes_by_site.has(mine_site_id):
						loose_resource_mine_nodes_by_site[mine_site_id] = node.duplicate(true)
			elif int(source.get("h3m_type_id", -1)) == 12:
				live_campfires.append({"index": node_index, "node": node.duplicate(true)})
			elif int(source.get("h3m_type_id", -1)) == 17:
				var expected_dwelling: Dictionary = CREATURE_GENERATOR_ROWS.get(int(source.get("h3m_subtype", -1)), {}) if CREATURE_GENERATOR_ROWS.get(int(source.get("h3m_subtype", -1)), {}) is Dictionary else {}
				if not expected_dwelling.is_empty() \
						and creature_generator_placement_ids.has(String(node.get("placement_id", ""))) \
						and String(node.get("kind", "")) == "neutral_dwelling" \
						and String(node.get("object_id", "")) == String(expected_dwelling.get("object_id", "")) \
						and String(node.get("site_id", "")) == String(expected_dwelling.get("site_id", "")):
					live_creature_generators.append({
						"index": node_index,
						"subtype": int(source.get("h3m_subtype", -1)),
						"node": node.duplicate(true),
					})
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
				var loose_site_id := String(node.get("site_id", ""))
				for presentation_row in LOOSE_RESOURCE_PRESENTATION_ROWS:
					if presentation_row is Dictionary and String(presentation_row.get("site_id", "")) == loose_site_id and not loose_resource_nodes_by_site.has(loose_site_id):
						loose_resource_nodes_by_site[loose_site_id] = node.duplicate(true)
			elif int(source.get("h3m_type_id", -1)) == 93:
				if String(node.get("object_id", "")) == "spell_beacon_path" \
						and String(node.get("site_id", "")) == "site_beacon_path_scroll" \
						and spell_scroll_placement_ids.has(String(node.get("placement_id", ""))):
					live_spell_scrolls.append({"index": node_index, "node": node.duplicate(true)})
		var artifact_nodes: Array = session.overworld.get("artifact_nodes", []) if session.overworld.get("artifact_nodes", []) is Array else []
		for artifact_index in range(artifact_nodes.size()):
			var artifact_value: Variant = artifact_nodes[artifact_index]
			if not (artifact_value is Dictionary):
				continue
			var artifact_node: Dictionary = artifact_value
			if artifact_proxy_placement_ids.has(String(artifact_node.get("placement_id", ""))):
				live_artifacts.append({"index": artifact_index, "node": artifact_node.duplicate(true)})
	var loose_resource_presentation := {}
	if session != null:
		loose_resource_presentation = await _validate_loose_resource_presentation(session, loose_resource_nodes_by_site, loose_resource_mine_nodes_by_site)
	var creature_generator_interaction: Dictionary = _validate_creature_generator_interaction(adoption, [59, 52])
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
	var spell_scroll_interaction := {}
	var spell_scroll_presentation := {}
	if session != null and live_spell_scrolls.size() == 1:
		var scroll_result: Dictionary = live_spell_scrolls[0]
		var scroll_node: Dictionary = scroll_result.get("node", {}) if scroll_result.get("node", {}) is Dictionary else {}
		spell_scroll_presentation = await _validate_spell_scroll_presentation(session, scroll_node)
		var scroll_index := int(scroll_result.get("index", -1))
		var resources_before: Dictionary = session.overworld.get("resources", {}).duplicate(true)
		var artifact_nodes_before: Array = session.overworld.get("artifact_nodes", []).duplicate(true) if session.overworld.get("artifact_nodes", []) is Array else []
		var resource_nodes_before: Array = session.overworld.get("resource_nodes", []).duplicate(true) if session.overworld.get("resource_nodes", []) is Array else []
		var hero_before: Dictionary = session.overworld.get("hero", {}).duplicate(true)
		var army_before: Dictionary = session.overworld.get("army", {}).duplicate(true)
		var spellbook_before: Dictionary = hero_before.get("spellbook", {}).duplicate(true) if hero_before.get("spellbook", {}) is Dictionary else {}
		var known_before: Array = spellbook_before.get("known_spell_ids", []).duplicate(true) if spellbook_before.get("known_spell_ids", []) is Array else []
		var expected_known_after: Array = known_before.duplicate(true)
		expected_known_after.append("spell_beacon_path")
		var claim: Dictionary = OverworldRulesScript._collect_resource_node_result(session, scroll_result, false)
		var resource_nodes_after: Array = session.overworld.get("resource_nodes", []) if session.overworld.get("resource_nodes", []) is Array else []
		var claimed_node: Dictionary = resource_nodes_after[scroll_index] if scroll_index >= 0 and scroll_index < resource_nodes_after.size() and resource_nodes_after[scroll_index] is Dictionary else {}
		var hero_after: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
		var spellbook_after: Dictionary = hero_after.get("spellbook", {}) if hero_after.get("spellbook", {}) is Dictionary else {}
		var known_after: Array = spellbook_after.get("known_spell_ids", []) if spellbook_after.get("known_spell_ids", []) is Array else []
		var spellbook_before_without_known: Dictionary = spellbook_before.duplicate(true)
		var spellbook_after_without_known: Dictionary = spellbook_after.duplicate(true)
		spellbook_before_without_known.erase("known_spell_ids")
		spellbook_after_without_known.erase("known_spell_ids")
		var hero_before_without_spellbook: Dictionary = hero_before.duplicate(true)
		var hero_after_without_spellbook: Dictionary = hero_after.duplicate(true)
		hero_before_without_spellbook.erase("spellbook")
		hero_after_without_spellbook.erase("spellbook")
		var unrelated_nodes_exact := resource_nodes_before.size() == resource_nodes_after.size()
		if unrelated_nodes_exact:
			for node_index in range(resource_nodes_before.size()):
				if node_index != scroll_index and resource_nodes_before[node_index] != resource_nodes_after[node_index]:
					unrelated_nodes_exact = false
					break
		var repeat_claim: Dictionary = OverworldRulesScript._collect_resource_node_result(session, {"index": scroll_index, "node": claimed_node}, false)
		var restored = SessionStateStoreScript.SessionData.new()
		restored.from_dict(session.to_dict())
		var restored_nodes: Array = restored.overworld.get("resource_nodes", []) if restored.overworld.get("resource_nodes", []) is Array else []
		var restored_node: Dictionary = restored_nodes[scroll_index] if scroll_index >= 0 and scroll_index < restored_nodes.size() and restored_nodes[scroll_index] is Dictionary else {}
		var restored_hero: Dictionary = restored.overworld.get("hero", {}) if restored.overworld.get("hero", {}) is Dictionary else {}
		spell_scroll_interaction = {
			"ok": bool(claim.get("ok", false)) \
					and not known_before.has("spell_beacon_path") \
					and known_after == expected_known_after \
					and bool(claimed_node.get("collected", false)) \
					and session.overworld.get("resources", {}) == resources_before \
					and session.overworld.get("artifact_nodes", []) == artifact_nodes_before \
					and session.overworld.get("army", {}) == army_before \
					and hero_before_without_spellbook == hero_after_without_spellbook \
					and spellbook_before_without_known == spellbook_after_without_known \
					and unrelated_nodes_exact \
					and not bool(repeat_claim.get("ok", false)) \
					and restored_node == claimed_node \
					and restored_hero.get("spellbook", {}) == spellbook_after,
			"placement_id": scroll_node.get("placement_id", ""),
			"site_id": claimed_node.get("site_id", ""),
			"claim_ok": claim.get("ok", false),
			"known_before": known_before,
			"known_after": known_after,
			"resources_exact": session.overworld.get("resources", {}) == resources_before,
			"artifacts_exact": session.overworld.get("artifact_nodes", []) == artifact_nodes_before,
			"army_exact": session.overworld.get("army", {}) == army_before,
			"unrelated_nodes_exact": unrelated_nodes_exact,
			"repeat_rejected": not bool(repeat_claim.get("ok", false)),
			"save_round_trip_exact": restored_node == claimed_node and restored_hero.get("spellbook", {}) == spellbook_after,
		}
	var exact_repeat: bool = bool(second.get("ok", false)) \
			and first.get("final_payload_fnv1a32", "") == second.get("final_payload_fnv1a32", "") \
			and first.get("final_payload_byte_count", -1) == second.get("final_payload_byte_count", -2) \
			and exact_identity == repeat_identity
	return {
		"ok": bool(first.get("ok", false)) \
				and String(first.get("final_payload_fnv1a32", "")) == "457dba6b" \
				and int(first.get("final_payload_byte_count", -1)) == 23664 \
				and int(first.get("runtime_object_count", -1)) == 294 \
				and mine_count == 18 \
				and mine_subtypes.size() == 7 \
				and mine_rows_exact \
				and campfire_count == 2 \
				and campfire_rows_exact \
				and creature_generator_count == 2 \
				and creature_generator_rows_exact \
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
				and spell_scroll_count == 1 \
				and spell_scroll_rows_exact \
				and bool(adoption.get("ok", false)) \
				and session != null \
				and live_mine_count == mine_count \
				and live_mine_sites_exact \
				and live_campfires.size() == campfire_count \
				and bool(interaction.get("ok", false)) \
				and live_creature_generators.size() == creature_generator_count \
				and bool(creature_generator_interaction.get("ok", false)) \
				and artifact_resource_node_count == 0 \
				and live_artifacts.size() == artifact_proxy_count \
				and bool(artifact_interaction.get("ok", false)) \
				and live_resource_proxy_count == resource_proxy_count \
				and live_resource_proxy_rows_exact \
				and bool(loose_resource_presentation.get("ok", false)) \
				and bool(rare_resource_interaction.get("ok", false)) \
				and live_spell_scrolls.size() == spell_scroll_count \
				and bool(spell_scroll_presentation.get("ok", false)) \
				and bool(spell_scroll_interaction.get("ok", false)) \
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
		"creature_generator_rows_exact": creature_generator_rows_exact,
		"live_creature_generator_count": live_creature_generators.size(),
		"creature_generator_interaction": creature_generator_interaction,
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
		"loose_resource_presentation": loose_resource_presentation,
		"spell_scroll_count": spell_scroll_count,
		"spell_scroll_rows_exact": spell_scroll_rows_exact,
		"live_spell_scroll_count": live_spell_scrolls.size(),
		"live_mine_count": live_mine_count,
		"live_mine_sites_exact": live_mine_sites_exact,
		"live_campfire_count": live_campfires.size(),
		"interaction": interaction,
		"artifact_interaction": artifact_interaction,
		"rare_resource_interaction": rare_resource_interaction,
		"spell_scroll_presentation": spell_scroll_presentation,
		"spell_scroll_interaction": spell_scroll_interaction,
		"exact_repeat": exact_repeat,
	}

func _validate_medium_creature_generator_projection(service: Variant, generated: Dictionary) -> Dictionary:
	var map_document: Variant = generated.get("map_document", null)
	if map_document == null:
		return {"ok": false, "reason": "missing_medium_map_document"}
	var expected_rows := {
		0: {
			"placement_id": "native_h3maped_e76c8967_object_1162",
			"x": 9,
			"y": 37,
			"body_tiles": [{"x": 8, "y": 37, "level": 0}, {"x": 9, "y": 37, "level": 0}],
		},
		22: {
			"placement_id": "native_h3maped_e76c8967_object_1208",
			"x": 66,
			"y": 10,
			"body_tiles": [{"x": 65, "y": 10, "level": 0}, {"x": 66, "y": 10, "level": 0}],
		},
		5: {
			"placement_id": "native_h3maped_e76c8967_object_1322",
			"x": 21,
			"y": 63,
			"body_tiles": [{"x": 20, "y": 63, "level": 0}, {"x": 21, "y": 63, "level": 0}],
		},
	}
	var ordered_subtypes: Array[int] = []
	var type17_authority: Array[Dictionary] = []
	var rows_exact := true
	for object_index in range(int(map_document.get_object_count())):
		var object: Dictionary = map_document.get_object_by_index(object_index)
		if int(object.get("h3m_type_id", -1)) != 17:
			continue
		var subtype := int(object.get("h3m_subtype", -1))
		ordered_subtypes.append(subtype)
		type17_authority.append(_proxy_projection_object_authority(object))
		var expected: Dictionary = expected_rows.get(subtype, {}) if expected_rows.get(subtype, {}) is Dictionary else {}
		if expected.is_empty() \
				or String(object.get("placement_id", "")) != String(expected.get("placement_id", "")) \
				or int(object.get("x", -1)) != int(expected.get("x", -2)) \
				or int(object.get("y", -1)) != int(expected.get("y", -2)) \
				or int(object.get("level", -1)) != 0 \
				or object.get("body_tiles", []) != expected.get("body_tiles", []) \
				or object.get("action_tiles", []) != [] \
				or not bool(object.get("blocking_body", false)):
			rows_exact = false
		if subtype in [0, 22, 5]:
			var expected_dwelling: Dictionary = CREATURE_GENERATOR_ROWS.get(subtype, {})
			if String(object.get("kind", "")) != "neutral_dwelling" \
					or String(object.get("object_id", "")) != String(expected_dwelling.get("object_id", "")) \
					or String(object.get("native_proxy_object_id", "")) != String(expected_dwelling.get("object_id", "")) \
					or String(object.get("site_id", "")) != "" \
					or int(object.get("homm3_re_object_source_row", -1)) != int(expected_dwelling.get("source_row", -2)) \
					or String(object.get("homm3_re_object_def_ref", "")) != String(expected_dwelling.get("def_ref", "")) \
					or String(object.get("homm3_re_reward_object_catalog_id", "")) != String(expected_dwelling.get("catalog_id", "")) \
					or not _live_proxy_provenance_exact(object):
				rows_exact = false
		elif String(object.get("kind", "")) != "h3m_object" \
				or String(object.get("object_id", "")) != "" \
				or String(object.get("native_proxy_object_id", "")) != "" \
				or String(object.get("site_id", "")) != "" \
				or int(object.get("homm3_re_object_source_row", -1)) != -1 \
				or String(object.get("homm3_re_object_def_ref", "")) != "" \
				or String(object.get("homm3_re_reward_object_catalog_id", "")) != "":
			rows_exact = false
	var repeat: Dictionary = service.generate_random_map(_config("medium", 72, 1, "land", "10"), {"startup_path": "medium_creature_generator_projection_repeat"})
	var repeat_map: Variant = repeat.get("map_document", null)
	var repeat_type17_authority: Array[Dictionary] = []
	if repeat_map != null:
		for object_index in range(int(repeat_map.get_object_count())):
			var object: Dictionary = repeat_map.get_object_by_index(object_index)
			if int(object.get("h3m_type_id", -1)) == 17:
				repeat_type17_authority.append(_proxy_projection_object_authority(object))
	var repeat_exact: bool = bool(repeat.get("ok", false)) \
			and String(repeat.get("final_payload_fnv1a32", "")) == String(generated.get("final_payload_fnv1a32", "")) \
			and int(repeat.get("final_payload_byte_count", -1)) == int(generated.get("final_payload_byte_count", -2)) \
			and int(repeat.get("runtime_object_count", -1)) == int(generated.get("runtime_object_count", -2)) \
			and repeat_type17_authority == type17_authority
	var adoption: Dictionary = service.convert_generated_payload(generated, {"feature_gate": REPORT_ID})
	var interaction: Dictionary = _validate_creature_generator_interaction(adoption, [0, 22, 5])
	return {
		"ok": String(generated.get("final_payload_fnv1a32", "")) == "e76c8967" \
				and int(generated.get("final_payload_byte_count", -1)) == 79333 \
				and int(generated.get("runtime_object_count", -1)) == 1326 \
				and ordered_subtypes == [0, 22, 5] \
				and rows_exact \
				and repeat_exact \
				and bool(adoption.get("ok", false)) \
				and bool(interaction.get("ok", false)),
		"payload_hash": generated.get("final_payload_fnv1a32", ""),
		"payload_bytes": generated.get("final_payload_byte_count", -1),
		"object_count": generated.get("runtime_object_count", -1),
		"ordered_subtypes": ordered_subtypes,
		"rows_exact": rows_exact,
		"repeat_exact": repeat_exact,
		"interaction": interaction,
	}

func _validate_xlarge_creature_generator_projection(service: Variant, generated: Dictionary) -> Dictionary:
	var map_document: Variant = generated.get("map_document", null)
	if map_document == null:
		return {"ok": false, "reason": "missing_xlarge_map_document"}
	var expected_rows: Array[Dictionary] = [
		{"subtype": 30, "placement_id": "native_h3maped_33610c0a_object_1932", "x": 90, "y": 81, "level": 0, "body_tiles": [{"x": 89, "y": 81, "level": 0}, {"x": 90, "y": 81, "level": 0}]},
		{"subtype": 29, "placement_id": "native_h3maped_33610c0a_object_1976", "x": 53, "y": 84, "level": 1, "body_tiles": [{"x": 52, "y": 84, "level": 1}, {"x": 53, "y": 84, "level": 1}]},
		{"subtype": 15, "placement_id": "native_h3maped_33610c0a_object_2015", "x": 5, "y": 93, "level": 0, "body_tiles": [{"x": 4, "y": 93, "level": 0}, {"x": 5, "y": 93, "level": 0}]},
		{"subtype": 15, "placement_id": "native_h3maped_33610c0a_object_2026", "x": 20, "y": 94, "level": 0, "body_tiles": [{"x": 19, "y": 94, "level": 0}, {"x": 20, "y": 94, "level": 0}]},
		{"subtype": 6, "placement_id": "native_h3maped_33610c0a_object_2085", "x": 118, "y": 86, "level": 0, "body_tiles": [{"x": 117, "y": 86, "level": 0}, {"x": 118, "y": 86, "level": 0}]},
		{"subtype": 45, "placement_id": "native_h3maped_33610c0a_object_2124", "x": 118, "y": 106, "level": 0, "body_tiles": [{"x": 117, "y": 106, "level": 0}, {"x": 118, "y": 106, "level": 0}]},
		{"subtype": 68, "placement_id": "native_h3maped_33610c0a_object_2169", "x": 125, "y": 119, "level": 0, "body_tiles": [{"x": 124, "y": 119, "level": 0}, {"x": 125, "y": 119, "level": 0}]},
		{"subtype": 26, "placement_id": "native_h3maped_33610c0a_object_2206", "x": 86, "y": 63, "level": 1, "body_tiles": [{"x": 85, "y": 63, "level": 1}, {"x": 86, "y": 63, "level": 1}]},
		{"subtype": 40, "placement_id": "native_h3maped_33610c0a_object_2458", "x": 128, "y": 28, "level": 0, "body_tiles": [{"x": 127, "y": 28, "level": 0}, {"x": 128, "y": 28, "level": 0}]},
		{"subtype": 45, "placement_id": "native_h3maped_33610c0a_object_2614", "x": 16, "y": 42, "level": 0, "body_tiles": [{"x": 15, "y": 42, "level": 0}, {"x": 16, "y": 42, "level": 0}]},
		{"subtype": 68, "placement_id": "native_h3maped_33610c0a_object_2626", "x": 13, "y": 51, "level": 0, "body_tiles": [{"x": 12, "y": 51, "level": 0}, {"x": 13, "y": 51, "level": 0}]},
		{"subtype": 50, "placement_id": "native_h3maped_33610c0a_object_2661", "x": 23, "y": 52, "level": 0, "body_tiles": [{"x": 22, "y": 52, "level": 0}, {"x": 23, "y": 52, "level": 0}]},
	]
	var ordered_subtypes: Array[int] = []
	var type17_authority: Array[Dictionary] = []
	var rows_exact := true
	var row_index := 0
	for object_index in range(int(map_document.get_object_count())):
		var object: Dictionary = map_document.get_object_by_index(object_index)
		if int(object.get("h3m_type_id", -1)) != 17:
			continue
		var subtype := int(object.get("h3m_subtype", -1))
		ordered_subtypes.append(subtype)
		type17_authority.append(_proxy_projection_object_authority(object))
		var expected: Dictionary = expected_rows[row_index] if row_index < expected_rows.size() else {}
		row_index += 1
		if expected.is_empty() \
				or subtype != int(expected.get("subtype", -2)) \
				or String(object.get("placement_id", "")) != String(expected.get("placement_id", "")) \
				or int(object.get("x", -1)) != int(expected.get("x", -2)) \
				or int(object.get("y", -1)) != int(expected.get("y", -2)) \
				or int(object.get("level", -1)) != int(expected.get("level", -2)) \
				or object.get("body_tiles", []) != expected.get("body_tiles", []) \
				or object.get("action_tiles", []) != [] \
				or not bool(object.get("blocking_body", false)):
			rows_exact = false
		if subtype in [26, 50]:
			var expected_dwelling: Dictionary = CREATURE_GENERATOR_ROWS.get(subtype, {})
			if String(object.get("kind", "")) != "neutral_dwelling" \
					or String(object.get("object_id", "")) != String(expected_dwelling.get("object_id", "")) \
					or String(object.get("native_proxy_object_id", "")) != String(expected_dwelling.get("object_id", "")) \
					or String(object.get("site_id", "")) != "" \
					or int(object.get("homm3_re_object_source_row", -1)) != int(expected_dwelling.get("source_row", -2)) \
					or String(object.get("homm3_re_object_def_ref", "")) != String(expected_dwelling.get("def_ref", "")) \
					or String(object.get("homm3_re_reward_object_catalog_id", "")) != String(expected_dwelling.get("catalog_id", "")) \
					or not _live_proxy_provenance_exact(object):
				rows_exact = false
		elif String(object.get("kind", "")) != "h3m_object" \
				or String(object.get("object_id", "")) != "" \
				or String(object.get("native_proxy_object_id", "")) != "" \
				or String(object.get("site_id", "")) != "" \
				or int(object.get("homm3_re_object_source_row", -1)) != -1 \
				or String(object.get("homm3_re_object_def_ref", "")) != "" \
				or String(object.get("homm3_re_reward_object_catalog_id", "")) != "":
			rows_exact = false
	var repeat: Dictionary = service.generate_random_map(_config("homm3_extra_large", 144, 2, "normal_water", "77"), {"startup_path": "xlarge_creature_generator_projection_repeat"})
	var repeat_map: Variant = repeat.get("map_document", null)
	var repeat_type17_authority: Array[Dictionary] = []
	if repeat_map != null:
		for object_index in range(int(repeat_map.get_object_count())):
			var object: Dictionary = repeat_map.get_object_by_index(object_index)
			if int(object.get("h3m_type_id", -1)) == 17:
				repeat_type17_authority.append(_proxy_projection_object_authority(object))
	var repeat_exact: bool = bool(repeat.get("ok", false)) \
			and String(repeat.get("final_payload_fnv1a32", "")) == String(generated.get("final_payload_fnv1a32", "")) \
			and int(repeat.get("final_payload_byte_count", -1)) == int(generated.get("final_payload_byte_count", -2)) \
			and int(repeat.get("runtime_object_count", -1)) == int(generated.get("runtime_object_count", -2)) \
			and repeat_type17_authority == type17_authority
	var adoption: Dictionary = service.convert_generated_payload(generated, {"feature_gate": REPORT_ID})
	var interaction: Dictionary = _validate_creature_generator_interaction(adoption, [26, 50])
	return {
		"ok": String(generated.get("final_payload_fnv1a32", "")) == "33610c0a" \
				and int(generated.get("final_payload_byte_count", -1)) == 365777 \
				and int(generated.get("runtime_object_count", -1)) == 2779 \
				and ordered_subtypes == [30, 29, 15, 15, 6, 45, 68, 26, 40, 45, 68, 50] \
				and row_index == expected_rows.size() \
				and rows_exact \
				and repeat_exact \
				and bool(adoption.get("ok", false)) \
				and bool(interaction.get("ok", false)),
		"payload_hash": generated.get("final_payload_fnv1a32", ""),
		"payload_bytes": generated.get("final_payload_byte_count", -1),
		"object_count": generated.get("runtime_object_count", -1),
		"ordered_subtypes": ordered_subtypes,
		"rows_exact": rows_exact,
		"repeat_exact": repeat_exact,
		"interaction": interaction,
	}

func _validate_creature_generator_interaction(adoption: Dictionary, expected_subtypes: Array[int]) -> Dictionary:
	var session = NativeRandomMapPackageSessionBridgeScript.build_session_from_adoption(adoption)
	if session == null:
		return {"ok": false, "reason": "missing_adopted_session"}
	var source_objects: Dictionary = session.overworld.get("package_source_objects_by_id", {}) if session.overworld.get("package_source_objects_by_id", {}) is Dictionary else {}
	var nodes_before: Array = session.overworld.get("resource_nodes", []).duplicate(true) if session.overworld.get("resource_nodes", []) is Array else []
	var resources_before: Dictionary = session.overworld.get("resources", {}).duplicate(true)
	var army_before: Dictionary = session.overworld.get("army", {}).duplicate(true)
	var artifacts_before: Array = session.overworld.get("artifact_nodes", []).duplicate(true) if session.overworld.get("artifact_nodes", []) is Array else []
	var encounters_before: Array = session.overworld.get("encounters", []).duplicate(true) if session.overworld.get("encounters", []) is Array else []
	var map_objects_before: Array = session.overworld.get("map_objects", []).duplicate(true) if session.overworld.get("map_objects", []) is Array else []
	var package_ids_before: Array = session.overworld.get("package_source_object_ids", []).duplicate(true) if session.overworld.get("package_source_object_ids", []) is Array else []
	var package_sources_before: Dictionary = source_objects.duplicate(true)
	var owned_artifacts_before: Array = ArtifactRulesScript.owned_artifact_ids(session.overworld.get("hero", {}))
	var live_rows := []
	var target_indices := {}
	for node_index in range(nodes_before.size()):
		var node_value: Variant = nodes_before[node_index]
		if not (node_value is Dictionary):
			continue
		var node: Dictionary = node_value
		var source: Dictionary = source_objects.get(String(node.get("placement_id", "")), {}) if source_objects.get(String(node.get("placement_id", "")), {}) is Dictionary else {}
		if int(source.get("h3m_type_id", -1)) != 17:
			continue
		var subtype := int(source.get("h3m_subtype", -1))
		var expected: Dictionary = CREATURE_GENERATOR_ROWS.get(subtype, {}) if CREATURE_GENERATOR_ROWS.get(subtype, {}) is Dictionary else {}
		if expected.is_empty():
			return {"ok": false, "reason": "unexpected_creature_generator_subtype", "subtype": subtype}
		live_rows.append({"index": node_index, "subtype": subtype, "node": node.duplicate(true)})
		target_indices[node_index] = true
	if live_rows.map(func(row: Dictionary) -> int: return int(row.get("subtype", -1))) != expected_subtypes:
		return {"ok": false, "reason": "ordered_creature_generator_rows_mismatch", "rows": live_rows}
	var expected_recruits := {}
	var expected_gold := 0
	var claim_rows := []
	var repeat_rejected := true
	for row_value in live_rows:
		var row: Dictionary = row_value
		var subtype := int(row.get("subtype", -1))
		var expected: Dictionary = CREATURE_GENERATOR_ROWS.get(subtype, {})
		expected_gold += int(expected.get("gold", 0))
		for unit_id_value in expected.get("recruits", {}).keys():
			var unit_id := String(unit_id_value)
			expected_recruits[unit_id] = int(expected_recruits.get(unit_id, 0)) + int(expected.get("recruits", {}).get(unit_id, 0))
		var node_index := int(row.get("index", -1))
		var current_nodes: Array = session.overworld.get("resource_nodes", []) if session.overworld.get("resource_nodes", []) is Array else []
		var current_node: Dictionary = current_nodes[node_index] if node_index >= 0 and node_index < current_nodes.size() and current_nodes[node_index] is Dictionary else {}
		var claim: Dictionary = OverworldRulesScript._collect_resource_node_result(session, {"index": node_index, "node": current_node}, false)
		current_nodes = session.overworld.get("resource_nodes", []) if session.overworld.get("resource_nodes", []) is Array else []
		var claimed_node: Dictionary = current_nodes[node_index] if node_index >= 0 and node_index < current_nodes.size() and current_nodes[node_index] is Dictionary else {}
		var authority_before_repeat: Dictionary = session.to_dict()
		var repeat_claim: Dictionary = OverworldRulesScript._collect_resource_node_result(session, {"index": node_index, "node": claimed_node}, false)
		var repeat_authority_exact: bool = session.to_dict() == authority_before_repeat
		repeat_rejected = repeat_rejected and not bool(repeat_claim.get("ok", false)) and repeat_authority_exact
		claim_rows.append({
			"subtype": subtype,
			"placement_id": claimed_node.get("placement_id", ""),
			"object_id": claimed_node.get("object_id", ""),
			"site_id": claimed_node.get("site_id", ""),
			"claim_ok": claim.get("ok", false),
			"controller": claimed_node.get("collected_by_faction_id", ""),
			"persistent": claimed_node.get("collected", false),
			"repeat_rejected": not bool(repeat_claim.get("ok", false)),
			"repeat_authority_exact": repeat_authority_exact,
		})
	var resources_after: Dictionary = session.overworld.get("resources", {}).duplicate(true)
	var expected_resources: Dictionary = resources_before.duplicate(true)
	expected_resources["gold"] = int(expected_resources.get("gold", 0)) + expected_gold
	var army_after: Dictionary = session.overworld.get("army", {}).duplicate(true)
	var army_counts_before := _army_stack_counts(army_before)
	var army_counts_after := _army_stack_counts(army_after)
	var expected_army_counts: Dictionary = army_counts_before.duplicate(true)
	for unit_id_value in expected_recruits.keys():
		var unit_id := String(unit_id_value)
		expected_army_counts[unit_id] = int(expected_army_counts.get(unit_id, 0)) + int(expected_recruits.get(unit_id, 0))
	var nodes_after: Array = session.overworld.get("resource_nodes", []) if session.overworld.get("resource_nodes", []) is Array else []
	var unrelated_nodes_exact := nodes_after.size() == nodes_before.size()
	if unrelated_nodes_exact:
		for node_index in range(nodes_before.size()):
			if not target_indices.has(node_index) and nodes_before[node_index] != nodes_after[node_index]:
				unrelated_nodes_exact = false
				break
	var all_claims_exact := claim_rows.size() == expected_subtypes.size()
	for claim_value in claim_rows:
		var claim_row: Dictionary = claim_value
		var expected: Dictionary = CREATURE_GENERATOR_ROWS.get(int(claim_row.get("subtype", -1)), {})
		if not bool(claim_row.get("claim_ok", false)) \
				or String(claim_row.get("controller", "")) != "player" \
				or not bool(claim_row.get("persistent", false)) \
				or String(claim_row.get("object_id", "")) != String(expected.get("object_id", "")) \
				or String(claim_row.get("site_id", "")) != String(expected.get("site_id", "")):
			all_claims_exact = false
	var owned_artifacts_after: Array = ArtifactRulesScript.owned_artifact_ids(session.overworld.get("hero", {}))
	var serialized_authority: Dictionary = session.to_dict()
	var restored = SessionStateStoreScript.SessionData.new()
	restored.from_dict(serialized_authority)
	var save_round_trip_exact: bool = int(restored.save_version) == int(SessionStateStoreScript.SAVE_VERSION) and restored.to_dict() == serialized_authority
	return {
		"ok": all_claims_exact \
				and resources_after == expected_resources \
				and army_counts_after == expected_army_counts \
				and session.overworld.get("hero", {}).get("army", {}) == army_after \
				and owned_artifacts_after == owned_artifacts_before \
				and session.overworld.get("artifact_nodes", []) == artifacts_before \
				and session.overworld.get("encounters", []) == encounters_before \
				and session.overworld.get("map_objects", []) == map_objects_before \
				and session.overworld.get("package_source_object_ids", []) == package_ids_before \
				and session.overworld.get("package_source_objects_by_id", {}) == package_sources_before \
				and unrelated_nodes_exact \
				and repeat_rejected \
				and save_round_trip_exact,
		"claim_rows": claim_rows,
		"gold_delta": int(resources_after.get("gold", 0)) - int(resources_before.get("gold", 0)),
		"expected_gold_delta": expected_gold,
		"army_deltas": expected_recruits,
		"army_exact": army_counts_after == expected_army_counts,
		"artifacts_exact": owned_artifacts_after == owned_artifacts_before and session.overworld.get("artifact_nodes", []) == artifacts_before,
		"unrelated_nodes_exact": unrelated_nodes_exact,
		"encounters_exact": session.overworld.get("encounters", []) == encounters_before,
		"map_objects_exact": session.overworld.get("map_objects", []) == map_objects_before,
		"package_authority_exact": session.overworld.get("package_source_object_ids", []) == package_ids_before and session.overworld.get("package_source_objects_by_id", {}) == package_sources_before,
		"repeat_rejected": repeat_rejected,
		"save_version": int(restored.save_version),
		"save_round_trip_exact": save_round_trip_exact,
	}

func _army_stack_counts(army: Dictionary) -> Dictionary:
	var counts := {}
	for stack_value in army.get("stacks", []):
		if stack_value is Dictionary:
			var unit_id := String(stack_value.get("unit_id", ""))
			if unit_id != "":
				counts[unit_id] = int(counts.get(unit_id, 0)) + int(stack_value.get("count", 0))
	return counts

func _validate_loose_resource_presentation(
	session: SessionStateStoreScript.SessionData,
	live_nodes_by_site: Dictionary,
	live_mine_nodes_by_site: Dictionary
) -> Dictionary:
	var session_authority_before: Dictionary = session.to_dict()
	var expected_current_sites := []
	var actual_current_sites := []
	for row_value in LOOSE_RESOURCE_PRESENTATION_ROWS:
		var row: Dictionary = row_value
		var site_id := String(row.get("site_id", ""))
		if bool(row.get("current_small", false)):
			expected_current_sites.append(site_id)
			if live_nodes_by_site.has(site_id):
				actual_current_sites.append(site_id)
	if actual_current_sites != expected_current_sites or live_nodes_by_site.size() != expected_current_sites.size():
		return {
			"ok": false,
			"reason": "current_small_site_set_mismatch",
			"expected": expected_current_sites,
			"actual": actual_current_sites,
		}
	if live_mine_nodes_by_site.size() != LOOSE_RESOURCE_PRESENTATION_ROWS.size():
		return {"ok": false, "reason": "current_small_mine_site_set_mismatch", "actual": live_mine_nodes_by_site.keys()}
	var template_node_value: Variant = live_nodes_by_site.values()[0]
	if not (template_node_value is Dictionary) or template_node_value.is_empty():
		return {"ok": false, "reason": "missing_detached_template_node"}
	var template_node: Dictionary = template_node_value.duplicate(true)
	var map_size := OverworldRulesScript.derive_map_size(session)
	var view: Variant = OverworldMapViewScript.new()
	add_child(view)
	var site_rows := []
	var all_rows_exact := true
	for row_value in LOOSE_RESOURCE_PRESENTATION_ROWS:
		var row: Dictionary = row_value
		var site_id := String(row.get("site_id", ""))
		var node: Dictionary = live_nodes_by_site[site_id].duplicate(true) if live_nodes_by_site.has(site_id) else template_node.duplicate(true)
		node["placement_id"] = "detached_presentation_%s" % site_id
		node["object_id"] = String(row.get("object_id", ""))
		node["site_id"] = site_id
		node["resource_id"] = String(row.get("resource_id", ""))
		node["collected"] = false
		node["collected_by_faction_id"] = ""
		node.erase("collected_day")
		if not bool(row.get("current_small", false)):
			node.erase("runtime_footprint")
		var tile := Vector2i(int(node.get("x", -1)), int(node.get("y", -1)))
		if tile.x < 0 or tile.y < 0 or tile.x >= map_size.x or tile.y >= map_size.y:
			all_rows_exact = false
			site_rows.append({"site_id": site_id, "exact": false, "reason": "invalid_tile", "tile": {"x": tile.x, "y": tile.y}, "map_size": {"x": map_size.x, "y": map_size.y}, "node_keys": node.keys()})
			continue
		var texture: Texture2D = load(String(row.get("texture_path", ""))) as Texture2D
		var image: Image = texture.get_image() if texture != null else null
		var texture_exact := image != null and image.get_size() == Vector2i(512, 512) and image.detect_alpha() != Image.ALPHA_NONE
		if texture_exact:
			for corner in [Vector2i(0, 0), Vector2i(511, 0), Vector2i(0, 511), Vector2i(511, 511)]:
				if image.get_pixelv(corner).a > 0.01:
					texture_exact = false
					break
		var view_session := SessionStateStoreScript.SessionData.new()
		view_session.from_dict(session_authority_before)
		view_session.overworld["resource_nodes"] = [node]
		view_session.overworld["encounters"] = []
		view_session.overworld["fog"] = _uniform_test_fog(map_size, true, true)
		var viewport_rows := []
		var viewport_exact := true
		for viewport_size in [Vector2(1280, 720), Vector2(1920, 1080)]:
			view.size = viewport_size
			view.set_map_state(view_session, view_session.overworld.get("map", []), map_size, tile)
			await get_tree().process_frame
			var presentation: Dictionary = view.validation_tile_presentation(tile)
			var art: Dictionary = presentation.get("art_presentation", {}) if presentation.get("art_presentation", {}) is Dictionary else {}
			var marker: Dictionary = presentation.get("marker_readability", {}) if presentation.get("marker_readability", {}) is Dictionary else {}
			var asset_ids: Array = art.get("sprite_asset_ids", []) if art.get("sprite_asset_ids", []) is Array else []
			var row_exact: bool = bool(presentation.get("visible", false)) \
					and bool(presentation.get("has_resource", false)) \
					and bool(art.get("uses_asset_sprite", false)) \
					and asset_ids.count(String(row.get("asset_id", ""))) == 1 \
					and art.get("sprite_footprints", []) == [row.get("expected_footprint", {})] \
					and bool(art.get("mapped_sprite_grounding", false)) \
					and bool(marker.get("mapped_sprite_settlement", false)) \
					and not bool(art.get("fallback_procedural_marker", true))
			viewport_exact = viewport_exact and row_exact
			viewport_rows.append({
				"width": int(viewport_size.x),
				"height": int(viewport_size.y),
				"asset_ids": asset_ids,
				"footprints": art.get("sprite_footprints", []),
				"mapped_grounding": art.get("mapped_sprite_grounding", false),
				"mapped_settlement": marker.get("mapped_sprite_settlement", false),
				"fallback_procedural": art.get("fallback_procedural_marker", false),
				"visible": presentation.get("visible", false),
				"has_resource": presentation.get("has_resource", false),
				"exact": row_exact,
			})
		view_session.overworld["fog"] = _uniform_test_fog(map_size, false, true)
		view.set_map_state(view_session, view_session.overworld.get("map", []), map_size, tile)
		await get_tree().process_frame
		var permanently_explored: Dictionary = view.validation_tile_presentation(tile)
		var permanently_explored_art: Dictionary = permanently_explored.get("art_presentation", {}) if permanently_explored.get("art_presentation", {}) is Dictionary else {}
		var remembered_asset_ids: Array = permanently_explored_art.get("sprite_asset_ids", []) if permanently_explored_art.get("sprite_asset_ids", []) is Array else []
		var permanent_explored_exact: bool = bool(permanently_explored.get("explored", false)) \
				and bool(permanently_explored.get("visible", false)) \
				and not bool(permanently_explored.get("draws_remembered_object", true)) \
				and remembered_asset_ids.count(String(row.get("asset_id", ""))) == 1
		var mine_node: Dictionary = live_mine_nodes_by_site.get(site_id, {}) if live_mine_nodes_by_site.get(site_id, {}) is Dictionary else {}
		var mine_session := SessionStateStoreScript.SessionData.new()
		mine_session.from_dict(session_authority_before)
		mine_session.overworld["resource_nodes"] = [mine_node.duplicate(true)]
		mine_session.overworld["encounters"] = []
		mine_session.overworld["fog"] = _uniform_test_fog(map_size, true, true)
		var mine_tile := Vector2i(int(mine_node.get("x", -1)), int(mine_node.get("y", -1)))
		view.size = Vector2(1280, 720)
		view.set_map_state(mine_session, mine_session.overworld.get("map", []), map_size, mine_tile)
		await get_tree().process_frame
		var mine_presentation: Dictionary = view.validation_tile_presentation(mine_tile)
		var mine_art: Dictionary = mine_presentation.get("art_presentation", {}) if mine_presentation.get("art_presentation", {}) is Dictionary else {}
		var mine_asset_ids: Array = mine_art.get("sprite_asset_ids", []) if mine_art.get("sprite_asset_ids", []) is Array else []
		var mine_exact: bool = String(mine_node.get("kind", "")) == "mine" \
				and mine_asset_ids.count(String(row.get("mine_asset_id", ""))) == 1 \
				and String(row.get("asset_id", "")) not in mine_asset_ids \
				and bool(mine_art.get("uses_asset_sprite", false))
		var claim_session := SessionStateStoreScript.SessionData.new()
		claim_session.from_dict(session_authority_before)
		claim_session.overworld["resource_nodes"] = [node.duplicate(true)]
		claim_session.overworld["encounters"] = []
		var resources_before: Dictionary = claim_session.overworld.get("resources", {}).duplicate(true)
		var claim: Dictionary = OverworldRulesScript._collect_resource_node_result(claim_session, {"index": 0, "node": node.duplicate(true)}, false)
		var resources_after: Dictionary = claim_session.overworld.get("resources", {}).duplicate(true)
		var reward_exact := bool(claim.get("ok", false))
		var expected_rewards: Dictionary = row.get("rewards", {})
		for resource_key in ["gold", "wood", "ore", "aetherglass", "brass_scrip", "embergrain", "memory_salt", "peatwax", "verdant_grafts"]:
			if int(resources_after.get(resource_key, 0)) - int(resources_before.get(resource_key, 0)) != int(expected_rewards.get(resource_key, 0)):
				reward_exact = false
		var claimed_nodes: Array = claim_session.overworld.get("resource_nodes", []) if claim_session.overworld.get("resource_nodes", []) is Array else []
		var claimed_node: Dictionary = claimed_nodes[0] if claimed_nodes.size() == 1 and claimed_nodes[0] is Dictionary else {}
		var repeat_claim: Dictionary = OverworldRulesScript._collect_resource_node_result(claim_session, {"index": 0, "node": claimed_node}, false)
		var restored := SessionStateStoreScript.SessionData.new()
		restored.from_dict(claim_session.to_dict())
		var restored_nodes: Array = restored.overworld.get("resource_nodes", []) if restored.overworld.get("resource_nodes", []) is Array else []
		var save_exact: bool = restored.overworld.get("resources", {}) == resources_after \
				and restored_nodes.size() == 1 \
				and restored_nodes[0] == claimed_node
		var exact: bool = texture_exact and viewport_exact and permanent_explored_exact and mine_exact and reward_exact \
				and bool(claimed_node.get("collected", false)) \
				and not bool(repeat_claim.get("ok", false)) \
				and save_exact
		all_rows_exact = all_rows_exact and exact
		site_rows.append({
			"site_id": site_id,
			"resource_id": row.get("resource_id", ""),
			"asset_id": row.get("asset_id", ""),
			"current_small": row.get("current_small", false),
			"texture_exact": texture_exact,
			"viewport_rows": viewport_rows,
			"permanent_explored_exact": permanent_explored_exact,
			"mine_asset_ids": mine_asset_ids,
			"mine_exact": mine_exact,
			"reward_exact": reward_exact,
			"repeat_rejected": not bool(repeat_claim.get("ok", false)),
			"save_exact": save_exact,
			"exact": exact,
		})
	var fallback_session := SessionStateStoreScript.SessionData.new()
	fallback_session.from_dict(session_authority_before)
	var fallback_node: Dictionary = template_node.duplicate(true)
	fallback_node["object_id"] = "missing_loose_resource_object"
	fallback_node["site_id"] = "missing_loose_resource_site"
	fallback_session.overworld["resource_nodes"] = [fallback_node]
	fallback_session.overworld["encounters"] = []
	fallback_session.overworld["fog"] = _uniform_test_fog(map_size, true, true)
	var fallback_tile := Vector2i(int(fallback_node.get("x", -1)), int(fallback_node.get("y", -1)))
	view.size = Vector2(1280, 720)
	view.set_map_state(fallback_session, fallback_session.overworld.get("map", []), map_size, fallback_tile)
	await get_tree().process_frame
	var fallback: Dictionary = view.validation_tile_presentation(fallback_tile)
	var fallback_art: Dictionary = fallback.get("art_presentation", {}) if fallback.get("art_presentation", {}) is Dictionary else {}
	remove_child(view)
	view.queue_free()
	var fallback_exact: bool = bool(fallback.get("has_resource", false)) \
			and not bool(fallback_art.get("uses_asset_sprite", true)) \
			and bool(fallback_art.get("fallback_procedural_marker", false))
	return {
		"ok": all_rows_exact \
				and fallback_exact \
				and session.to_dict() == session_authority_before,
		"current_small_sites": actual_current_sites,
		"site_rows": site_rows,
		"fallback_procedural": fallback_exact,
		"session_authority_exact": session.to_dict() == session_authority_before,
	}

func _validate_spell_scroll_presentation(session: SessionStateStoreScript.SessionData, scroll_node: Dictionary) -> Dictionary:
	var map_size := OverworldRulesScript.derive_map_size(session)
	var tile := Vector2i(int(scroll_node.get("x", -1)), int(scroll_node.get("y", -1)))
	if map_size.x <= 0 or map_size.y <= 0 or tile.x < 0 or tile.y < 0:
		return {"ok": false, "reason": "invalid_map_or_scroll_tile"}
	var texture: Texture2D = load("res://art/overworld/runtime/objects/pickups/beacon_path_scroll.png") as Texture2D
	if texture == null:
		return {"ok": false, "reason": "missing_beacon_path_scroll_texture"}
	var image: Image = texture.get_image()
	var transparent_corners := image != null and image.get_size() == Vector2i(512, 512) and image.detect_alpha() != Image.ALPHA_NONE
	if transparent_corners:
		for corner in [Vector2i(0, 0), Vector2i(511, 0), Vector2i(0, 511), Vector2i(511, 511)]:
			if image.get_pixelv(corner).a > 0.01:
				transparent_corners = false
				break
	var view_session := SessionStateStoreScript.SessionData.new()
	view_session.from_dict(session.to_dict())
	view_session.overworld["fog"] = _uniform_test_fog(map_size, true, true)
	var view: Variant = OverworldMapViewScript.new()
	add_child(view)
	var viewport_rows := []
	var viewport_assets_exact := true
	var visible := {}
	for viewport_size in [Vector2(1280, 720), Vector2(1920, 1080)]:
		view.size = viewport_size
		view.set_map_state(view_session, view_session.overworld.get("map", []), map_size, tile)
		await get_tree().process_frame
		visible = view.validation_tile_presentation(tile)
		var viewport_art: Dictionary = visible.get("art_presentation", {}) if visible.get("art_presentation", {}) is Dictionary else {}
		var marker: Dictionary = visible.get("marker_readability", {}) if visible.get("marker_readability", {}) is Dictionary else {}
		var row_exact: bool = bool(visible.get("visible", false)) \
				and bool(visible.get("has_resource", false)) \
				and bool(viewport_art.get("uses_asset_sprite", false)) \
				and "beacon_path_scroll" in viewport_art.get("sprite_asset_ids", []) \
				and viewport_art.get("sprite_footprints", []) == [{"width": 1, "height": 1}] \
				and bool(viewport_art.get("mapped_sprite_grounding", false)) \
				and bool(marker.get("mapped_sprite_settlement", false)) \
				and not bool(viewport_art.get("fallback_procedural_marker", true))
		viewport_assets_exact = viewport_assets_exact and row_exact
		viewport_rows.append({
			"width": int(viewport_size.x),
			"height": int(viewport_size.y),
			"asset_ids": viewport_art.get("sprite_asset_ids", []),
			"footprints": viewport_art.get("sprite_footprints", []),
			"mapped_grounding": viewport_art.get("mapped_sprite_grounding", false),
			"exact": row_exact,
		})
	view_session.overworld["fog"] = _uniform_test_fog(map_size, false, true)
	view.set_map_state(view_session, view_session.overworld.get("map", []), map_size, tile)
	await get_tree().process_frame
	var permanently_explored: Dictionary = view.validation_tile_presentation(tile)
	var fallback_nodes: Array = view_session.overworld.get("resource_nodes", []).duplicate(true) if view_session.overworld.get("resource_nodes", []) is Array else []
	for node_index in range(fallback_nodes.size()):
		if fallback_nodes[node_index] is Dictionary and String(fallback_nodes[node_index].get("placement_id", "")) == String(scroll_node.get("placement_id", "")):
			var fallback_node: Dictionary = fallback_nodes[node_index].duplicate(true)
			fallback_node["object_id"] = "missing_spell_scroll_object"
			fallback_node["site_id"] = "missing_spell_scroll_site"
			fallback_nodes[node_index] = fallback_node
			break
	view_session.overworld["resource_nodes"] = fallback_nodes
	view_session.overworld["fog"] = _uniform_test_fog(map_size, true, true)
	view.set_map_state(view_session, view_session.overworld.get("map", []), map_size, tile)
	await get_tree().process_frame
	var fallback: Dictionary = view.validation_tile_presentation(tile)
	remove_child(view)
	view.queue_free()
	var visible_art: Dictionary = visible.get("art_presentation", {}) if visible.get("art_presentation", {}) is Dictionary else {}
	var permanently_explored_art: Dictionary = permanently_explored.get("art_presentation", {}) if permanently_explored.get("art_presentation", {}) is Dictionary else {}
	var fallback_art: Dictionary = fallback.get("art_presentation", {}) if fallback.get("art_presentation", {}) is Dictionary else {}
	return {
		"ok": transparent_corners \
				and viewport_assets_exact \
				and bool(visible.get("visible", false)) \
				and bool(visible.get("has_resource", false)) \
				and bool(visible_art.get("uses_asset_sprite", false)) \
				and "beacon_path_scroll" in visible_art.get("sprite_asset_ids", []) \
				and not bool(visible_art.get("fallback_procedural_marker", true)) \
				and bool(permanently_explored.get("explored", false)) \
				and bool(permanently_explored.get("visible", false)) \
				and not bool(permanently_explored.get("draws_remembered_object", true)) \
				and "beacon_path_scroll" in permanently_explored_art.get("sprite_asset_ids", []) \
				and bool(fallback.get("has_resource", false)) \
				and not bool(fallback_art.get("uses_asset_sprite", true)) \
				and bool(fallback_art.get("fallback_procedural_marker", false)),
		"tile": {"x": tile.x, "y": tile.y},
		"texture_size": {"width": image.get_width(), "height": image.get_height()},
		"transparent_corners": transparent_corners,
		"viewport_rows": viewport_rows,
		"visible_asset_ids": visible_art.get("sprite_asset_ids", []),
		"permanently_explored_asset_ids": permanently_explored_art.get("sprite_asset_ids", []),
		"permanent_explored_visibility": permanently_explored.get("visible", false),
		"fallback_procedural": fallback_art.get("fallback_procedural_marker", false),
	}

func _uniform_test_fog(map_size: Vector2i, visible_value: bool, explored_value: bool) -> Dictionary:
	var visible_tiles := []
	var explored_tiles := []
	for _y in range(map_size.y):
		var visible_row := []
		var explored_row := []
		for _x in range(map_size.x):
			visible_row.append(visible_value)
			explored_row.append(explored_value)
		visible_tiles.append(visible_row)
		explored_tiles.append(explored_row)
	return {
		"visible_tiles": visible_tiles,
		"explored_tiles": explored_tiles,
		"visible_count": map_size.x * map_size.y if visible_value else 0,
		"explored_count": map_size.x * map_size.y if explored_value else 0,
		"total_tiles": map_size.x * map_size.y,
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
