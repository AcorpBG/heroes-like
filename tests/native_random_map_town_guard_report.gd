extends Node

const REPORT_ID := "NATIVE_RANDOM_MAP_TOWN_GUARD_REPORT"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ClassDB.class_exists("MapPackageService"):
		_fail("MapPackageService native class is not available.")
		return

	var service: Variant = ClassDB.instantiate("MapPackageService")
	var metadata: Dictionary = service.get_api_metadata()
	if String(metadata.get("binding_kind", "")) != "native_gdextension" or not bool(metadata.get("native_extension_loaded", false)):
		_fail("Native GDExtension metadata did not prove native load: %s" % JSON.stringify(metadata))
		return

	var capabilities: PackedStringArray = service.get_capabilities()
	if not capabilities.has("native_random_map_town_guard_placement_foundation"):
		_fail("Native town/guard capability is missing: %s" % JSON.stringify(Array(capabilities)))
		return

	var config := {
		"seed": "native-rmg-town-guard-placement-10184",
		"size": {
			"width": 46,
			"height": 40,
			"level_count": 1,
			"size_class_id": "homm3_small",
			"water_mode": "islands",
		},
		"player_constraints": {
			"human_count": 1,
			"computer_count": 3,
			"team_mode": "free_for_all",
		},
		"profile": {
			"id": "native_town_guard_profile",
			"template_id": "native_foundation_spoke",
			"terrain_ids": ["grass", "dirt", "rough", "snow", "underground"],
			"faction_ids": ["faction_embercourt", "faction_mireclaw", "faction_sunvault", "faction_thornwake"],
		},
	}
	var changed_seed_config := config.duplicate(true)
	changed_seed_config["seed"] = "native-rmg-town-guard-placement-10184-changed"

	var first: Dictionary = service.generate_random_map(config)
	var second: Dictionary = service.generate_random_map(config.duplicate(true))
	var changed: Dictionary = service.generate_random_map(changed_seed_config)

	_assert_town_guard_shape(first, 46, 40)
	_assert_town_guard_shape(second, 46, 40)
	_assert_town_guard_shape(changed, 46, 40)

	var first_payload: Dictionary = first.get("town_guard_placement", {})
	var second_payload: Dictionary = second.get("town_guard_placement", {})
	var changed_payload: Dictionary = changed.get("town_guard_placement", {})
	var signature := String(first_payload.get("signature", ""))
	if signature == "":
		_fail("Town/guard placement signature is empty.")
		return
	if signature != String(second_payload.get("signature", "")):
		_fail("Same seed/config did not preserve town/guard signature.")
		return
	if signature == String(changed_payload.get("signature", "")):
		_fail("Changed seed did not change town/guard signature.")
		return
	if _town_guard_layout_signature(first_payload) == _town_guard_layout_signature(changed_payload):
		_fail("Changed seed did not change town/guard layout coordinates.")
		return

	var report: Dictionary = first.get("report", {})
	if String(first.get("town_generation_status", "")) != "towns_generated_foundation" or String(first.get("guard_generation_status", "")) != "guards_generated_foundation":
		_fail("Top-level town/guard generation statuses missing.")
		return
	if String(report.get("town_generation_status", "")) != "towns_generated_foundation" or String(report.get("guard_generation_status", "")) != "guards_generated_foundation":
		_fail("Report town/guard generation statuses missing: %s" % JSON.stringify(report))
		return
	if String(report.get("town_guard_placement_signature", "")) != signature:
		_fail("Report town/guard signature did not match payload.")
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"binding_kind": metadata.get("binding_kind", ""),
		"native_extension_loaded": metadata.get("native_extension_loaded", false),
		"status": first.get("status", ""),
		"full_generation_status": first.get("full_generation_status", ""),
		"town_generation_status": first.get("town_generation_status", ""),
		"guard_generation_status": first.get("guard_generation_status", ""),
		"town_count": first_payload.get("town_count", 0),
		"guard_count": first_payload.get("guard_count", 0),
		"town_guard_signature": signature,
		"changed_town_guard_signature": changed_payload.get("signature", ""),
		"occupancy_signature": first_payload.get("combined_occupancy_index", {}).get("signature", ""),
		"category_counts": first_payload.get("category_counts", {}),
	})])
	get_tree().quit(0)

