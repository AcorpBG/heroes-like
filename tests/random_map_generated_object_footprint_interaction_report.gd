extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const OverworldMapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")

const REPORT_ID := "RANDOM_MAP_GENERATED_OBJECT_FOOTPRINT_INTERACTION_REPORT"
const SIZE_CLASS_ID := "homm3_small"
const EXPLICIT_SEED := "generated-footprint-interaction-10184"
const PRODUCER_FAMILIES := ["mine", "staged_resource_front", "support_producer"]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ContentService.clear_generated_scenario_drafts()
	SessionState.reset_session()

	var setup := ScenarioSelectRulesScript.build_random_map_skirmish_setup_with_retry(
		ScenarioSelectRulesScript.build_random_map_player_config(
			EXPLICIT_SEED,
			"border_gate_compact_v1",
			"border_gate_compact_profile_v1",
			3,
			"land",
			false,
			SIZE_CLASS_ID
		),
		"normal",
		ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY
	)
	if not bool(setup.get("ok", false)):
		_fail("Generated Small setup failed: %s" % JSON.stringify(setup))
		return
	var session = ScenarioSelectRulesScript.start_random_map_skirmish_session_from_setup(setup)
	if session == null or session.scenario_id == "":
		_fail("Generated Small session did not start from setup: %s" % JSON.stringify(setup))
		return
	OverworldRules.normalize_overworld_state(session)

	var records := []
	var failures := []
	var pickup_record := {}
	var dwelling_record := {}
	var sawmill_record := {}
	var producer_records := []
	var producer_route_proofs := []
	var generated_producer_families := {}
	for node_value in session.overworld.get("resource_nodes", []):
		if not (node_value is Dictionary):
			continue
		var record := _inspect_resource_node(session, node_value)
		records.append(record)
		failures.append_array(record.get("failures", []))
		var site_id := String(record.get("site_id", ""))
		var family := String(record.get("family", ""))
		if family in PRODUCER_FAMILIES:
			producer_records.append(record)
			generated_producer_families[family] = true
		if pickup_record.is_empty() and family == "pickup":
			pickup_record = record
		if dwelling_record.is_empty() and family == "neutral_dwelling":
			dwelling_record = record
		if site_id == "site_brightwood_sawmill":
			sawmill_record = record

	if pickup_record.is_empty():
		failures.append("Generated Small produced no pickup resource record to validate.")
	if dwelling_record.is_empty():
		failures.append("Generated Small produced no neutral dwelling record to validate.")
	if sawmill_record.is_empty():
		failures.append("Generated Small produced no Brightwood Sawmill record to validate.")
	elif not bool(sawmill_record.get("authored_runtime_contract", false)):
		failures.append("Generated sawmill did not use the authored runtime footprint/body/visit contract: %s" % JSON.stringify(sawmill_record))
	if producer_records.is_empty():
		failures.append("Generated Small produced no mine/resource producer records to validate.")
	for record in producer_records:
		var route_proof := _prove_interaction(session, record)
		producer_route_proofs.append(route_proof)
		if not bool(route_proof.get("ok", false)):
			failures.append("Generated producer interaction proof failed: %s" % JSON.stringify(route_proof))

	var pickup_interaction := _prove_interaction(session, pickup_record)
	if not bool(pickup_interaction.get("ok", false)):
		failures.append("Generated pickup interaction proof failed: %s" % JSON.stringify(pickup_interaction))
	var dwelling_interaction := _prove_interaction(session, dwelling_record)
	if not bool(dwelling_interaction.get("ok", false)):
		failures.append("Generated dwelling interaction proof failed: %s" % JSON.stringify(dwelling_interaction))
	var object_list_coverage := _prove_object_list_producer_families()
	if not bool(object_list_coverage.get("ok", false)):
		failures.append("Object-list producer family coverage failed: %s" % JSON.stringify(object_list_coverage))

	if not failures.is_empty():
		_fail("Generated object footprint/interaction report failed: %s" % JSON.stringify(failures))
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"scenario_id": session.scenario_id,
		"seed": EXPLICIT_SEED,
		"materialized_signature": String(setup.get("generated_identity", {}).get("materialized_map_signature", "")),
		"resource_node_count": records.size(),
		"pickup_interaction": pickup_interaction,
		"dwelling_interaction": dwelling_interaction,
		"producer_interactions": producer_route_proofs,
		"generated_producer_families": _sorted_keys(generated_producer_families),
		"object_list_producer_family_coverage": object_list_coverage,
		"sawmill_contract": sawmill_record,
		"sample_records": _compact_records(records, 8),
	})])
	ContentService.clear_generated_scenario_drafts()
	get_tree().quit(0)

