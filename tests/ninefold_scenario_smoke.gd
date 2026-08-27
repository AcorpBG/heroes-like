extends Node

const SCENARIO_ID := "ninefold-confluence"
const TERRAIN_DETAIL_ATLAS_PATH := "res://art/overworld/runtime/terrain_tiles/detail/terrain_detail_decal_atlas_rich_v2.png"
const TERRAIN_DETAIL_ATLAS_SIZE := Vector2i(1024, 1024)
const TERRAIN_DETAIL_CELL_SIZE := 256
const TERRAIN_DETAIL_CELL_INSET := 16
const TERRAIN_DETAIL_MIN_VISIBLE_PIXELS_PER_CELL := 25000
const BattleAutoplayBalanceHarnessRulesScript = preload("res://scripts/core/BattleAutoplayBalanceHarnessRules.gd")
const PRISM_MATRIX_PLACEMENT_ID := "ninefold_prism_matrix"
const PRISM_MATRIX_PRODUCTION_STACKS := [
	{"unit_id": "unit_sunvault_shard_wardens", "count": 6},
	{"unit_id": "unit_sunvault_prism_adepts", "count": 2},
	{"unit_id": "unit_sunvault_mirror_duelists", "count": 2},
]
const PRISM_MATRIX_LEGACY_STACKS := [
	{"unit_id": "unit_shard_guard", "count": 6},
	{"unit_id": "unit_prism_adept", "count": 2},
	{"unit_id": "unit_mirror_duelist", "count": 2},
]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not _assert_rich_terrain_detail_atlas():
		return
	var scenario := ContentService.get_scenario(SCENARIO_ID)
	if scenario.is_empty():
		_fail("Ninefold smoke: scenario was not loaded by ContentService.")
		return
	if not _assert_prism_matrix_production_line(scenario):
		return

	var session = ScenarioFactory.create_session(
		SCENARIO_ID,
		"hard",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	session = SessionState.set_active_session(session)

	var map_size := OverworldRules.derive_map_size(session)
	if map_size != Vector2i(64, 64):
		_fail("Ninefold smoke: derived map size was %s, expected 64x64." % map_size)
		return
	if session.overworld.get("resource_nodes", []).size() < 47:
		_fail("Ninefold smoke: breadth resource-node placements did not seed into session state.")
		return
	if session.overworld.get("towns", []).size() < 6:
		_fail("Ninefold smoke: six-faction town placements did not seed into session state.")
		return
	if session.overworld.get("enemy_states", []).size() < 5:
		_fail("Ninefold smoke: hostile faction pressure states did not seed into session state.")
		return

	var basalt_profile := OverworldRules.terrain_profile_at(session, 60, 36)
	if String(basalt_profile.get("id", "")) != "biome_subterranean_underways":
		_fail("Ninefold smoke: Basalt Gatehouse did not land in the underway biome band.")
		return

	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame

	if not shell.has_method("validation_snapshot"):
		_fail("Ninefold smoke: OverworldShell did not expose validation_snapshot.")
		return
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var snapshot_size: Dictionary = snapshot.get("map_size", {})
	if int(snapshot_size.get("x", 0)) != 64 or int(snapshot_size.get("y", 0)) != 64:
		_fail("Ninefold smoke: OverworldShell snapshot did not retain the 64x64 map size.")
		return
	if String(snapshot.get("scenario_id", "")) != SCENARIO_ID:
		_fail("Ninefold smoke: OverworldShell snapshot is not bound to Ninefold Confluence.")
		return
	var viewport_metrics: Dictionary = snapshot.get("map_viewport", {})
	if viewport_metrics.is_empty():
		_fail("Ninefold smoke: OverworldShell snapshot did not expose map viewport metrics.")
		return
	if bool(viewport_metrics.get("full_map_visible", true)):
		_fail("Ninefold smoke: 64x64 overworld map is still fully visible instead of using tactical framing.")
		return
	if bool(viewport_metrics.get("fit_entire_map", true)):
		_fail("Ninefold smoke: 64x64 overworld map was treated as a fit-entire-map case.")
		return
	if bool(viewport_metrics.get("visible_tile_span_override_active", false)):
		_fail("Ninefold smoke: gameplay overworld unexpectedly used the editor zoom-out override: %s." % viewport_metrics)
		return
	if not is_equal_approx(float(viewport_metrics.get("active_visible_tile_span", 0.0)), 16.0):
		_fail("Ninefold smoke: gameplay tactical visible span changed from the normal overworld default: %s." % viewport_metrics)
		return
	var visible_columns := float(viewport_metrics.get("visible_tile_columns", 0.0))
	var visible_rows := float(viewport_metrics.get("visible_tile_rows", 0.0))
	var visible_area := float(viewport_metrics.get("visible_tile_area", 0.0))
	if visible_columns <= 0.0 or visible_rows <= 0.0 or visible_area <= 0.0:
		_fail("Ninefold smoke: tactical viewport metrics were empty: %s." % viewport_metrics)
		return
	if visible_columns >= 32.0 or visible_rows >= 32.0 or visible_area > 360.0:
		_fail("Ninefold smoke: tactical viewport still shows too much of the 64x64 map: %s." % viewport_metrics)
		return
	var focus_tile: Dictionary = viewport_metrics.get("camera_focus_tile", {})
	if int(focus_tile.get("x", -1)) != 23 or int(focus_tile.get("y", -1)) != 26:
		_fail("Ninefold smoke: tactical viewport is not centered on Mira's starting hero tile: %s." % viewport_metrics)
		return
	if not _assert_large_map_marker_readability(shell):
		return
	if not shell.has_method("validation_pan_map") or not shell.has_method("validation_focus_map_on_hero"):
		_fail("Ninefold smoke: OverworldShell did not expose large-map pan validation hooks.")
		return
	var pan_result: Dictionary = shell.call("validation_pan_map", 6, 0)
	if not bool(pan_result.get("ok", false)):
		_fail("Ninefold smoke: 64x64 overworld map did not pan when requested: %s." % pan_result)
		return
	var panned_metrics: Dictionary = pan_result.get("after", {})
	var panned_focus: Dictionary = panned_metrics.get("camera_focus_tile", {})
	if not bool(panned_metrics.get("manual_camera", false)) or int(panned_focus.get("x", 0)) <= int(focus_tile.get("x", 0)):
		_fail("Ninefold smoke: map pan did not move the manual camera east: %s." % pan_result)
		return
	var panned_bounds: Dictionary = panned_metrics.get("visible_bounds", {})
	var original_bounds: Dictionary = viewport_metrics.get("visible_bounds", {})
	if int(panned_bounds.get("x", 0)) <= int(original_bounds.get("x", 0)):
		_fail("Ninefold smoke: visible tile bounds did not scroll east after panning: %s." % pan_result)
		return
	var focus_result: Dictionary = shell.call("validation_focus_map_on_hero")
	var refocused_metrics: Dictionary = focus_result.get("after", {})
	if bool(refocused_metrics.get("manual_camera", true)):
		_fail("Ninefold smoke: Home/focus validation did not return camera control to the active hero: %s." % focus_result)
		return

	var progress_result: Dictionary = shell.call("validation_try_progress_action")
	if not bool(progress_result.get("ok", false)):
		_fail("Ninefold smoke: OverworldShell could not advance one safe step on the 64x64 scenario.")
		return
	if not _assert_homm_road_topology(shell, session):
		return
	if not _assert_neighbor_terrain_transitions(shell, session):
		return

	get_tree().quit(0)

func _assert_rich_terrain_detail_atlas() -> bool:
	var texture := load(TERRAIN_DETAIL_ATLAS_PATH) as Texture2D
	if texture == null:
		_fail("Ninefold smoke: rich terrain-detail atlas did not load.")
		return false
	var image := texture.get_image()
	if image == null or image.is_empty() or image.get_size() != TERRAIN_DETAIL_ATLAS_SIZE:
		_fail("Ninefold smoke: rich terrain-detail atlas did not retain exact 1024x1024 image authority.")
		return false
	for cell_id in range(16):
		var cell_origin := Vector2i(cell_id % 4, floori(float(cell_id) / 4.0)) * TERRAIN_DETAIL_CELL_SIZE
		var visible_pixel_count := 0
		var border_alpha_max := 0.0
		for local_y in range(TERRAIN_DETAIL_CELL_SIZE):
			for local_x in range(TERRAIN_DETAIL_CELL_SIZE):
				var alpha := image.get_pixelv(cell_origin + Vector2i(local_x, local_y)).a
				if alpha >= 0.06:
					visible_pixel_count += 1
				if local_x < TERRAIN_DETAIL_CELL_INSET or local_x >= TERRAIN_DETAIL_CELL_SIZE - TERRAIN_DETAIL_CELL_INSET or local_y < TERRAIN_DETAIL_CELL_INSET or local_y >= TERRAIN_DETAIL_CELL_SIZE - TERRAIN_DETAIL_CELL_INSET:
					border_alpha_max = maxf(border_alpha_max, alpha)
		if visible_pixel_count < TERRAIN_DETAIL_MIN_VISIBLE_PIXELS_PER_CELL or border_alpha_max > 0.01:
			_fail("Ninefold smoke: rich terrain-detail atlas cell %d is clipped, empty, or bleeding. visible=%d border_alpha=%s" % [cell_id, visible_pixel_count, border_alpha_max])
			return false
	return true

func _assert_prism_matrix_production_line(scenario: Dictionary) -> bool:
	var encounter: Dictionary = {}
	for encounter_value in scenario.get("encounters", []):
		if encounter_value is Dictionary and String(encounter_value.get("placement_id", "")) == PRISM_MATRIX_PLACEMENT_ID:
			encounter = encounter_value.duplicate(true)
			break
	if encounter.is_empty():
		_fail("Ninefold smoke: Prism Matrix encounter is missing.")
		return false
	var enemy_army: Dictionary = encounter.get("enemy_army", {}) if encounter.get("enemy_army", {}) is Dictionary else {}
	if (
		String(encounter.get("encounter_id", "")) != "encounter_daybreak_matrix"
		or String(encounter.get("difficulty", "")) != "high"
		or int(encounter.get("combat_seed", 0)) != 16402
		or Vector2i(int(encounter.get("x", -1)), int(encounter.get("y", -1))) != Vector2i(23, 38)
		or String(enemy_army.get("id", "")) != "army_ninefold_prism_matrix_watch"
		or String(enemy_army.get("faction_id", "")) != "faction_sunvault"
		or _army_stack_contract(enemy_army.get("stacks", [])) != PRISM_MATRIX_PRODUCTION_STACKS
	):
		_fail("Ninefold smoke: Prism Matrix production encounter identity or exact 6/2/2 line drifted: %s" % JSON.stringify(encounter))
		return false
	var payload_session = ScenarioFactory.create_session(SCENARIO_ID, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(payload_session)
	var payload_authority_before: Dictionary = payload_session.to_dict()
	var battle_payload: Dictionary = BattleRules.create_battle_payload(payload_session, encounter)
	if payload_session.to_dict() != payload_authority_before:
		_fail("Ninefold smoke: Prism Matrix public battle payload mutated its source session.")
		return false
	var expected_abilities := {
		"unit_sunvault_shard_wardens": ["shielding"],
		"unit_sunvault_prism_adepts": ["volley"],
		"unit_sunvault_mirror_duelists": ["backstab", "reach"],
	}
	var actual_stacks: Array = _battle_enemy_stack_contract(battle_payload)
	var actual_abilities: Dictionary = _battle_enemy_ability_contract(battle_payload)
	if actual_stacks != _army_stack_contract(PRISM_MATRIX_PRODUCTION_STACKS):
		_fail("Ninefold smoke: Prism Matrix public battle payload missed exact production counts: actual=%s expected=%s" % [JSON.stringify(actual_stacks), JSON.stringify(_army_stack_contract(PRISM_MATRIX_PRODUCTION_STACKS))])
		return false
	if actual_abilities != expected_abilities:
		_fail("Ninefold smoke: Prism Matrix public battle payload missed exact production ability identities: actual=%s expected=%s" % [JSON.stringify(actual_abilities), JSON.stringify(expected_abilities)])
		return false
	if _army_stack_health(PRISM_MATRIX_PRODUCTION_STACKS) != 96 or _army_stack_health(PRISM_MATRIX_LEGACY_STACKS) != 92:
		_fail("Ninefold smoke: Prism Matrix production/legacy stack-health contract drifted.")
		return false
	var production_sample: Dictionary = BattleAutoplayBalanceHarnessRulesScript.run_battle_sample(SCENARIO_ID, encounter, 72, "normal")
	if (
		not bool(production_sample.get("completed", false))
		or String(production_sample.get("outcome_state", "")) != "victory"
		or int(production_sample.get("round_reached", 0)) != 4
		or int(production_sample.get("invalid_order_count", -1)) != 0
		or int(production_sample.get("player_health_remaining_pct", -1)) != 36
		or int(production_sample.get("enemy_health_remaining_pct", -1)) != 0
		or production_sample.get("initial_stack_profile", {}).get("side_ability_counts", {}).get("enemy", {}) != {"backstab": 1, "reach": 1, "shielding": 1, "volley": 1}
	):
		_fail("Ninefold smoke: production Prism Matrix left its exact four-round player-advantaged control: %s" % JSON.stringify(production_sample))
		return false
	var production_consequences: Dictionary = production_sample.get("runtime_consequence_profile", {})
	if not bool(production_consequences.get("has_ability_consequence", false)) or not bool(production_consequences.get("has_spell_consequence", false)) or not bool(production_consequences.get("has_status_consequence", false)):
		_fail("Ninefold smoke: production Prism Matrix did not expose its live battle consequences.")
		return false
	var legacy_encounter: Dictionary = encounter.duplicate(true)
	legacy_encounter["placement_id"] = "%s:legacy_control" % PRISM_MATRIX_PLACEMENT_ID
	var legacy_army: Dictionary = enemy_army.duplicate(true)
	legacy_army["id"] = "army_ninefold_prism_matrix_legacy_control"
	legacy_army["stacks"] = PRISM_MATRIX_LEGACY_STACKS.duplicate(true)
	legacy_encounter["enemy_army"] = legacy_army
	var legacy_sample: Dictionary = BattleAutoplayBalanceHarnessRulesScript.run_battle_sample(SCENARIO_ID, legacy_encounter, 72, "normal")
	if (
		not bool(legacy_sample.get("completed", false))
		or String(legacy_sample.get("outcome_state", "")) != "victory"
		or int(legacy_sample.get("round_reached", 0)) != 4
		or int(legacy_sample.get("invalid_order_count", -1)) != 0
		or int(legacy_sample.get("player_health_remaining_pct", -1)) != 46
		or int(legacy_sample.get("enemy_health_remaining_pct", -1)) != 0
	):
		_fail("Ninefold smoke: legacy Prism Matrix method control drifted: %s" % JSON.stringify(legacy_sample))
		return false
	if abs(int(production_sample.get("player_health_remaining_pct", 0)) - int(legacy_sample.get("player_health_remaining_pct", 0))) > 10:
		_fail("Ninefold smoke: production Prism Matrix left the bounded legacy terminal margin.")
		return false
	return true

func _army_stack_contract(stacks: Array) -> Array:
	var result: Array = []
	for stack_value in stacks:
		if stack_value is Dictionary:
			result.append({"unit_id": String(stack_value.get("unit_id", "")), "count": int(stack_value.get("count", 0))})
	return result

func _army_stack_health(stacks: Array) -> int:
	var total := 0
	for stack_value in stacks:
		if stack_value is Dictionary:
			var unit: Dictionary = ContentService.get_unit(String(stack_value.get("unit_id", "")))
			total += int(stack_value.get("count", 0)) * int(unit.get("hp", 0))
	return total

func _battle_enemy_stack_contract(battle: Dictionary) -> Array:
	var result: Array = []
	for stack_value in battle.get("stacks", []):
		if stack_value is Dictionary and String(stack_value.get("side", "")) == "enemy":
			result.append({"unit_id": String(stack_value.get("unit_id", "")), "count": int(stack_value.get("base_count", 0))})
	return result

func _battle_enemy_ability_contract(battle: Dictionary) -> Dictionary:
	var result := {}
	for stack_value in battle.get("stacks", []):
		if not (stack_value is Dictionary) or String(stack_value.get("side", "")) != "enemy":
			continue
		var ability_ids: Array = []
		for ability_value in stack_value.get("abilities", []):
			if ability_value is Dictionary:
				ability_ids.append(String(ability_value.get("id", "")))
		ability_ids.sort()
		result[String(stack_value.get("unit_id", ""))] = ability_ids
	return result

func _assert_neighbor_terrain_transitions(shell: Node, session) -> bool:
	var receiver_tile := Vector2i(27, 23)
	var source_tile := Vector2i(28, 23)
	_reveal_validation_tiles(session, [receiver_tile, source_tile])
	if not _assert_terrain_macro_lighting(shell, session, receiver_tile):
		return false
	shell.call("validation_select_tile", receiver_tile.x, receiver_tile.y)
	var presentation: Dictionary = shell.call("validation_tile_presentation", receiver_tile.x, receiver_tile.y)
	var terrain: Dictionary = presentation.get("terrain_presentation", {})
	if (
		String(terrain.get("terrain", "")) != "grass"
		or String(terrain.get("terrain_group", "")) != "grasslands"
		or not bool(terrain.get("neighbor_aware_transitions", false))
		or String(terrain.get("transition_calculation_model", "")) != "accepted_web_prototype_relation_class_row_lookup"
		or String(terrain.get("transition_edge_model", "")) != "bridge_or_shoreline_atlas_frame_lookup"
		or String(terrain.get("transition_edge_mask", "")) != "E"
		or "dirt" not in terrain.get("transition_source_terrain_ids", [])
		or "dirt" not in terrain.get("transition_source_groups", [])
		or int(terrain.get("edge_transition_count", 0)) != 1
		or String(terrain.get("homm3_selection_kind", "")) != "bridge_transition"
		or String(terrain.get("homm3_bridge_family", "")) != "dirt"
		or String(terrain.get("transition_shape_model", "")) != "layered_feathered_organic_intrusion"
		or String(terrain.get("transition_edge_treatment", "")) != "shallow_irregular_feather_bands"
		or String(terrain.get("transition_draw_policy", "")) != "active_homm3_self_contained_else_generic_overlay"
		or bool(terrain.get("homm3_transition_self_contained", true))
		or not bool(terrain.get("generic_transition_overlay_active", false))
		or String(terrain.get("generic_transition_surface_model", "")) != "layered_feathered_organic_intrusion"
		or int(terrain.get("generic_transition_feather_band_count", 0)) != 2
		or not bool(terrain.get("generic_transition_irregular_inner_edge", false))
		or String(terrain.get("generic_transition_deterministic_seed_basis", "")) != "tile_and_direction_only"
	):
		_fail("Ninefold smoke: canonical grass/dirt boundary did not render the original-bank generic transition overlay with inactive HoMM3 relation metadata: %s." % presentation)
		return false
	if not _assert_full_receiver_stamp_payload(terrain, {
		"table": "full_receiver_native_to_dirt_5x4_provisional_stamp_table",
		"direction": "E",
		"frame": "00_06",
		"offset": {"x": 1, "y": 0},
		"bridge_family": "dirt",
		"target_block": "native_to_dirt_transition",
		"source_kind": "cardinal_source",
		"shape_class": 3,
		"row_group": "4-7",
		"flip": "H",
		"flip_h": true,
	}):
		_fail("Ninefold smoke: canonical east-side grass/dirt boundary did not expose accepted relation-class metadata: %s." % presentation)
		return false
	var sources: Array = terrain.get("transition_cardinal_sources", [])
	var found_east_dirt := false
	for source_value in sources:
		var source: Dictionary = source_value
		if String(source.get("source_terrain", "")) == "dirt" and String(source.get("direction", "")) == "E" and String(source.get("relation_kind", "")) == "bridge_base_resolution":
			found_east_dirt = true
			break
	if not found_east_dirt:
		_fail("Ninefold smoke: terrain transition did not expose its neighboring source terrain and direction: %s." % presentation)
		return false
	if not _assert_enabled_homm3_transition_ownership(shell, session, receiver_tile):
		return false
	var shoreline_tile := Vector2i(49, 0)
	var shoreline_source := Vector2i(48, 0)
	_reveal_validation_tiles(session, [shoreline_tile, shoreline_source])
	var shoreline_presentation: Dictionary = shell.call("validation_tile_presentation", shoreline_tile.x, shoreline_tile.y)
	var shoreline: Dictionary = shoreline_presentation.get("terrain_presentation", {})
	if String(shoreline.get("homm3_selection_kind", "")) != "water_shoreline" or not bool(shoreline.get("homm3_shoreline_specific", false)) or String(shoreline.get("homm3_terrain_atlas", "")) != "watrtl":
		_fail("Ninefold smoke: water/coast terrain did not use shoreline-specific HoMM3 lookup beside land: %s." % shoreline_presentation)
		return false
	var shoreline_detail: Dictionary = shoreline.get("terrain_detail_decal", {}) if shoreline.get("terrain_detail_decal", {}) is Dictionary else {}
	if (
		String(shoreline_detail.get("model", "")) != "rich_biome_aware_painterly_surface_clusters_v2"
		or String(shoreline_detail.get("terrain_group", "")) != "water"
		or bool(shoreline_detail.get("drawn", true))
		or not bool(shoreline_detail.get("water_excluded", false))
		or int(shoreline_detail.get("cell_id", -2)) != -1
	):
		_fail("Ninefold smoke: water shoreline received a land surface-detail decal: %s." % JSON.stringify(shoreline_detail))
		return false
	var sparse_water_ripple: Dictionary = shoreline.get("water_surface_ripples", {}) if shoreline.get("water_surface_ripples", {}) is Dictionary else {}
	if not _water_surface_ripple_payload_exact(sparse_water_ripple, false, false):
		_fail("Ninefold smoke: sparse water control did not retain exact non-drawn current ownership: %s." % JSON.stringify(sparse_water_ripple))
		return false
	var active_water_tile := Vector2i(50, 0)
	_reveal_validation_tiles(session, [active_water_tile])
	var active_water_presentation: Dictionary = shell.call("validation_tile_presentation", active_water_tile.x, active_water_tile.y)
	var active_water_terrain: Dictionary = active_water_presentation.get("terrain_presentation", {}) if active_water_presentation.get("terrain_presentation", {}) is Dictionary else {}
	var active_water_ripple: Dictionary = active_water_terrain.get("water_surface_ripples", {}) if active_water_terrain.get("water_surface_ripples", {}) is Dictionary else {}
	if String(active_water_terrain.get("terrain", "")) != "water" or not _water_surface_ripple_payload_exact(active_water_ripple, true, false):
		_fail("Ninefold smoke: authored loaded water did not expose exact broken current ripples: %s." % JSON.stringify(active_water_presentation))
		return false
	var repeated_water_presentation: Dictionary = shell.call("validation_tile_presentation", active_water_tile.x, active_water_tile.y)
	var repeated_water_terrain: Dictionary = repeated_water_presentation.get("terrain_presentation", {}) if repeated_water_presentation.get("terrain_presentation", {}) is Dictionary else {}
	if repeated_water_terrain.get("water_surface_ripples", {}) != active_water_ripple:
		_fail("Ninefold smoke: authored water current ripples changed across repeated observation.")
		return false
	if not _assert_direct_dirt_sand_transition(shell, session):
		return false
	return true

func _assert_terrain_macro_lighting(shell: Node, session, north_west_tile: Vector2i) -> bool:
	var east_tile := north_west_tile + Vector2i.RIGHT
	var south_tile := north_west_tile + Vector2i.DOWN
	var south_east_tile := north_west_tile + Vector2i(1, 1)
	var revealed_tiles: Array = []
	for y_offset in range(3):
		for x_offset in range(3):
			revealed_tiles.append(north_west_tile + Vector2i(x_offset, y_offset))
	_reveal_validation_tiles(session, revealed_tiles)
	var session_authority_before: Dictionary = session.to_dict()
	var north_west_presentation: Dictionary = shell.call("validation_tile_presentation", north_west_tile.x, north_west_tile.y)
	var repeated_presentation: Dictionary = shell.call("validation_tile_presentation", north_west_tile.x, north_west_tile.y)
	var east_presentation: Dictionary = shell.call("validation_tile_presentation", east_tile.x, east_tile.y)
	var south_presentation: Dictionary = shell.call("validation_tile_presentation", south_tile.x, south_tile.y)
	var south_east_presentation: Dictionary = shell.call("validation_tile_presentation", south_east_tile.x, south_east_tile.y)
	var presentations := [north_west_presentation, east_presentation, south_presentation, south_east_presentation]
	var lighting_rows: Array = []
	var grain_rows: Array = []
	var detail_rows: Array = []
	var drawn_detail_count := 0
	for presentation_value in presentations:
		var presentation: Dictionary = presentation_value
		var terrain: Dictionary = presentation.get("terrain_presentation", {}) if presentation.get("terrain_presentation", {}) is Dictionary else {}
		var lighting: Dictionary = terrain.get("terrain_macro_lighting", {}) if terrain.get("terrain_macro_lighting", {}) is Dictionary else {}
		var grain: Dictionary = terrain.get("terrain_grain_overlay", {}) if terrain.get("terrain_grain_overlay", {}) is Dictionary else {}
		var detail: Dictionary = terrain.get("terrain_detail_decal", {}) if terrain.get("terrain_detail_decal", {}) is Dictionary else {}
		var samples: Array = lighting.get("corner_samples", []) if lighting.get("corner_samples", []) is Array else []
		if (
			String(lighting.get("model", "")) != "continuous_shared_corner_bilinear_field"
			or int(lighting.get("cell_tiles", 0)) != 12
			or not is_equal_approx(float(lighting.get("shadow_max_alpha", 0.0)), 0.075)
			or not is_equal_approx(float(lighting.get("highlight_max_alpha", 0.0)), 0.040)
			or lighting.get("corner_order", []) != ["NW", "NE", "SE", "SW"]
			or samples.size() != 4
			or not bool(lighting.get("continuous_shared_corners", false))
			or String(lighting.get("draw_order", "")) != "after_terrain_transitions_before_roads"
			or not bool(lighting.get("hidden_by_unexplored_shroud", false))
			or not bool(lighting.get("drawn", false))
		):
			_fail("Ninefold smoke: explored terrain macro-lighting contract is incomplete: %s." % JSON.stringify(lighting))
			return false
		for sample_value in samples:
			if float(sample_value) < 0.0 or float(sample_value) > 1.0:
				_fail("Ninefold smoke: terrain macro-lighting sample escaped its bounded field: %s." % JSON.stringify(lighting))
				return false
		lighting_rows.append(lighting)
		if (
			String(grain.get("model", "")) != "single_normalized_map_space_seamless_painterly_microtexture"
			or String(grain.get("source_model", "")) != "original_generated_neutral_grain_mirrored_seamless_alpha"
			or not bool(grain.get("drawn", false))
			or not bool(grain.get("texture_loaded", false))
			or String(grain.get("texture_path", "")) != "res://art/overworld/runtime/terrain_tiles/detail/terrain_grain_overlay.png"
			or grain.get("texture_size", {}) != {"x": 1024, "y": 1024}
			or not is_equal_approx(float(grain.get("modulate_alpha", 0.0)), 0.72)
			or String(grain.get("mapping", "")) != "whole_board_normalized_once"
			or bool(grain.get("repeated_per_tile", true))
			or not bool(grain.get("seamless_outer_edges", false))
			or bool(grain.get("terrain_identity_sampled", true))
			or String(grain.get("draw_order", "")) != "after_terrain_transitions_before_macro_lighting_and_roads"
			or not bool(grain.get("hidden_by_unexplored_shroud", false))
		):
			_fail("Ninefold smoke: explored terrain grain contract is incomplete: %s." % JSON.stringify(grain))
			return false
		grain_rows.append(grain)
		var terrain_group := String(terrain.get("terrain_group", ""))
		if not _terrain_detail_decal_payload_exact(detail, terrain_group):
			_fail("Ninefold smoke: explored terrain detail decal contract is incomplete: %s." % JSON.stringify(detail))
			return false
		if bool(detail.get("drawn", false)):
			drawn_detail_count += 1
		detail_rows.append(detail)
	if drawn_detail_count <= 0:
		_fail("Ninefold smoke: live 2x2 grass fixture did not draw any sparse biome surface detail: %s." % JSON.stringify(detail_rows))
		return false
	var north_west_lighting: Dictionary = lighting_rows[0]
	var repeated_terrain: Dictionary = repeated_presentation.get("terrain_presentation", {}) if repeated_presentation.get("terrain_presentation", {}) is Dictionary else {}
	var repeated_lighting: Dictionary = repeated_terrain.get("terrain_macro_lighting", {}) if repeated_terrain.get("terrain_macro_lighting", {}) is Dictionary else {}
	if repeated_lighting != north_west_lighting:
		_fail("Ninefold smoke: terrain macro-lighting changed across repeated observation.")
		return false
	var repeated_grain: Dictionary = repeated_terrain.get("terrain_grain_overlay", {}) if repeated_terrain.get("terrain_grain_overlay", {}) is Dictionary else {}
	if repeated_grain != grain_rows[0]:
		_fail("Ninefold smoke: terrain grain changed across repeated observation.")
		return false
	var repeated_detail: Dictionary = repeated_terrain.get("terrain_detail_decal", {}) if repeated_terrain.get("terrain_detail_decal", {}) is Dictionary else {}
	if repeated_detail != detail_rows[0]:
		_fail("Ninefold smoke: terrain detail decal changed across repeated observation.")
		return false
	var north_west_samples: Array = north_west_lighting.get("corner_samples", [])
	var east_samples: Array = (lighting_rows[1] as Dictionary).get("corner_samples", [])
	var south_samples: Array = (lighting_rows[2] as Dictionary).get("corner_samples", [])
	var south_east_samples: Array = (lighting_rows[3] as Dictionary).get("corner_samples", [])
	if (
		north_west_samples[1] != east_samples[0]
		or north_west_samples[2] != east_samples[3]
		or north_west_samples[3] != south_samples[0]
		or north_west_samples[2] != south_samples[1]
		or north_west_samples[2] != south_east_samples[0]
	):
		_fail("Ninefold smoke: adjacent terrain tiles do not share exact macro-lighting corner samples: %s." % JSON.stringify(lighting_rows))
		return false
	var hidden_tile := Vector2i(-1, -1)
	var map_size := OverworldRules.derive_map_size(session)
	for y in range(map_size.y - 1, -1, -1):
		for x in range(map_size.x - 1, -1, -1):
			if not OverworldRules.is_tile_explored(session, x, y):
				hidden_tile = Vector2i(x, y)
				break
		if hidden_tile.x >= 0:
			break
	if hidden_tile.x < 0:
		_fail("Ninefold smoke: terrain macro-lighting fixture could not find an unexplored tile.")
		return false
	var hidden_presentation: Dictionary = shell.call("validation_tile_presentation", hidden_tile.x, hidden_tile.y)
	var hidden_terrain: Dictionary = hidden_presentation.get("terrain_presentation", {}) if hidden_presentation.get("terrain_presentation", {}) is Dictionary else {}
	var hidden_lighting: Dictionary = hidden_terrain.get("terrain_macro_lighting", {}) if hidden_terrain.get("terrain_macro_lighting", {}) is Dictionary else {}
	var hidden_grain: Dictionary = hidden_terrain.get("terrain_grain_overlay", {}) if hidden_terrain.get("terrain_grain_overlay", {}) is Dictionary else {}
	var hidden_detail: Dictionary = hidden_terrain.get("terrain_detail_decal", {}) if hidden_terrain.get("terrain_detail_decal", {}) is Dictionary else {}
	var hidden_water_ripples: Dictionary = hidden_terrain.get("water_surface_ripples", {}) if hidden_terrain.get("water_surface_ripples", {}) is Dictionary else {}
	if String(hidden_lighting.get("model", "")) != "continuous_shared_corner_bilinear_field" or bool(hidden_lighting.get("drawn", true)) or not bool(hidden_lighting.get("hidden_by_unexplored_shroud", false)):
		_fail("Ninefold smoke: unexplored fog did not remain authoritative over terrain macro-lighting: %s." % JSON.stringify(hidden_lighting))
		return false
	if String(hidden_grain.get("model", "")) != "single_normalized_map_space_seamless_painterly_microtexture" or bool(hidden_grain.get("drawn", true)) or not bool(hidden_grain.get("hidden_by_unexplored_shroud", false)) or bool(hidden_grain.get("terrain_identity_sampled", true)):
		_fail("Ninefold smoke: unexplored fog did not remain authoritative over terrain grain: %s." % JSON.stringify(hidden_grain))
		return false
	if String(hidden_detail.get("model", "")) != "rich_biome_aware_painterly_surface_clusters_v2" or bool(hidden_detail.get("drawn", true)) or not bool(hidden_detail.get("hidden_by_unexplored_shroud", false)) or bool(hidden_detail.get("terrain_identity_sampled", true)):
		_fail("Ninefold smoke: unexplored fog did not remain authoritative over terrain surface detail: %s." % JSON.stringify(hidden_detail))
		return false
	if String(hidden_water_ripples.get("model", "")) != "deterministic_broken_painterly_current_pairs" or bool(hidden_water_ripples.get("drawn", true)) or not bool(hidden_water_ripples.get("hidden_by_unexplored_shroud", false)) or bool(hidden_water_ripples.get("terrain_identity_sampled", true)):
		_fail("Ninefold smoke: unexplored fog did not remain authoritative over water current ripples: %s." % JSON.stringify(hidden_water_ripples))
		return false
	if not _assert_soft_fog_frontier(shell, session, north_west_tile):
		return false
	if session.to_dict() != session_authority_before:
		_fail("Ninefold smoke: terrain macro-lighting observation changed session authority.")
		return false
	return true

func _terrain_detail_decal_payload_exact(detail: Dictionary, expected_group: String) -> bool:
	var expected_cell_ids: Array = []
	match expected_group:
		"grasslands":
			expected_cell_ids = [0, 1, 6, 8, 10, 11, 12, 15]
		"forest":
			expected_cell_ids = [3, 4, 7, 9, 13, 14]
		"mire":
			expected_cell_ids = [5, 8, 10, 15]
		"rough", "rock", "underground":
			expected_cell_ids = [2, 3, 4, 9, 13, 14]
		"dirt", "sand":
			expected_cell_ids = [2, 3, 7, 13]
		"ash":
			expected_cell_ids = [3, 7, 10, 13]
	if (
		String(detail.get("model", "")) != "rich_biome_aware_painterly_surface_clusters_v2"
		or String(detail.get("source_model", "")) != "original_generated_clean_alpha_4x4_natural_cluster_atlas"
		or String(detail.get("terrain_group", "")) != expected_group
		or not bool(detail.get("atlas_texture_loaded", false))
		or String(detail.get("atlas_texture_path", "")) != "res://art/overworld/runtime/terrain_tiles/detail/terrain_detail_decal_atlas_rich_v2.png"
		or detail.get("atlas_size", {}) != {"x": 1024, "y": 1024}
		or detail.get("atlas_grid", {}) != {"x": 4, "y": 4}
		or detail.get("atlas_cell_size", {}) != {"x": 256, "y": 256}
		or int(detail.get("density_modulus", 0)) != 2
		or bool(detail.get("interactive", true))
		or bool(detail.get("collision", true))
		or not is_equal_approx(float(detail.get("modulate_alpha", 0.0)), 0.88)
		or String(detail.get("draw_order", "")) != "after_macro_lighting_before_roads_objects_and_fog"
		or not bool(detail.get("hidden_by_unexplored_shroud", false))
		or String(detail.get("variation_basis", "")) != "tile_coordinate_and_terrain_id_only"
	):
		return false
	if not bool(detail.get("drawn", false)):
		return int(detail.get("cell_id", -2)) == -1
	var cell_id := int(detail.get("cell_id", -1))
	var source_rect: Dictionary = detail.get("source_rect", {}) if detail.get("source_rect", {}) is Dictionary else {}
	var destination_rect: Dictionary = detail.get("destination_rect", {}) if detail.get("destination_rect", {}) is Dictionary else {}
	var offset: Dictionary = detail.get("offset_factor", {}) if detail.get("offset_factor", {}) is Dictionary else {}
	var extent_factor := float(detail.get("extent_factor", 0.0))
	return (
		cell_id in expected_cell_ids
		and int(source_rect.get("x", -1)) == (cell_id % 4) * 256
		and int(source_rect.get("y", -1)) == floori(float(cell_id) / 4.0) * 256
		and int(source_rect.get("width", 0)) == 256
		and int(source_rect.get("height", 0)) == 256
		and bool(detail.get("destination_contained", false))
		and extent_factor >= 0.38 and extent_factor <= 0.52
		and float(offset.get("x", -1.0)) >= -0.13 and float(offset.get("x", 1.0)) <= 0.13
		and float(offset.get("y", -1.0)) >= -0.08 and float(offset.get("y", 1.0)) <= 0.12
		and float(destination_rect.get("width", 0.0)) > 0.0
		and is_equal_approx(float(destination_rect.get("width", 0.0)), float(destination_rect.get("height", -1.0)))
	)

func _water_surface_ripple_payload_exact(ripples: Dictionary, expected_drawn: bool, expected_road_excluded: bool) -> bool:
	if (
		String(ripples.get("model", "")) != "deterministic_broken_painterly_current_pairs"
		or String(ripples.get("terrain_group", "")) != "water"
		or bool(ripples.get("drawn", not expected_drawn)) != expected_drawn
		or bool(ripples.get("road_excluded", not expected_road_excluded)) != expected_road_excluded
		or int(ripples.get("density_modulus", 0)) != 3
		or ripples.get("active_residues", []) != [0, 1]
		or int(ripples.get("point_count_per_ripple", 0)) != 5
		or not is_equal_approx(float(ripples.get("min_length_factor", 0.0)), 0.26)
		or not is_equal_approx(float(ripples.get("max_length_factor", 0.0)), 0.48)
		or not is_equal_approx(float(ripples.get("min_curve_factor", 0.0)), 0.018)
		or not is_equal_approx(float(ripples.get("max_curve_factor", 0.0)), 0.042)
		or not is_equal_approx(float(ripples.get("shadow_alpha", 0.0)), 0.24)
		or not is_equal_approx(float(ripples.get("highlight_alpha", 0.0)), 0.30)
		or bool(ripples.get("interactive", true))
		or bool(ripples.get("collision", true))
		or bool(ripples.get("animated", true))
		or String(ripples.get("variation_basis", "")) != "tile_coordinate_and_ripple_index_only"
		or String(ripples.get("draw_order", "")) != "after_macro_lighting_before_causeways_objects_routes_selection_and_fog"
		or not bool(ripples.get("hidden_by_unexplored_shroud", false))
	):
		return false
	if not expected_drawn:
		return int(ripples.get("ripple_count", -1)) == 0 and (ripples.get("profiles", []) as Array).is_empty() and not bool(ripples.get("geometry_contained", true))
	var profiles: Array = ripples.get("profiles", []) if ripples.get("profiles", []) is Array else []
	if int(ripples.get("density_residue", -1)) not in [0, 1] or int(ripples.get("ripple_count", 0)) != 2 or profiles.size() != 2 or not bool(ripples.get("geometry_contained", false)):
		return false
	for profile_value in profiles:
		var profile: Array = profile_value if profile_value is Array else []
		if profile.size() != 5:
			return false
		for point_value in profile:
			var point: Dictionary = point_value if point_value is Dictionary else {}
			if float(point.get("x", -1.0)) < 0.0 or float(point.get("x", 2.0)) > 1.0 or float(point.get("y", -1.0)) < 0.0 or float(point.get("y", 2.0)) > 1.0:
				return false
		var start: Dictionary = profile[0]
		var finish: Dictionary = profile[4]
		var length_factor := float(finish.get("x", 0.0)) - float(start.get("x", 0.0))
		if length_factor < 0.26 or length_factor > 0.48 or not is_equal_approx(float(start.get("y", -1.0)), float(finish.get("y", -2.0))):
			return false
	return true

func _assert_soft_fog_frontier(shell: Node, session, north_west_tile: Vector2i) -> bool:
	var session_authority_before: Dictionary = session.to_dict()
	var cases := [
		{"tile": north_west_tile, "directions": ["N", "W"], "corners": ["NW"]},
		{"tile": north_west_tile + Vector2i(2, 0), "directions": ["N", "E"], "corners": ["NE"]},
		{"tile": north_west_tile + Vector2i(2, 2), "directions": ["E", "S"], "corners": ["SE"]},
		{"tile": north_west_tile + Vector2i(0, 2), "directions": ["S", "W"], "corners": ["SW"]},
		{"tile": north_west_tile + Vector2i(1, 1), "directions": [], "corners": []},
	]
	var observed_rows: Array = []
	for case_value in cases:
		var case_row: Dictionary = case_value
		var tile: Vector2i = case_row.get("tile", Vector2i(-1, -1))
		var presentation: Dictionary = shell.call("validation_tile_presentation", tile.x, tile.y)
		var terrain: Dictionary = presentation.get("terrain_presentation", {}) if presentation.get("terrain_presentation", {}) is Dictionary else {}
		var frontier: Dictionary = terrain.get("fog_frontier", {}) if terrain.get("fog_frontier", {}) is Dictionary else {}
		if (
			String(frontier.get("model", "")) != "segmented_deep_inward_cartographic_veil_feather"
			or frontier.get("direction_order", []) != ["N", "E", "S", "W"]
			or frontier.get("directions", []) != case_row.get("directions", [])
			or frontier.get("softened_corners", []) != case_row.get("corners", [])
			or bool(frontier.get("drawn", false)) != not (case_row.get("directions", []) as Array).is_empty()
			or String(frontier.get("surface_model", "")) != "boundary_cap_plus_contour_segment_quads"
			or not is_equal_approx(float(frontier.get("cap_alpha", 0.0)), 0.54)
			or int(frontier.get("cap_polygon_point_count", 0)) != 9
			or int(frontier.get("gradient_stop_count", 0)) != 2
			or not is_equal_approx(float(frontier.get("gradient_depth_factor", 0.0)), 0.32)
			or not is_equal_approx(float(frontier.get("gradient_edge_alpha", 0.0)), 0.34)
			or not is_equal_approx(float(frontier.get("gradient_inner_alpha", -1.0)), 0.0)
			or int(frontier.get("gradient_segment_count_per_direction", 0)) != 8
			or not is_equal_approx(float(frontier.get("edge_alpha", 0.0)), 0.22)
			or not is_equal_approx(float(frontier.get("edge_width", 0.0)), 1.0)
			or int(frontier.get("contour_point_count", 0)) != 9
			or not is_equal_approx(float(frontier.get("contour_min_inset_factor", 0.0)), 0.05)
			or not is_equal_approx(float(frontier.get("contour_max_inset_factor", 0.0)), 0.14)
			or not bool(frontier.get("contour_endpoints_on_boundary", false))
			or bool(frontier.get("contour_hidden_side_intrusion", true))
			or String(frontier.get("contour_variation_basis", "")) != "explored_tile_direction_only"
			or String(frontier.get("draw_side", "")) != "explored_inward"
			or String(frontier.get("neighbor_basis", "")) != "cardinal_explored_boolean_only"
			or bool(frontier.get("hidden_identity_sampled", true))
			or bool(frontier.get("interior_explored_seams", true))
			or not _fog_contour_profiles_exact(frontier, case_row.get("directions", []))
		):
			_fail("Ninefold smoke: explored fog frontier contract changed: %s." % JSON.stringify({"case": case_row, "frontier": frontier}))
			return false
		observed_rows.append(frontier)
	var repeated_presentation: Dictionary = shell.call("validation_tile_presentation", north_west_tile.x, north_west_tile.y)
	var repeated_terrain: Dictionary = repeated_presentation.get("terrain_presentation", {}) if repeated_presentation.get("terrain_presentation", {}) is Dictionary else {}
	if repeated_terrain.get("fog_frontier", {}) != observed_rows[0]:
		_fail("Ninefold smoke: fog frontier changed across repeated public observation.")
		return false
	var hidden_tile := north_west_tile + Vector2i(3, 0)
	var hidden_presentation: Dictionary = shell.call("validation_tile_presentation", hidden_tile.x, hidden_tile.y)
	var hidden_terrain: Dictionary = hidden_presentation.get("terrain_presentation", {}) if hidden_presentation.get("terrain_presentation", {}) is Dictionary else {}
	var hidden_frontier: Dictionary = hidden_terrain.get("fog_frontier", {}) if hidden_terrain.get("fog_frontier", {}) is Dictionary else {}
	if (
		not bool(hidden_terrain.get("unexplored_hidden", false))
		or String(hidden_terrain.get("terrain", "leaked")) != ""
		or String(hidden_frontier.get("model", "")) != "segmented_deep_inward_cartographic_veil_feather"
		or bool(hidden_frontier.get("drawn", true))
		or String(hidden_frontier.get("draw_side", "")) != "explored_inward"
		or bool(hidden_frontier.get("hidden_identity_sampled", true))
	):
		_fail("Ninefold smoke: hidden tile identity or fog-frontier ownership leaked: %s." % JSON.stringify(hidden_terrain))
		return false
	if session.to_dict() != session_authority_before:
		_fail("Ninefold smoke: fog-frontier observation changed session authority.")
		return false
	return true

func _fog_contour_profiles_exact(frontier: Dictionary, expected_directions: Array) -> bool:
	var profiles: Dictionary = frontier.get("contour_profiles", {}) if frontier.get("contour_profiles", {}) is Dictionary else {}
	if profiles.keys() != expected_directions:
		return false
	for direction_value in expected_directions:
		var direction := String(direction_value)
		var profile: Array = profiles.get(direction, []) if profiles.get(direction, []) is Array else []
		if profile.size() != 9:
			return false
		for point_index in range(profile.size()):
			var point: Dictionary = profile[point_index] if profile[point_index] is Dictionary else {}
			var x := float(point.get("x", -1.0))
			var y := float(point.get("y", -1.0))
			var progress := float(point_index) / 8.0
			var endpoint := point_index == 0 or point_index == 8
			match direction:
				"N":
					if not is_equal_approx(x, progress) or (endpoint and not is_zero_approx(y)) or (not endpoint and (y < 0.05 or y > 0.14)):
						return false
				"S":
					if not is_equal_approx(x, progress) or (endpoint and not is_equal_approx(y, 1.0)) or (not endpoint and (y < 0.86 or y > 0.95)):
						return false
				"W":
					if not is_equal_approx(y, progress) or (endpoint and not is_zero_approx(x)) or (not endpoint and (x < 0.05 or x > 0.14)):
						return false
				"E":
					if not is_equal_approx(y, progress) or (endpoint and not is_equal_approx(x, 1.0)) or (not endpoint and (x < 0.86 or x > 0.95)):
						return false
				_:
					return false
	return true

func _assert_enabled_homm3_transition_ownership(shell: Node, session, receiver_tile: Vector2i) -> bool:
	var map_view = shell.get_node_or_null("%Map")
	if map_view == null:
		_fail("Ninefold smoke: enabled HoMM3 transition ownership fixture could not resolve MapView.")
		return false
	var session_authority_before: Dictionary = session.to_dict()
	var original_prototype: Dictionary = map_view.get("_homm3_prototype").duplicate(true)
	var enabled_prototype := original_prototype.duplicate(true)
	enabled_prototype["enabled"] = true
	map_view.set("_homm3_prototype", enabled_prototype)
	var enabled_presentation: Dictionary = shell.call("validation_tile_presentation", receiver_tile.x, receiver_tile.y)
	map_view.set("_homm3_prototype", original_prototype)
	var terrain: Dictionary = enabled_presentation.get("terrain_presentation", {}) if enabled_presentation.get("terrain_presentation", {}) is Dictionary else {}
	var shoreline: Dictionary = terrain.get("water_shoreline_contour", {}) if terrain.get("water_shoreline_contour", {}) is Dictionary else {}
	if session.to_dict() != session_authority_before:
		_fail("Ninefold smoke: enabled HoMM3 transition ownership fixture changed session authority.")
		return false
	if (
		not bool(terrain.get("uses_homm3_local_prototype", false))
		or not bool(terrain.get("homm3_transition_self_contained", false))
		or bool(terrain.get("generic_transition_overlay_active", true))
		or String(terrain.get("transition_shape_model", "")) != "homm3_base_atlas_frame"
		or String(terrain.get("generic_transition_surface_model", "leaked")) != ""
		or int(terrain.get("generic_transition_feather_band_count", -1)) != 0
		or bool(terrain.get("generic_transition_irregular_inner_edge", true))
		or String(shoreline.get("model", "")) != "shared_lattice_nine_sample_layered_natural_bank"
		or bool(shoreline.get("active", true))
		or int(shoreline.get("source_count", -1)) != 0
		or String((terrain.get("terrain_macro_lighting", {}) as Dictionary).get("model", "")) != "continuous_shared_corner_bilinear_field"
		or not bool((terrain.get("terrain_macro_lighting", {}) as Dictionary).get("drawn", false))
	):
		_fail("Ninefold smoke: enabled and loaded HoMM3 receiver did not exclusively own its self-contained transition art: %s." % enabled_presentation)
		return false
	return true

func _assert_direct_dirt_sand_transition(shell: Node, session) -> bool:
	var dirt_receiver := Vector2i(34, 1)
	var sand_source := Vector2i(35, 1)
	_reveal_validation_tiles(session, [dirt_receiver, sand_source])
	var dirt_presentation: Dictionary = shell.call("validation_tile_presentation", dirt_receiver.x, dirt_receiver.y)
	var dirt_terrain: Dictionary = dirt_presentation.get("terrain_presentation", {})
	if (
		String(dirt_terrain.get("terrain", "")) != "dirt"
		or String(dirt_terrain.get("homm3_terrain_family", "")) != "dirt"
		or String(dirt_terrain.get("homm3_terrain_atlas", "")) != "dirttl"
		or String(dirt_terrain.get("transition_edge_mask", "")) != "E"
		or String(dirt_terrain.get("homm3_selection_kind", "")) != "bridge_transition"
		or String(dirt_terrain.get("homm3_bridge_family", "")) != "sand"
		or String(dirt_terrain.get("homm3_bridge_resolution_model", "")) != "accepted_web_relation_function"
		or String(dirt_terrain.get("homm3_visual_selection_model", "")) != "accepted_web_prototype_relation_class_row_lookup.v1"
		or not _transition_sources_include_bridge(dirt_terrain, "E", "sand", "sand", "direct_dirt_sand_receiver_lookup")
	):
		_fail("Ninefold smoke: canonical direct dirt/sand boundary did not keep direct-pair diagnostics: %s." % dirt_presentation)
		return false
	return true

func _transition_sources_include_bridge(terrain: Dictionary, direction: String, source_terrain: String, bridge_family: String, bridge_model: String) -> bool:
	var sources: Array = terrain.get("transition_cardinal_sources", [])
	for source_value in sources:
		if not (source_value is Dictionary):
			continue
		var source: Dictionary = source_value
		if (
			String(source.get("direction", "")) == direction
			and String(source.get("source_terrain", "")) == source_terrain
			and String(source.get("resolved_bridge_family", "")) == bridge_family
			and String(source.get("bridge_resolution_model", "")) == bridge_model
			and (bool(source.get("uses_direct_bridge_pair", false)) or bool(source.get("uses_direct_bridge_material_contact", false)))
		):
			return true
	return false

func _assert_full_receiver_stamp_payload(terrain: Dictionary, expected: Dictionary) -> bool:
	if not bool(terrain.get("homm3_uses_land_receiver_stamp_tables", false)):
		return false
	if bool(terrain.get("homm3_allows_generic_land_edge_masks", true)):
		return false
	if String(terrain.get("homm3_visual_selection_model", "")) != "accepted_web_prototype_relation_class_row_lookup.v1":
		return false
	if String(terrain.get("homm3_final_normalization_model", "")) != "final_normalization_4bbfcc_reclassifies_settled_owner_map":
		return false
	if String(terrain.get("homm3_stamp_selection_model", "")) != "":
		return false
	if String(terrain.get("homm3_stamp_selected_frame", "")) != "":
		return false
	if int(terrain.get("homm3_shape_class", 0)) <= 0:
		return false
	if String(terrain.get("homm3_relation_grid", "")) == "":
		return false
	if String(expected.get("bridge_family", "")) != "" and String(terrain.get("homm3_bridge_family", "")) != String(expected.get("bridge_family", "")):
		return false
	if String(expected.get("target_block", "")) != "" and String(terrain.get("homm3_selected_frame_block", "")) != String(expected.get("target_block", "")):
		return false
	if expected.has("shape_class") and int(terrain.get("homm3_shape_class", 0)) != int(expected.get("shape_class", -1)):
		return false
	if expected.has("row_group") and String(terrain.get("homm3_row_group", "")) != String(expected.get("row_group", "")):
		return false
	if expected.has("frame") and expected.has("shape_class") and String(terrain.get("homm3_terrain_frame", "")) != String(expected.get("frame", "")):
		return false
	var expected_flip := String(expected.get("flip", String(terrain.get("homm3_terrain_flip", ""))))
	if String(terrain.get("homm3_terrain_flip", "")) != expected_flip:
		return false
	if expected.has("flip_h") and bool(terrain.get("homm3_terrain_flip_h", false)) != bool(expected.get("flip_h", false)):
		return false
	if expected.has("flip_v") and bool(terrain.get("homm3_terrain_flip_v", false)) != bool(expected.get("flip_v", false)):
		return false
	if String(terrain.get("homm3_web_prototype_selection_model", "")) != String(terrain.get("homm3_visual_selection_model", "")):
		return false
	return true

func _assert_homm_road_topology(shell: Node, session) -> bool:
	var vertical_tile := Vector2i(23, 30)
	var horizontal_tile := Vector2i(26, 42)
	var intersection_tile := Vector2i(23, 42)
	var straight_tile := Vector2i(20, 45)
	_reveal_validation_tiles(session, [vertical_tile, horizontal_tile, intersection_tile, straight_tile])

	shell.call("validation_select_tile", vertical_tile.x, vertical_tile.y)
	var vertical_presentation: Dictionary = shell.call("validation_tile_presentation", vertical_tile.x, vertical_tile.y)
	var vertical_terrain: Dictionary = vertical_presentation.get("terrain_presentation", {})
	if not _assert_land_road_render_model(vertical_terrain, vertical_presentation, "vertical"):
		return false
	if String(vertical_terrain.get("road_connection_source", "")) != "orthogonal_same_type_road_tiles" or not bool(vertical_terrain.get("road_same_type_adjacency", false)):
		_fail("Ninefold smoke: vertical road did not rebuild from 4-neighbor same-type road tiles: %s." % vertical_presentation)
		return false
	if String(vertical_terrain.get("road_connection_key", "")) != "N+S" or int(vertical_terrain.get("road_connection_count", 0)) != 2:
		_fail("Ninefold smoke: vertical road run did not expose clean N+S topology: %s." % vertical_presentation)
		return false
	if not bool(vertical_terrain.get("road_vertical_centered", false)) or String(vertical_terrain.get("road_vertical_lane", "")) != "orthogonal_mask_frame" or bool(vertical_terrain.get("road_horizontal_edge_riding", true)) or not bool(vertical_terrain.get("road_straight_tile_piece", false)):
		_fail("Ninefold smoke: vertical road run did not report the HoMM3 orthogonal-mask straight frame: %s." % vertical_presentation)
		return false
	if bool(vertical_terrain.get("road_joint_cap", true)):
		_fail("Ninefold smoke: vertical road straight still reports a center joint cap: %s." % vertical_presentation)
		return false

	shell.call("validation_select_tile", horizontal_tile.x, horizontal_tile.y)
	var horizontal_presentation: Dictionary = shell.call("validation_tile_presentation", horizontal_tile.x, horizontal_tile.y)
	var horizontal_terrain: Dictionary = horizontal_presentation.get("terrain_presentation", {})
	if not _assert_land_road_render_model(horizontal_terrain, horizontal_presentation, "horizontal"):
		return false
	if String(horizontal_terrain.get("road_connection_source", "")) != "orthogonal_same_type_road_tiles" or String(horizontal_terrain.get("road_connection_key", "")) != "E+W":
		_fail("Ninefold smoke: horizontal road run did not use same-type E+W topology: %s." % horizontal_presentation)
		return false
	if bool(horizontal_terrain.get("road_horizontal_edge_riding", true)) or String(horizontal_terrain.get("road_horizontal_lane", "")) != "orthogonal_mask_frame" or bool(horizontal_terrain.get("road_vertical_centered", true)) or not bool(horizontal_terrain.get("road_straight_tile_piece", false)):
		_fail("Ninefold smoke: horizontal road run did not report the HoMM3 orthogonal-mask straight frame: %s." % horizontal_presentation)
		return false
	if bool(horizontal_terrain.get("road_joint_cap", true)):
		_fail("Ninefold smoke: horizontal road straight still reports a center joint cap: %s." % horizontal_presentation)
		return false

	shell.call("validation_select_tile", intersection_tile.x, intersection_tile.y)
	var intersection_presentation: Dictionary = shell.call("validation_tile_presentation", intersection_tile.x, intersection_tile.y)
	var intersection_terrain: Dictionary = intersection_presentation.get("terrain_presentation", {})
	if not _assert_land_road_render_model(intersection_terrain, intersection_presentation, "intersection"):
		return false
	if String(intersection_terrain.get("road_connection_key", "")) != "N+E" or int(intersection_terrain.get("road_connection_count", 0)) != 2:
		_fail("Ninefold smoke: road corner tile did not select from orthogonal same-type neighbors only: %s." % intersection_presentation)
		return false
	if not bool(intersection_terrain.get("road_joint_cap", false)) or bool(intersection_terrain.get("road_horizontal_edge_riding", true)) or not bool(intersection_terrain.get("road_vertical_centered", false)):
		_fail("Ninefold smoke: road corner tile did not keep the 4-neighbor joint metadata: %s." % intersection_presentation)
		return false

	shell.call("validation_select_tile", straight_tile.x, straight_tile.y)
	var straight_presentation: Dictionary = shell.call("validation_tile_presentation", straight_tile.x, straight_tile.y)
	var straight_terrain: Dictionary = straight_presentation.get("terrain_presentation", {})
	if not _assert_land_road_render_model(straight_terrain, straight_presentation, "isolated"):
		return false
	if String(straight_terrain.get("road_connection_source", "")) != "orthogonal_same_type_road_tiles" or String(straight_terrain.get("road_connection_key", "")) != "":
		_fail("Ninefold smoke: diagonal-only neighboring road tiles were not suppressed by 4-neighbor topology: %s." % straight_presentation)
		return false
	if int(straight_terrain.get("road_connection_count", 0)) != 0 or bool(straight_terrain.get("road_diagonal_tile_piece", true)) or String(straight_terrain.get("road_diagonal_piece_model", "")) != "":
		_fail("Ninefold smoke: diagonal road metadata still reports diagonal tile pieces: %s." % straight_presentation)
		return false
	if not bool(straight_terrain.get("road_joint_cap", false)) or bool(straight_terrain.get("road_diagonal_connections", true)):
		_fail("Ninefold smoke: isolated 4-neighbor road tile did not report diagonal suppression cleanly: %s." % straight_presentation)
		return false
	if not _assert_explicit_road_frame_ownership(shell, session, vertical_tile):
		return false
	return true

func _assert_land_road_render_model(terrain: Dictionary, presentation: Dictionary, label: String) -> bool:
	if String(terrain.get("terrain", "")) == "water":
		_fail("Ninefold smoke: %s land-road fixture unexpectedly uses water terrain: %s." % [label, presentation])
		return false
	if String(terrain.get("road_render_model", "")) != "layered_wheel_rutted_dirt_path" or String(terrain.get("road_shape_model", "")) != "terrain_integrated_4_neighbor_surface":
		_fail("Ninefold smoke: %s road did not use the terrain-integrated wheel-rutted surface: %s." % [label, presentation])
		return false
	if String(terrain.get("road_surface_material", "")) != "packed_earth_with_twin_wheel_ruts" or String(terrain.get("road_surface_detail", "")) != "soft_shoulders_twin_ruts_and_dust_center":
		_fail("Ninefold smoke: %s road did not expose the packed-earth/rut treatment: %s." % [label, presentation])
		return false
	if not bool(terrain.get("road_ordinary_tile_art_bypassed", false)) or bool(terrain.get("road_explicit_source_frame_rendered", true)):
		_fail("Ninefold smoke: %s ordinary road did not bypass the timber-bar art while retaining source-frame separation: %s." % [label, presentation])
		return false
	return true

func _assert_explicit_road_frame_ownership(shell: Node, session, road_tile: Vector2i) -> bool:
	var map_view = shell.get_node_or_null("%Map")
	if map_view == null:
		_fail("Ninefold smoke: explicit road-frame fixture could not resolve MapView.")
		return false
	var session_authority_before: Dictionary = session.to_dict()
	var original_prototype: Dictionary = map_view.get("_homm3_prototype").duplicate(true)
	var enabled_prototype := original_prototype.duplicate(true)
	enabled_prototype["enabled"] = true
	map_view.set("_homm3_prototype", enabled_prototype)
	var source_presentation: Dictionary = shell.call("validation_tile_presentation", road_tile.x, road_tile.y)
	map_view.set("_homm3_prototype", original_prototype)
	if session.to_dict() != session_authority_before:
		_fail("Ninefold smoke: explicit road-frame observation changed session authority.")
		return false
	var terrain: Dictionary = source_presentation.get("terrain_presentation", {})
	if String(terrain.get("road_render_model", "")) != "explicit_source_frame" or not bool(terrain.get("road_explicit_source_frame_rendered", false)) or bool(terrain.get("road_ordinary_tile_art_bypassed", true)):
		_fail("Ninefold smoke: enabled loaded road frame did not retain explicit source ownership: %s." % source_presentation)
		return false
	if String(terrain.get("road_shape_model", "")) != "homm3_4_neighbor_overlay_lookup" or String(terrain.get("road_source_frame_path", "")) != "res://art/overworld/runtime/homm3_local_prototype/roads/dirtrd/00_10.png":
		_fail("Ninefold smoke: N+S source road did not resolve the exact dirtrd 00_10 frame: %s." % source_presentation)
		return false
	if String(terrain.get("road_connection_key", "")) != "N+S" or int(terrain.get("road_connection_count", 0)) != 2:
		_fail("Ninefold smoke: enabling source road art changed the N+S topology: %s." % source_presentation)
		return false
	return true

func _reveal_validation_tiles(session, tiles: Array) -> void:
	var map_size := OverworldRules.derive_map_size(session)
	var visible_tiles := []
	var explored_tiles := []
	for y in range(map_size.y):
		var visible_row := []
		var explored_row := []
		for x in range(map_size.x):
			visible_row.append(false)
			explored_row.append(false)
		visible_tiles.append(visible_row)
		explored_tiles.append(explored_row)
	for tile_value in tiles:
		if not (tile_value is Vector2i):
			continue
		var tile: Vector2i = tile_value
		if tile.x < 0 or tile.y < 0 or tile.x >= map_size.x or tile.y >= map_size.y:
			continue
		visible_tiles[tile.y][tile.x] = true
		explored_tiles[tile.y][tile.x] = true
	session.overworld["fog"] = {
		"visible_tiles": visible_tiles,
		"explored_tiles": explored_tiles,
		"visible_count": tiles.size(),
		"explored_count": tiles.size(),
		"total_tiles": map_size.x * map_size.y,
	}

func _assert_large_map_marker_readability(shell: Node) -> bool:
	if not shell.has_method("validation_tile_presentation"):
		_fail("Ninefold smoke: OverworldShell did not expose tile marker presentation validation.")
		return false
	var town_tile := Vector2i(23, 26)
	var town_presentation: Dictionary = shell.call("validation_tile_presentation", town_tile.x, town_tile.y)
	if not _assert_marker_style(town_presentation, "town", false):
		return false
	if not _assert_town_footprint_profile(shell, town_presentation):
		return false
	var terrain_presentation: Dictionary = town_presentation.get("terrain_presentation", {})
	if String(terrain_presentation.get("rendering_mode", "")) != "original_quiet_tile_bank" or bool(terrain_presentation.get("uses_sampled_texture", true)) or bool(terrain_presentation.get("generated_source_primary", true)) or bool(terrain_presentation.get("uses_homm3_local_prototype", true)) or not bool(terrain_presentation.get("uses_original_tile_bank", false)):
		_fail("Ninefold smoke: large-map starting terrain is not using the shippable original quiet tile bank: %s." % town_presentation)
		return false
	if String(terrain_presentation.get("primary_base_model", "")) != "original_quiet_tile_bank" or String(terrain_presentation.get("terrain_noise_profile", "")) != "quiet_low_contrast_macro_readable" or String(terrain_presentation.get("tile_art_source_basis", "")) != "original_procedural_reference_informed":
		_fail("Ninefold smoke: large-map starting terrain does not expose the original authored base model: %s." % town_presentation)
		return false
	if String(terrain_presentation.get("terrain_variant_selection", "")) != "patch_cohesive_low_frequency" or String(terrain_presentation.get("homm3_terrain_lookup_model", "")) != "accepted_web_prototype_relation_class_row_lookup" or not bool(terrain_presentation.get("homm3_local_reference_only", false)):
		_fail("Ninefold smoke: large-map starting grasslands terrain does not use original tile selection while retaining inactive reference metadata: %s." % town_presentation)
		return false
	if String(terrain_presentation.get("homm3_interior_frame_selection", "")) != "accepted_web_full_row_bucket_selection" or bool(terrain_presentation.get("homm3_uses_interior_variant_cycle", true)):
		_fail("Ninefold smoke: large-map starting terrain still reports the retired HoMM3 interior patch-variant cycling contract: %s." % town_presentation)
		return false
	if String(terrain_presentation.get("visible_terrain_grid_mode", "")) != "fog_boundary_only" or float(terrain_presentation.get("visible_terrain_grid_alpha", 1.0)) > 0.01 or bool(terrain_presentation.get("explored_intertile_seams", true)):
		_fail("Ninefold smoke: large-map visible terrain still reports per-cell black grid seams: %s." % town_presentation)
		return false
	if not bool(terrain_presentation.get("road_overlay", false)) or String(terrain_presentation.get("road_overlay_id", "")) != "road_dirt" or not bool(terrain_presentation.get("road_overlay_art", false)) or String(terrain_presentation.get("road_shape_model", "")) != "terrain_integrated_4_neighbor_surface":
		_fail("Ninefold smoke: large-map starting road does not retain its ordinary art availability while rendering through the terrain-integrated 4-neighbor surface: %s." % town_presentation)
		return false
	if not _assert_land_road_render_model(terrain_presentation, town_presentation, "starting town"):
		return false
	if String(terrain_presentation.get("road_connection_source", "")) != "orthogonal_same_type_road_tiles" or not bool(terrain_presentation.get("road_same_type_adjacency", false)) or not bool(terrain_presentation.get("road_orthogonal_mask_only", false)):
		_fail("Ninefold smoke: large-map starting road is not using 4-neighbor same-type adjacency topology: %s." % town_presentation)
		return false
	if String(terrain_presentation.get("road_joint_cap_model", "")) != "connection_aware_joint_cap" or not bool(terrain_presentation.get("road_joint_cap", false)):
		_fail("Ninefold smoke: large-map starting road intersection does not expose the connection-aware joint cap contract: %s." % town_presentation)
		return false
	var town_readability: Dictionary = town_presentation.get("marker_readability", {})
	if not bool(town_readability.get("hero_emphasis", false)) or not bool(town_readability.get("selection_emphasis", false)):
		_fail("Ninefold smoke: active hero/current-selection emphasis is not readable on the large starting town tile: %s." % town_presentation)
		return false
	if not _assert_hero_presence_correction(town_readability, town_presentation):
		return false
	var town_art: Dictionary = town_presentation.get("art_presentation", {})
	var town_asset_ids: Array = town_art.get("sprite_asset_ids", [])
	if not bool(town_art.get("uses_asset_sprite", false)) or "town_faction_embercourt" not in town_asset_ids or bool(town_art.get("fallback_procedural_marker", true)):
		_fail("Ninefold smoke: large-map starting town is not using the exact Embercourt faction town sprite: %s." % town_presentation)
		return false
	if String(town_art.get("town_sprite_grounding_model", "")) != "town_sprite_settled_without_base_ellipse" or bool(town_art.get("town_base_ellipse", true)) or bool(town_art.get("town_cast_shadow", true)):
		_fail("Ninefold smoke: large-map starting town sprite did not use the corrected no-ellipse/no-cast-shadow grounding: %s." % town_presentation)
		return false

	var resource_tile := Vector2i(23, 24)
	var resource_presentation: Dictionary = shell.call("validation_tile_presentation", resource_tile.x, resource_tile.y)
	if not _assert_marker_style(resource_presentation, "resource", false):
		return false
	var art_presentation: Dictionary = resource_presentation.get("art_presentation", {})
	if bool(art_presentation.get("uses_asset_sprite", true)) or not bool(art_presentation.get("fallback_procedural_marker", false)):
		_fail("Ninefold smoke: unmapped large-map resource site did not keep procedural marker fallback: %s." % resource_presentation)
		return false
	if String(art_presentation.get("fallback_silhouette_model", "")) != "family_specific_procedural_world_object":
		_fail("Ninefold smoke: unmapped large-map resource site did not report family-specific procedural world-object fallback: %s." % resource_presentation)
		return false
	if String(art_presentation.get("fallback_grounding_model", "")) != "family_specific_contact_scuffs_no_marker_plate" or bool(art_presentation.get("fallback_shared_marker_plate", true)) or bool(art_presentation.get("fallback_upper_mass_backdrop", true)) or bool(art_presentation.get("fallback_foreground_lip", true)):
		_fail("Ninefold smoke: unmapped large-map resource site did not report the corrected no-plate/no-backdrop/no-lip fallback grounding: %s." % resource_presentation)
		return false
	if String(art_presentation.get("fallback_contact_shadow_model", "")) != "localized_object_contact_shadow":
		_fail("Ninefold smoke: unmapped large-map resource site did not report localized contact shadow grounding: %s." % resource_presentation)
		return false
	return true

func _assert_marker_style(presentation: Dictionary, expected_kind: String, remembered: bool) -> bool:
	var readability: Dictionary = presentation.get("marker_readability", {})
	var object_kinds: Array = readability.get("object_kinds", [])
	var is_town := expected_kind == "town"
	var uses_procedural_fallback := bool(readability.get("procedural_world_silhouette", false))
	var art: Dictionary = presentation.get("art_presentation", {})
	var uses_mapped_sprite := bool(art.get("uses_asset_sprite", false)) and not is_town
	if expected_kind not in object_kinds:
		_fail("Ninefold smoke: expected %s marker kind was missing on the large map: %s." % [expected_kind, presentation])
		return false
	if not bool(readability.get("ground_anchor", false)):
		_fail("Ninefold smoke: large-map %s marker lacks terrain-grounded placement metadata: %s." % [expected_kind, presentation])
		return false
	if String(readability.get("presence_model", "")) != "footprint_scaled_world_object":
		_fail("Ninefold smoke: large-map %s marker no longer reports object-first footprint presence: %s." % [expected_kind, presentation])
		return false
	var expected_occlusion := "town_sprite_settled_without_base_ellipse" if is_town else ("ground_contact_without_foreground_lip" if uses_procedural_fallback else ("sprite_contact_without_foreground_lip" if uses_mapped_sprite else ""))
	if String(readability.get("occlusion_model", "")) != expected_occlusion:
		_fail("Ninefold smoke: large-map %s marker no longer reports the expected foreground contact model: %s." % [expected_kind, presentation])
		return false
	if is_town:
		if not _assert_town_grounding_correction(readability, presentation):
			return false
	elif uses_procedural_fallback:
		if not _assert_procedural_fallback_grounding(readability, expected_kind, presentation):
			return false
	elif uses_mapped_sprite:
		if not _assert_mapped_sprite_grounding(readability, expected_kind, presentation):
			return false
	elif String(readability.get("anchor_shape", "")) != "terrain_ellipse_footprint":
		_fail("Ninefold smoke: large-map %s marker lacks a terrain-grounded anchor: %s." % [expected_kind, presentation])
		return false
	else:
		_fail("Ninefold smoke: large-map %s marker used an unsupported non-town/non-procedural/non-mapped grounding path: %s." % [expected_kind, presentation])
		return false
	if int(readability.get("footprint_width_tiles", 0)) <= 0 or int(readability.get("footprint_height_tiles", 0)) <= 0:
		_fail("Ninefold smoke: large-map %s marker does not expose footprint dimensions: %s." % [expected_kind, presentation])
		return false
	if expected_kind == "town":
		if int(readability.get("footprint_width_tiles", 0)) != 3 or int(readability.get("footprint_height_tiles", 0)) != 2:
			_fail("Ninefold smoke: large-map town marker must present as a 3x2 footprint: %s." % presentation)
			return false
		var town_presentation: Dictionary = presentation.get("town_presentation", {})
		if not bool(town_presentation.get("has_town_footprint", false)) or String(town_presentation.get("presentation_model", "")) != "town_3x2_footprint_bottom_middle_entry":
			_fail("Ninefold smoke: large-map town metadata does not expose the 3x2 presentation model: %s." % presentation)
			return false
		if String(town_presentation.get("entry_role", "")) != "bottom_middle_visit_approach" or not bool(town_presentation.get("entry_is_visit_tile", false)):
			_fail("Ninefold smoke: large-map town does not expose the bottom-middle visit approach tile: %s." % presentation)
			return false
		if not bool(town_presentation.get("is_entry_tile", false)) or String(town_presentation.get("tile_role", "")) != "bottom_middle_visit_approach":
			_fail("Ninefold smoke: large-map starting town tile is not reported as the entry approach: %s." % presentation)
			return false
		if not bool(town_presentation.get("non_entry_tiles_blocked", false)) or bool(town_presentation.get("visible_helper_cues", true)) or bool(town_presentation.get("footprint_helper_glyphs", true)) or bool(town_presentation.get("entry_apron_cue", true)) or bool(town_presentation.get("entry_wedge_cue", true)) or bool(town_presentation.get("gate_cue", true)) or bool(town_presentation.get("helper_circle_cue", true)):
			_fail("Ninefold smoke: large-map town must preserve blocked non-entry metadata without visible helper apron/gate/glyph cues: %s." % presentation)
			return false
	var min_anchor_width := 0.36 if uses_mapped_sprite else (0.40 if uses_procedural_fallback else 0.60)
	var min_anchor_height := 0.06 if uses_mapped_sprite else (0.12 if uses_procedural_fallback else 0.20)
	if float(readability.get("footprint_anchor_width_fraction", 0.0)) < min_anchor_width or float(readability.get("footprint_anchor_height_fraction", 0.0)) < min_anchor_height:
		_fail("Ninefold smoke: large-map %s footprint anchor is too small for object-first tactical framing: %s." % [expected_kind, presentation])
		return false
	if bool(readability.get("ui_badge_plate", true)):
		_fail("Ninefold smoke: large-map %s marker regressed to a UI badge plate: %s." % [expected_kind, presentation])
		return false
	if float(readability.get("min_symbol_extent_fraction", 0.0)) < 0.33:
		_fail("Ninefold smoke: large-map %s marker is too small for tactical framing: %s." % [expected_kind, presentation])
		return false
	if remembered:
		if is_town:
			if bool(readability.get("memory_echo", false)) or String(readability.get("town_remembered_treatment", "")) != "ghosted_sprite_without_echo_plate":
				_fail("Ninefold smoke: remembered large-map town should use ghosted sprite treatment without the removed echo plate: %s." % presentation)
				return false
		elif not bool(readability.get("memory_echo", false)) or float(readability.get("remembered_marker_alpha", 0.0)) < 0.80:
			_fail("Ninefold smoke: remembered large-map %s marker is too faint: %s." % [expected_kind, presentation])
			return false
	else:
		var visible_grid_suppressed := String(readability.get("visible_terrain_grid_mode", "")) == "fog_boundary_only" and float(readability.get("grid_alpha", 1.0)) <= 0.08 and not bool(readability.get("explored_intertile_seams", true))
		var anchor_floor := 0.12 if uses_mapped_sprite else (0.16 if uses_procedural_fallback else 0.30)
		if bool(readability.get("memory_echo", false)) or (not is_town and (float(readability.get("anchor_alpha", 0.0)) < anchor_floor or float(readability.get("outline_alpha", 0.0)) < 0.85 or not visible_grid_suppressed)):
			_fail("Ninefold smoke: visible large-map %s marker grounding or map contrast regressed: %s." % [expected_kind, presentation])
			return false
	return true

func _assert_procedural_fallback_grounding(readability: Dictionary, expected_kind: String, presentation: Dictionary) -> bool:
	if String(readability.get("anchor_shape", "")) != "family_terrain_contact_scuffs":
		_fail("Ninefold smoke: procedural large-map %s fallback still reports the old terrain-ellipse marker anchor: %s." % [expected_kind, presentation])
		return false
	if not bool(readability.get("procedural_fallback_grounding", false)) or String(readability.get("procedural_grounding_model", "")) != "family_specific_contact_scuffs_no_marker_plate":
		_fail("Ninefold smoke: procedural large-map %s fallback does not expose the contact-scuff grounding model: %s." % [expected_kind, presentation])
		return false
	if bool(readability.get("contrast_plate", true)) or bool(readability.get("shared_marker_plate", true)) or float(readability.get("plate_alpha", 1.0)) > 0.01 or float(readability.get("ring_alpha", 1.0)) > 0.01:
		_fail("Ninefold smoke: procedural large-map %s fallback still exposes the shared marker plate or ring: %s." % [expected_kind, presentation])
		return false
	if bool(readability.get("terrain_quieting_bed", true)) or String(readability.get("placement_bed_model", "")) != "" or float(readability.get("placement_bed_alpha", 1.0)) > 0.01:
		_fail("Ninefold smoke: procedural large-map %s fallback still reports the broad terrain quieting bed: %s." % [expected_kind, presentation])
		return false
	if not bool(readability.get("procedural_contact_disturbance", false)) or String(readability.get("procedural_contact_disturbance_model", "")) != "thin_terrain_contact_disturbance":
		_fail("Ninefold smoke: procedural large-map %s fallback lacks the thin terrain contact disturbance: %s." % [expected_kind, presentation])
		return false
	if float(readability.get("procedural_contact_disturbance_alpha", 0.0)) < 0.16 or float(readability.get("procedural_contact_disturbance_alpha", 1.0)) > 0.24:
		_fail("Ninefold smoke: procedural large-map %s fallback contact disturbance alpha is outside range: %s." % [expected_kind, presentation])
		return false
	if bool(readability.get("upper_mass_backdrop", true)) or String(readability.get("upper_mass_backdrop_model", "")) != "" or bool(readability.get("vertical_mass_shadow", true)):
		_fail("Ninefold smoke: procedural large-map %s fallback still reports upper-mass backdrop/shadow support: %s." % [expected_kind, presentation])
		return false
	if bool(readability.get("foreground_occlusion_lip", true)) or not bool(readability.get("procedural_contact_marks", false)):
		_fail("Ninefold smoke: procedural large-map %s fallback still reports the foreground lip instead of contact marks: %s." % [expected_kind, presentation])
		return false
	if String(readability.get("depth_cue_model", "")) != "localized_contact_shadow_without_backdrop":
		_fail("Ninefold smoke: procedural large-map %s fallback does not report localized contact-shadow depth: %s." % [expected_kind, presentation])
		return false
	if bool(readability.get("directional_contact_shadow", true)) or not bool(readability.get("localized_contact_shadow", false)) or String(readability.get("contact_shadow_model", "")) != "localized_object_contact_shadow":
		_fail("Ninefold smoke: procedural large-map %s fallback still reports the shared directional cast shadow: %s." % [expected_kind, presentation])
		return false
	if float(readability.get("contact_shadow_alpha", 0.0)) < 0.24 or bool(readability.get("base_occlusion_pads", true)) or float(readability.get("base_occlusion_alpha", 1.0)) > 0.01:
		_fail("Ninefold smoke: procedural large-map %s fallback lacks localized contact shadow or still reports base occlusion pads: %s." % [expected_kind, presentation])
		return false
	return true

func _assert_town_grounding_correction(readability: Dictionary, presentation: Dictionary) -> bool:
	if String(readability.get("anchor_shape", "")) != "town_contact_cues_no_base_ellipse":
		_fail("Ninefold smoke: large-map town still reports a base ellipse anchor: %s." % presentation)
		return false
	if bool(readability.get("terrain_quieting_bed", true)) or String(readability.get("placement_bed_model", "")) != "" or float(readability.get("placement_bed_alpha", 1.0)) > 0.01:
		_fail("Ninefold smoke: large-map town still reports a filled terrain underlay/quieting bed: %s." % presentation)
		return false
	if bool(readability.get("upper_mass_backdrop", true)) or bool(readability.get("vertical_mass_shadow", true)):
		_fail("Ninefold smoke: large-map town still reports upper-mass shadow/backdrop treatment: %s." % presentation)
		return false
	if String(readability.get("depth_cue_model", "")) != "town_contact_line_without_cast_shadow" or bool(readability.get("directional_contact_shadow", true)) or float(readability.get("contact_shadow_alpha", 1.0)) > 0.01:
		_fail("Ninefold smoke: large-map town still reports directional cast-shadow depth cues: %s." % presentation)
		return false
	if bool(readability.get("base_occlusion_pads", true)) or float(readability.get("base_occlusion_alpha", 1.0)) > 0.01:
		_fail("Ninefold smoke: large-map town still reports foreground base occlusion pads: %s." % presentation)
		return false
	if String(readability.get("town_grounding_model", "")) != "town_sprite_settled_without_base_ellipse" or String(readability.get("town_footprint_cue_model", "")) != "no_visible_helper_cues_3x2_contract":
		_fail("Ninefold smoke: large-map town grounding metadata does not describe the no-ellipse presentation: %s." % presentation)
		return false
	if bool(readability.get("town_base_ellipse", true)) or bool(readability.get("town_underlay", true)) or bool(readability.get("town_cast_shadow", true)) or not bool(readability.get("town_contact_cue", false)):
		_fail("Ninefold smoke: large-map town grounding flags did not remove base ellipse/underlay/cast shadow while preserving contact cues: %s." % presentation)
		return false
	var town_presentation: Dictionary = presentation.get("town_presentation", {})
	if bool(town_presentation.get("base_ellipse", true)) or bool(town_presentation.get("filled_underlay", true)) or bool(town_presentation.get("cast_shadow", true)):
		_fail("Ninefold smoke: large-map town presentation payload still exposes the removed ellipse/underlay/shadow treatment: %s." % presentation)
		return false
	if String(town_presentation.get("footprint_cue_model", "")) != "no_visible_helper_cues_3x2_contract":
		_fail("Ninefold smoke: large-map town footprint cue metadata does not describe the cue-free 3x2 contract: %s." % presentation)
		return false
	if bool(town_presentation.get("visible_helper_cues", true)) or bool(town_presentation.get("footprint_helper_glyphs", true)) or bool(town_presentation.get("entry_apron_cue", true)) or bool(town_presentation.get("entry_wedge_cue", true)) or bool(town_presentation.get("gate_cue", true)) or bool(town_presentation.get("helper_circle_cue", true)):
		_fail("Ninefold smoke: large-map town presentation payload still exposes visible helper footprint/entry cues: %s." % presentation)
		return false
	return true

func _assert_hero_presence_correction(readability: Dictionary, presentation: Dictionary) -> bool:
	if String(readability.get("hero_presence_model", "")) != "placed_world_hero_figure":
		_fail("Ninefold smoke: active hero does not report the placed world-figure presence model: %s." % presentation)
		return false
	if String(readability.get("hero_anchor_shape", "")) != "hero_foot_contact_shadow" or String(readability.get("hero_grounding_model", "")) != "hero_foot_contact_without_base_ellipse":
		_fail("Ninefold smoke: active hero still lacks the hero-specific foot-contact grounding model: %s." % presentation)
		return false
	if String(readability.get("hero_depth_cue_model", "")) != "hero_foot_contact_shadow_with_boot_occlusion":
		_fail("Ninefold smoke: active hero does not report boot-level depth/occlusion contact: %s." % presentation)
		return false
	if bool(readability.get("hero_badge_plate", true)) or bool(readability.get("hero_base_ellipse", true)) or bool(readability.get("hero_terrain_quieting_bed", true)) or bool(readability.get("hero_upper_mass_backdrop", true)) or bool(readability.get("hero_shared_marker_plate", true)):
		_fail("Ninefold smoke: active hero regressed toward the staged badge/ellipse support: %s." % presentation)
		return false
	if not bool(readability.get("hero_world_figure", false)) or not bool(readability.get("hero_foot_contact_shadow", false)) or not bool(readability.get("hero_boot_occlusion", false)):
		_fail("Ninefold smoke: active hero lacks world-figure, foot-shadow, or boot-occlusion cues: %s." % presentation)
		return false
	if float(readability.get("hero_contact_shadow_alpha", 0.0)) < 0.30 or float(readability.get("hero_boot_occlusion_alpha", 0.0)) < 0.34:
		_fail("Ninefold smoke: active hero foot-contact depth cues are too faint: %s." % presentation)
		return false
	if float(readability.get("hero_foot_anchor_width_fraction", 0.0)) < 0.50 or float(readability.get("hero_foot_anchor_height_fraction", 0.0)) < 0.12:
		_fail("Ninefold smoke: active hero foot-contact anchor is too small for the large-map tactical view: %s." % presentation)
		return false
	if String(readability.get("hero_selection_ring_source", "")) != "tile_focus":
		_fail("Ninefold smoke: active hero selection readability is no longer tied to the tile focus ring: %s." % presentation)
		return false
	return true

func _assert_town_footprint_profile(shell: Node, entry_presentation: Dictionary) -> bool:
	var profiles: Array = shell.call("validation_town_presentation_profiles")
	var matching_profile := {}
	for profile_value in profiles:
		if not (profile_value is Dictionary):
			continue
		var profile: Dictionary = profile_value
		if String(profile.get("town_placement_id", "")) == "ninefold_embercourt_survey_camp":
			matching_profile = profile
			break
	if matching_profile.is_empty():
		_fail("Ninefold smoke: town presentation profiles did not include the starting survey camp: %s." % profiles)
		return false
	if int(matching_profile.get("footprint_width_tiles", 0)) != 3 or int(matching_profile.get("footprint_height_tiles", 0)) != 2:
		_fail("Ninefold smoke: starting town profile is not a 3x2 footprint: %s." % matching_profile)
		return false
	if int(matching_profile.get("blocked_footprint_cell_count", 0)) != 5 or int(matching_profile.get("off_map_footprint_cell_count", 0)) != 0:
		_fail("Ninefold smoke: in-bounds starting town should expose five blocked non-entry footprint cells: %s." % matching_profile)
		return false
	var entry_tile: Dictionary = matching_profile.get("entry_tile", {})
	if int(entry_tile.get("x", -1)) != 23 or int(entry_tile.get("y", -1)) != 26:
		_fail("Ninefold smoke: starting town entry tile moved away from the actual visit tile: %s." % matching_profile)
		return false
	var blocked_cells: Array = matching_profile.get("blocked_footprint_cells", [])
	if blocked_cells.is_empty():
		_fail("Ninefold smoke: starting town profile did not expose blocked non-entry cells: %s." % matching_profile)
		return false
	var first_blocked: Dictionary = blocked_cells[0]
	var blocked_presentation: Dictionary = shell.call("validation_tile_presentation", int(first_blocked.get("x", -1)), int(first_blocked.get("y", -1)))
	var blocked_town: Dictionary = blocked_presentation.get("town_presentation", {})
	if not bool(blocked_presentation.get("has_town_non_entry", false)) or bool(blocked_town.get("is_visit_tile", true)):
		_fail("Ninefold smoke: blocked town footprint tile did not read as non-entry: cell=%s presentation=%s." % [first_blocked, blocked_presentation])
		return false
	if not bool(blocked_town.get("presentation_blocked", false)) or String(blocked_town.get("tile_role", "")) != "blocked_non_entry_footprint":
		_fail("Ninefold smoke: blocked town footprint tile is not presentation-blocked: cell=%s presentation=%s." % [first_blocked, blocked_presentation])
		return false
	var entry_town: Dictionary = entry_presentation.get("town_presentation", {})
	if int(entry_town.get("blocked_footprint_cell_count", 0)) != 5:
		_fail("Ninefold smoke: entry tile did not expose the complete blocked-cell footprint: %s." % entry_presentation)
		return false
	return true

func _assert_mapped_sprite_grounding(readability: Dictionary, label: String, presentation: Dictionary) -> bool:
	if String(readability.get("anchor_shape", "")) != "mapped_sprite_local_contact_scuffs" or not bool(readability.get("mapped_sprite_grounding", false)):
		_fail("Ninefold smoke: large-map mapped %s sprite does not report the local contact-scuff anchor: %s." % [label, presentation])
		return false
	if String(readability.get("mapped_sprite_grounding_model", "")) != "localized_sprite_contact_scuffs" or not bool(readability.get("mapped_sprite_contact_disturbance", false)):
		_fail("Ninefold smoke: large-map mapped %s sprite lacks localized contact scuffs: %s." % [label, presentation])
		return false
	if String(readability.get("mapped_sprite_contact_disturbance_model", "")) != "thin_sprite_contact_disturbance" or float(readability.get("mapped_sprite_contact_disturbance_alpha", 0.0)) < 0.12:
		_fail("Ninefold smoke: large-map mapped %s sprite contact scuffs are missing or too faint: %s." % [label, presentation])
		return false
	if bool(readability.get("terrain_quieting_bed", true)) or String(readability.get("placement_bed_model", "")) != "" or float(readability.get("placement_bed_alpha", 1.0)) > 0.01:
		_fail("Ninefold smoke: large-map mapped %s sprite still reports a broad placement bed: %s." % [label, presentation])
		return false
	if bool(readability.get("upper_mass_backdrop", true)) or String(readability.get("upper_mass_backdrop_model", "")) != "" or bool(readability.get("vertical_mass_shadow", true)):
		_fail("Ninefold smoke: large-map mapped %s sprite still reports upper-mass backdrop or vertical shadow support: %s." % [label, presentation])
		return false
	if bool(readability.get("foreground_occlusion_lip", true)) or bool(readability.get("base_occlusion_pads", true)) or bool(readability.get("shared_marker_plate", true)):
		_fail("Ninefold smoke: large-map mapped %s sprite still reports foreground lip/base pads/shared marker plate: %s." % [label, presentation])
		return false
	if not bool(readability.get("localized_contact_shadow", false)) or String(readability.get("contact_shadow_model", "")) != "localized_sprite_contact_shadow" or float(readability.get("contact_shadow_alpha", 0.0)) < 0.22:
		_fail("Ninefold smoke: large-map mapped %s sprite lacks localized contact-shadow readability: %s." % [label, presentation])
		return false
	return true

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