func _assert_town_guard_shape(generated: Dictionary, expected_width: int, expected_height: int) -> void:
	if not bool(generated.get("ok", false)):
		_fail("Native RMG town/guard generation returned ok=false: %s" % JSON.stringify(generated))
		return
	if String(generated.get("status", "")) != "partial_foundation":
		_fail("Town/guard slice did not preserve partial_foundation status.")
		return
	if String(generated.get("full_generation_status", "")) != "not_implemented":
		_fail("Town/guard slice falsely implied full generation.")
		return
	if String(generated.get("town_generation_status", "")) != "towns_generated_foundation" or String(generated.get("guard_generation_status", "")) != "guards_generated_foundation":
		_fail("Town/guard statuses are missing.")
		return

	var payload: Dictionary = generated.get("town_guard_placement", {})
	if String(payload.get("schema_id", "")) != "aurelion_native_rmg_town_guard_placement_v1":
		_fail("Town/guard schema mismatch: %s" % JSON.stringify(payload))
		return
	if String(payload.get("materialization_state", "")) != "staged_town_guard_records_only_no_gameplay_adoption":
		_fail("Town/guard placement crossed the no-adoption boundary.")
		return

	var towns: Array = payload.get("town_records", [])
	var guards: Array = payload.get("guard_records", [])
	var objects: Array = generated.get("object_placements", [])
	var starts: Array = generated.get("player_starts", {}).get("starts", [])
	if towns.size() < starts.size() or guards.is_empty():
		_fail("Town/guard payload must include start towns and non-empty guards.")
		return
	if int(payload.get("town_count", 0)) != towns.size() or int(payload.get("guard_count", 0)) != guards.size():
		_fail("Town/guard counts did not match records.")
		return

	var town_by_player := {}
	var faction_ids := {}
	var zone_ids := {}
	for town in towns:
		if not (town is Dictionary):
			_fail("Non-dictionary town record.")
			return
		_assert_town_valid(town, expected_width, expected_height)
		if bool(town.get("is_start_town", false)):
			town_by_player[int(town.get("player_slot", 0))] = town
		faction_ids[String(town.get("faction_id", ""))] = true
		zone_ids[String(town.get("zone_id", ""))] = true
	for start in starts:
		if not (start is Dictionary):
			continue
		var player_slot := int(start.get("player_slot", 0))
		if not town_by_player.has(player_slot):
			_fail("Player start %d has no start town." % player_slot)
			return
		var town: Dictionary = town_by_player[player_slot]
		if String(town.get("town_id", "")) != String(start.get("town_id", "")) or String(town.get("faction_id", "")) != String(start.get("faction_id", "")):
			_fail("Start town does not preserve player faction/town assignment: %s vs %s" % [JSON.stringify(town), JSON.stringify(start)])
			return
	if faction_ids.size() < 3 or zone_ids.size() < 4:
		_fail("Town placement did not expose useful faction/zone spread.")
		return

	var object_ids := {}
	var route_ids := {}
	var guard_zones := {}
	for object in objects:
		if object is Dictionary:
			object_ids[String(object.get("placement_id", ""))] = true
	for edge in generated.get("route_graph", {}).get("edges", []):
		if edge is Dictionary:
			route_ids[String(edge.get("id", ""))] = true
	for guard in guards:
		if not (guard is Dictionary):
			_fail("Non-dictionary guard record.")
			return
		_assert_guard_valid(guard, expected_width, expected_height, object_ids, route_ids)
		guard_zones[String(guard.get("zone_id", ""))] = true
	if guard_zones.size() < 4:
		_fail("Guard placement did not preserve useful zone spread.")
		return

	var occupancy: Dictionary = payload.get("combined_occupancy_index", {})
	if String(occupancy.get("status", "")) != "pass" or int(occupancy.get("duplicate_primary_tile_count", -1)) != 0:
		_fail("Town/guard/object combined occupancy did not prove unique primary tiles: %s" % JSON.stringify(occupancy))
		return
	if int(occupancy.get("occupied_primary_tile_count", 0)) != objects.size() + towns.size() + guards.size():
		_fail("Combined primary occupancy count did not match objects + towns + guards.")
		return