func _inspect_resource_node(session, node: Dictionary) -> Dictionary:
	var site := ContentService.get_resource_site(String(node.get("site_id", "")))
	var map_object := ContentService.get_map_object(String(node.get("object_id", "")))
	if map_object.is_empty():
		map_object = ContentService.get_map_object_for_resource_site(String(node.get("site_id", "")))
	var surface := OverworldRules.overworld_object_placement_pathing_surface(session, String(node.get("placement_id", "")))
	var interaction_tiles: Array = surface.get("interaction_tiles", []) if surface.get("interaction_tiles", []) is Array else []
	var body_tiles: Array = surface.get("body_tiles", []) if surface.get("body_tiles", []) is Array else []
	var failures := []
	if int(surface.get("interaction_tile_count", 0)) != 1:
		failures.append("%s has %d interaction tiles." % [String(node.get("placement_id", "")), int(surface.get("interaction_tile_count", 0))])
	var interaction_tile: Dictionary = interaction_tiles[0] if not interaction_tiles.is_empty() and interaction_tiles[0] is Dictionary else {}
	if interaction_tile.is_empty():
		failures.append("%s has no concrete interaction tile." % String(node.get("placement_id", "")))
	elif OverworldRules.tile_is_blocked(session, int(interaction_tile.get("x", 0)), int(interaction_tile.get("y", 0))):
		failures.append("%s interaction tile is blocked: %s." % [String(node.get("placement_id", "")), JSON.stringify(interaction_tile)])
	if bool(surface.get("blocks_body_tiles", false)) and _tile_in_array(body_tiles, interaction_tile):
		failures.append("%s interaction tile overlaps body tiles: %s." % [String(node.get("placement_id", "")), JSON.stringify(surface)])

	var family := String(map_object.get("family", site.get("family", "pickup")))
	if family == "":
		family = "pickup"
	var node_tile := {"x": int(node.get("x", 0)), "y": int(node.get("y", 0))}
	var passability_class := String(map_object.get("passability_class", ""))
	if family == "pickup" or passability_class == "passable_visit_on_enter":
		if OverworldRules.tile_is_blocked(session, int(node_tile.get("x", 0)), int(node_tile.get("y", 0))):
			failures.append("%s pickup/enter tile is blocked: %s." % [String(node.get("placement_id", "")), JSON.stringify(node_tile)])

	var authored_footprint: Dictionary = map_object.get("footprint", {}) if map_object.get("footprint", {}) is Dictionary else {}
	var runtime_footprint: Dictionary = node.get("runtime_footprint", {}) if node.get("runtime_footprint", {}) is Dictionary else {}
	var authored_area: int = max(1, int(authored_footprint.get("width", 1))) * max(1, int(authored_footprint.get("height", 1)))
	var runtime_area: int = max(1, int(runtime_footprint.get("width", authored_footprint.get("width", 1)))) * max(1, int(runtime_footprint.get("height", authored_footprint.get("height", 1))))
	var authored_body_tiles: Array = map_object.get("body_tiles", []) if map_object.get("body_tiles", []) is Array else []
	var footprint_deferred: Dictionary = node.get("footprint_deferred", {}) if node.get("footprint_deferred", {}) is Dictionary else {}
	var authored_runtime_contract := true
	if family in PRODUCER_FAMILIES:
		var has_runtime_contract: bool = node.get("object_footprint_catalog_ref", {}) is Dictionary and not node.get("object_footprint_catalog_ref", {}).is_empty()
		authored_runtime_contract = runtime_area == authored_area and footprint_deferred.is_empty()
		if has_runtime_contract:
			authored_runtime_contract = (
				authored_runtime_contract
				and bool(surface.get("uses_runtime_body_tiles", false))
				and bool(surface.get("uses_runtime_visit_tile", false))
				and int(surface.get("body_tile_count", 0)) == 1
				and not bool(_tile_in_array(body_tiles, interaction_tile))
			)
		else:
			authored_runtime_contract = (
				authored_runtime_contract
				and int(surface.get("body_tile_count", 0)) == authored_body_tiles.size()
				and bool(surface.get("uses_authored_body_tiles", false))
				and bool(surface.get("uses_authored_approach", false))
			)
		if not authored_runtime_contract:
			failures.append("%s producer runtime contract does not match authored object list footprint/body/visit data: %s." % [String(node.get("placement_id", "")), JSON.stringify(surface)])
	return {
		"placement_id": String(node.get("placement_id", "")),
		"site_id": String(node.get("site_id", "")),
		"object_id": String(map_object.get("id", "")),
		"family": family,
		"node_tile": node_tile,
		"body_tile_count": int(surface.get("body_tile_count", 0)),
		"interaction_tile_count": int(surface.get("interaction_tile_count", 0)),
		"interaction_tile": interaction_tile,
		"interaction_tile_blocked": (not interaction_tile.is_empty()) and OverworldRules.tile_is_blocked(session, int(interaction_tile.get("x", 0)), int(interaction_tile.get("y", 0))),
		"body_overlaps_interaction": _tile_in_array(body_tiles, interaction_tile),
		"blocks_body_tiles": bool(surface.get("blocks_body_tiles", false)),
		"uses_runtime_body_tiles": bool(surface.get("uses_runtime_body_tiles", false)),
		"uses_runtime_visit_tile": bool(surface.get("uses_runtime_visit_tile", false)),
		"authored_footprint": authored_footprint,
		"runtime_footprint": runtime_footprint,
		"authored_area": authored_area,
		"runtime_area": runtime_area,
		"authored_body_tile_count": authored_body_tiles.size(),
		"authored_runtime_contract": authored_runtime_contract,
		"failures": failures,
	}

func _prove_interaction(session, record: Dictionary) -> Dictionary:
	if record.is_empty():
		return {"ok": false, "reason": "missing_record"}
	var interaction_tile: Dictionary = record.get("interaction_tile", {}) if record.get("interaction_tile", {}) is Dictionary else {}
	if interaction_tile.is_empty():
		return {"ok": false, "reason": "missing_interaction_tile", "record": record}
	var target := Vector2i(int(interaction_tile.get("x", 0)), int(interaction_tile.get("y", 0)))
	var start := _open_neighbor(session, target)
	if start == target:
		return {"ok": false, "reason": "no_open_neighbor", "target": interaction_tile, "record": record}
	_set_active_hero_position(session, start)
	session.overworld["movement"] = {"current": 8, "max": 8}
	OverworldRules.normalize_overworld_state(session)
	var move_result: Dictionary = OverworldRules.try_move(session, target.x - start.x, target.y - start.y)
	var node := _resource_node(session, String(record.get("placement_id", "")))
	var claimed := String(node.get("collected_by_faction_id", "")) == "player"
	return {
		"ok": bool(move_result.get("ok", false)) and claimed,
		"placement_id": String(record.get("placement_id", "")),
		"site_id": String(record.get("site_id", "")),
		"family": String(record.get("family", "")),
		"start": {"x": start.x, "y": start.y},
		"target": interaction_tile,
		"move_result": move_result,
		"claimed_by": String(node.get("collected_by_faction_id", "")),
	}

func _open_neighbor(session, target: Vector2i) -> Vector2i:
	for offset in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
		var candidate: Vector2i = target + offset
		if not OverworldRules.tile_is_blocked(session, candidate.x, candidate.y):
			return candidate
	return target

func _resource_node(session, placement_id: String) -> Dictionary:
	for node_value in session.overworld.get("resource_nodes", []):
		if node_value is Dictionary and String(node_value.get("placement_id", "")) == placement_id:
			return node_value
	return {}

func _set_active_hero_position(session, tile: Vector2i) -> void:
	var position := {"x": tile.x, "y": tile.y}
	session.overworld["hero_position"] = position.duplicate(true)
	var active_hero = session.overworld.get("hero", {})
	if active_hero is Dictionary:
		active_hero["position"] = position.duplicate(true)
		session.overworld["hero"] = active_hero
	var heroes: Array = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and bool(heroes[index].get("is_active", false)):
			var hero: Dictionary = heroes[index]
			hero["position"] = position.duplicate(true)
			heroes[index] = hero
	session.overworld["player_heroes"] = heroes