func _assert_town_valid(town: Dictionary, width: int, height: int) -> void:
	var x := int(town.get("x", -1))
	var y := int(town.get("y", -1))
	if x < 0 or x >= width or y < 0 or y >= height or int(town.get("level", -1)) != 0:
		_fail("Town has invalid coordinates: %s" % JSON.stringify(town))
		return
	if String(town.get("placement_id", "")) == "" or String(town.get("town_id", "")) == "" or String(town.get("faction_id", "")) == "" or String(town.get("zone_id", "")) == "":
		_fail("Town missed identity fields: %s" % JSON.stringify(town))
		return
	if String(town.get("primary_occupancy_key", "")) == "" or String(town.get("signature", "")) == "":
		_fail("Town missed occupancy/signature fields: %s" % JSON.stringify(town))
		return
	if town.get("body_tiles", []).is_empty() or town.get("occupancy_keys", []).is_empty():
		_fail("Town missed footprint occupancy fields: %s" % JSON.stringify(town))
		return
	if String(town.get("road_proximity", {}).get("proximity_class", "")) == "":
		_fail("Town missed road proximity: %s" % JSON.stringify(town))
		return

func _assert_guard_valid(guard: Dictionary, width: int, height: int, object_ids: Dictionary, route_ids: Dictionary) -> void:
	var x := int(guard.get("x", -1))
	var y := int(guard.get("y", -1))
	if x < 0 or x >= width or y < 0 or y >= height or int(guard.get("level", -1)) != 0:
		_fail("Guard has invalid coordinates: %s" % JSON.stringify(guard))
		return
	if String(guard.get("guard_id", "")) == "" or String(guard.get("primary_occupancy_key", "")) == "" or String(guard.get("signature", "")) == "":
		_fail("Guard missed identity/occupancy/signature fields: %s" % JSON.stringify(guard))
		return
	if guard.get("stack_records", []).is_empty() or int(guard.get("stack_count", 0)) <= 0:
		_fail("Guard stack is empty: %s" % JSON.stringify(guard))
		return
	var target_type := String(guard.get("protected_target_type", ""))
	if target_type == "route_edge":
		if not route_ids.has(String(guard.get("route_edge_id", ""))):
			_fail("Route guard references invalid route edge: %s" % JSON.stringify(guard))
			return
	elif target_type == "object_placement":
		if not object_ids.has(String(guard.get("protected_object_placement_id", ""))):
			_fail("Site guard references invalid object placement: %s" % JSON.stringify(guard))
			return
	else:
		_fail("Guard has unsupported protected target type: %s" % JSON.stringify(guard))
		return
	if String(guard.get("protected_zone_id", "")) == "" or String(guard.get("zone_id", "")) == "":
		_fail("Guard missed zone references: %s" % JSON.stringify(guard))
		return
	if String(guard.get("road_proximity", {}).get("proximity_class", "")) == "":
		_fail("Guard missed road proximity: %s" % JSON.stringify(guard))
		return

func _town_guard_layout_signature(payload: Dictionary) -> String:
	var rows := []
	for town in payload.get("town_records", []):
		if town is Dictionary:
			rows.append("town:%s@%d,%d" % [String(town.get("placement_id", "")), int(town.get("x", 0)), int(town.get("y", 0))])
	for guard in payload.get("guard_records", []):
		if guard is Dictionary:
			rows.append("guard:%s@%d,%d" % [String(guard.get("placement_id", "")), int(guard.get("x", 0)), int(guard.get("y", 0))])
	rows.sort()
	return "|".join(rows)

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