func _prove_object_list_producer_families() -> Dictionary:
	var session: SessionStateStore.SessionData = _producer_fixture_session()
	var view = OverworldMapViewScript.new()
	view.size = Vector2(960, 640)
	add_child(view)
	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), Vector2i(5, 5))
	var failures := []
	var families := {}
	var records := []
	for node_value in session.overworld.get("resource_nodes", []):
		if not (node_value is Dictionary):
			continue
		var node: Dictionary = node_value
		var record := _inspect_resource_node(session, node)
		var family := String(record.get("family", ""))
		families[family] = true
		var anchor := Vector2i(int(node.get("x", 0)), int(node.get("y", 0)))
		var presentation: Dictionary = view.validation_tile_presentation(anchor)
		var readability: Dictionary = presentation.get("marker_readability", {}) if presentation.get("marker_readability", {}) is Dictionary else {}
		var rendered_width := int(readability.get("footprint_width_tiles", 0))
		var rendered_height := int(readability.get("footprint_height_tiles", 0))
		var authored_footprint: Dictionary = record.get("authored_footprint", {}) if record.get("authored_footprint", {}) is Dictionary else {}
		if rendered_width != int(authored_footprint.get("width", 1)) or rendered_height != int(authored_footprint.get("height", 1)):
			failures.append("%s rendered footprint %dx%d did not match authored %s." % [
				String(record.get("object_id", "")),
				rendered_width,
				rendered_height,
				JSON.stringify(authored_footprint),
			])
		failures.append_array(record.get("failures", []))
		records.append({
			"object_id": String(record.get("object_id", "")),
			"family": family,
			"authored_footprint": authored_footprint,
			"rendered_footprint": {"width": rendered_width, "height": rendered_height},
			"body_tile_count": int(record.get("body_tile_count", 0)),
			"interaction_tile": record.get("interaction_tile", {}),
		})
	remove_child(view)
	view.queue_free()
	for required_family in PRODUCER_FAMILIES:
		if not families.has(required_family):
			failures.append("Producer fixture missed family %s." % required_family)
	return {
		"ok": failures.is_empty(),
		"families": _sorted_keys(families),
		"records": records,
		"failures": failures,
	}

func _producer_fixture_session():
	var width := 24
	var height := 18
	var rows := []
	for _y in range(height):
		var row := []
		for _x in range(width):
			row.append("grass")
		rows.append(row)
	var nodes := [
		{"placement_id": "fixture_brightwood_sawmill", "site_id": "site_brightwood_sawmill", "object_id": "object_brightwood_sawmill", "x": 5, "y": 5, "collected": false},
		{"placement_id": "fixture_ridge_quarry", "site_id": "site_ridge_quarry", "object_id": "object_ridge_quarry", "x": 11, "y": 5, "collected": false},
		{"placement_id": "fixture_peatwax_reed_yard", "site_id": "site_peatwax_reed_yard", "object_id": "object_peatwax_reed_yard", "x": 5, "y": 12, "collected": false},
		{"placement_id": "fixture_saw_chain", "site_id": "site_saw_chain", "object_id": "object_saw_chain", "x": 13, "y": 12, "collected": false},
	]
	var session = SessionStateStore.SessionData.new("producer_fixture", "producer_fixture", "hero_lyra", 1, {
		"map": rows,
		"map_size": {"width": width, "height": height},
		"hero_position": {"x": 1, "y": 1},
		"player_heroes": [{"hero_id": "hero_lyra", "x": 1, "y": 1, "is_active": true}],
		"movement": {"current": 99, "max": 99},
		"resource_nodes": nodes,
		"artifact_nodes": [],
		"encounters": [],
		"towns": [],
		"resolved_encounters": [],
		"fog": _all_visible_fog(width, height),
	})
	session.game_state = "overworld"
	session.overworld["fog"] = _all_visible_fog(width, height)
	return session

func _all_visible_fog(width: int, height: int) -> Dictionary:
	var visible := []
	var explored := []
	for _y in range(height):
		var row_visible := []
		var row_explored := []
		for _x in range(width):
			row_visible.append(true)
			row_explored.append(true)
		visible.append(row_visible)
		explored.append(row_explored)
	return {
		"visible_tiles": visible,
		"explored_tiles": explored,
		"visible_count": width * height,
		"explored_count": width * height,
		"total_tiles": width * height,
	}

func _sorted_keys(values: Dictionary) -> Array:
	var keys := []
	for key in values.keys():
		keys.append(String(key))
	keys.sort()
	return keys

func _tile_in_array(tiles: Array, tile: Dictionary) -> bool:
	if tile.is_empty():
		return false
	for value in tiles:
		if not (value is Dictionary):
			continue
		if int(value.get("x", -999)) == int(tile.get("x", -998)) and int(value.get("y", -999)) == int(tile.get("y", -998)):
			return true
	return false

func _compact_records(records: Array, limit: int) -> Array:
	var result := []
	for record in records:
		if result.size() >= limit:
			break
		if record is Dictionary:
			var compact: Dictionary = record.duplicate(true)
			compact.erase("failures")
			result.append(compact)
	return result

func _fail(message: String) -> void:
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message})])
	ContentService.clear_generated_scenario_drafts()
	get_tree().quit(1)
