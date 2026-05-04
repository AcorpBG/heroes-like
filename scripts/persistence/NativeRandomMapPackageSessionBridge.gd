class_name NativeRandomMapPackageSessionBridge
extends RefCounted

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const HeroCommandRulesScript = preload("res://scripts/core/HeroCommandRules.gd")
const OverworldRulesScript = preload("res://scripts/core/OverworldRules.gd")

static func build_session_from_adoption(
	adoption: Dictionary,
	difficulty: String = "normal",
	options: Dictionary = {}
) -> SessionStateStoreScript.SessionData:
	if not bool(adoption.get("ok", false)):
		return SessionStateStoreScript.new_session_data()
	var boundary: Dictionary = adoption.get("session_boundary_record", {}) if adoption.get("session_boundary_record", {}) is Dictionary else {}
	if boundary.is_empty():
		return SessionStateStoreScript.new_session_data()

	var scenario_id := String(boundary.get("scenario_id", ""))
	var session_id := String(boundary.get("session_id", ""))
	var hero_id := String(boundary.get("hero_id", options.get("hero_id", "hero_lyra")))
	var map_ref: Dictionary = boundary.get("map_package_ref", {}) if boundary.get("map_package_ref", {}) is Dictionary else {}
	var scenario_ref: Dictionary = boundary.get("scenario_package_ref", {}) if boundary.get("scenario_package_ref", {}) is Dictionary else {}
	var report: Dictionary = adoption.get("report", {}) if adoption.get("report", {}) is Dictionary else {}
	var metrics: Dictionary = report.get("metrics", {}) if report.get("metrics", {}) is Dictionary else {}
	var start := _primary_start(adoption)
	var map_document: Variant = adoption.get("map_document", null)
	var scenario_document: Variant = adoption.get("scenario_document", null)
	var map_size := _map_size_from_document(map_document, metrics)
	var terrain_layers := _terrain_layers_from_document(map_document)
	var map_rows := _map_rows_from_document(map_document)
	var hero_id_from_doc := _primary_hero_id(scenario_document, hero_id)
	var hero_state := _hero_state(hero_id_from_doc, start, difficulty)
	var towns := _town_states_from_document(map_document)
	var resource_nodes := _resource_nodes_from_document(map_document)
	var map_objects := _decorative_objects_from_document(map_document)
	var overworld_state := {
		"map": map_rows,
		"map_size": map_size,
		"terrain_layers": terrain_layers,
		"active_hero_id": hero_id_from_doc,
		"player_heroes": [hero_state] if not hero_state.is_empty() else [],
		"hero_position": start,
		"hero": hero_state,
		"movement": hero_state.get("movement", {"current": 0, "max": 0}) if not hero_state.is_empty() else {"current": 0, "max": 0},
		"resources": {"gold": 5000, "wood": 10, "ore": 10},
		"army": hero_state.get("army", {}) if not hero_state.is_empty() else {},
		"encounters": [],
		"resolved_encounters": [],
		"towns": towns,
		"resource_nodes": resource_nodes,
		"map_objects": map_objects,
		"artifact_nodes": [],
		"enemy_states": _enemy_states_from_document(scenario_document),
		"map_package_ref": map_ref,
		"scenario_package_ref": scenario_ref,
		"native_random_map_package_session_adoption": boundary.duplicate(true),
		"generated_random_map_identity": adoption.get("generated_identity", {}),
		"generated_random_map_validation": adoption.get("validation_report", {}),
	}
	var session := SessionStateStoreScript.new_session_data(
		session_id,
		scenario_id,
		hero_id_from_doc,
		1,
		overworld_state,
		difficulty,
		SessionStateStoreScript.LAUNCH_MODE_SKIRMISH
	)
	session.save_version = SessionStateStoreScript.SAVE_VERSION
	session.game_state = "overworld"
	session.scenario_status = "in_progress"
	session.flags = {
		"native_random_map_package_session_adoption": true,
		"native_random_map_feature_gate": String(boundary.get("feature_gate", "")),
		"generated_random_map": true,
		"generated_random_map_source": "native_rmg_disk_package",
		"generated_random_map_boundary": {
			"authored_content_writeback": false,
			"campaign_adoption": false,
			"skirmish_browser_authored_listing": false,
			"runtime_call_site_adoption": true,
			"native_runtime_authoritative": bool(boundary.get("native_runtime_authoritative", false)),
			"full_parity_claim": bool(boundary.get("full_parity_claim", false)),
			"adoption_path": "native_rmg_generated_package_saved_loaded_from_disk",
			"content_service_generated_draft": false,
			"legacy_json_scenario_record": false,
		},
		"map_package_ref": map_ref,
		"scenario_package_ref": scenario_ref,
		"generated_random_map_provenance": adoption.get("provenance", {}),
		"generated_random_map_validation": adoption.get("validation_report", {}),
	}
	OverworldRulesScript.normalize_overworld_state(session)
	return session

static func build_session_from_loaded_packages(
	map_load: Dictionary,
	scenario_load: Dictionary,
	boundary: Dictionary,
	difficulty: String = "normal",
	options: Dictionary = {}
) -> SessionStateStoreScript.SessionData:
	if not bool(map_load.get("ok", false)) or not bool(scenario_load.get("ok", false)):
		return SessionStateStoreScript.new_session_data()
	var adoption := {
		"ok": true,
		"map_document": map_load.get("map_document", null),
		"scenario_document": scenario_load.get("scenario_document", null),
		"map_ref": map_load.get("map_ref", {}),
		"scenario_ref": scenario_load.get("scenario_ref", {}),
		"session_boundary_record": boundary.duplicate(true),
		"report": {
			"metrics": {
				"width": map_load.get("map_document", null).get_width() if map_load.get("map_document", null) != null else 0,
				"height": map_load.get("map_document", null).get_height() if map_load.get("map_document", null) != null else 0,
				"level_count": map_load.get("map_document", null).get_level_count() if map_load.get("map_document", null) != null else 1,
			},
		},
	}
	return build_session_from_adoption(adoption, difficulty, options)

static func _primary_start(adoption: Dictionary) -> Dictionary:
	var scenario_document: Variant = adoption.get("scenario_document", null)
	if scenario_document != null and scenario_document.has_method("get_start_contract"):
		var start_contract: Dictionary = scenario_document.get_start_contract()
		var starts: Array = start_contract.get("player_starts", []) if start_contract.get("player_starts", []) is Array else []
		if not starts.is_empty() and starts[0] is Dictionary:
			return {"x": int(starts[0].get("x", 0)), "y": int(starts[0].get("y", 0))}
	return {"x": 0, "y": 0}

static func _primary_hero_id(scenario_document: Variant, fallback: String) -> String:
	if scenario_document != null and scenario_document.has_method("get_start_contract"):
		var start_contract: Dictionary = scenario_document.get_start_contract()
		var hero_id := String(start_contract.get("primary_hero_id", ""))
		if hero_id != "":
			return hero_id
	return fallback if fallback != "" else "hero_lyra"

static func _hero_state(hero_id: String, start: Dictionary, difficulty: String) -> Dictionary:
	var hero_template := ContentService.get_hero(hero_id)
	var army_state := _army_state(ContentService.get_army_group("army_emberwell_vanguard"))
	var hero := HeroCommandRulesScript.build_hero_from_template(hero_template, start, army_state, difficulty)
	if not hero.is_empty():
		hero["is_primary"] = true
	return hero

static func _army_state(army_template: Dictionary) -> Dictionary:
	var stacks := []
	for stack in army_template.get("stacks", []):
		if stack is Dictionary:
			stacks.append({"unit_id": String(stack.get("unit_id", "")), "count": max(0, int(stack.get("count", 0)))})
	return {"id": String(army_template.get("id", "")), "name": String(army_template.get("name", "Field Army")), "stacks": stacks}

static func _map_size_from_document(map_document: Variant, metrics: Dictionary) -> Dictionary:
	var width := int(metrics.get("width", 0))
	var height := int(metrics.get("height", 0))
	var level_count := int(metrics.get("level_count", 1))
	if map_document != null:
		width = map_document.get_width()
		height = map_document.get_height()
		level_count = map_document.get_level_count()
	return {"width": width, "height": height, "x": width, "y": height, "level_count": level_count}

static func _terrain_layers_from_document(map_document: Variant) -> Dictionary:
	if map_document != null and map_document.has_method("get_terrain_layers"):
		var layers: Dictionary = map_document.get_terrain_layers()
		if not layers.is_empty():
			return layers
	return {}

static func _map_rows_from_document(map_document: Variant) -> Array:
	if map_document == null:
		return []
	var width := int(map_document.get_width())
	var height := int(map_document.get_height())
	var codes: PackedInt32Array = map_document.get_tile_layer_u16("terrain", 0)
	var layers := _terrain_layers_from_document(map_document)
	var ids_by_code: Variant = layers.get("terrain_id_by_code", [])
	var rows := []
	for y in range(height):
		var row := []
		for x in range(width):
			var index := y * width + x
			var code := int(codes[index]) if index >= 0 and index < codes.size() else 0
			row.append(_terrain_id_for_code(ids_by_code, code))
		rows.append(row)
	return rows

static func _terrain_id_for_code(ids_by_code: Variant, code: int) -> String:
	if (ids_by_code is Array or ids_by_code is PackedStringArray) and code >= 0 and code < ids_by_code.size():
		return String(ids_by_code[code])
	return "grass"

static func _document_objects(map_document: Variant) -> Array:
	var objects := []
	if map_document == null:
		return objects
	for index in range(int(map_document.get_object_count())):
		var object: Dictionary = map_document.get_object_by_index(index)
		if not object.is_empty():
			objects.append(object)
	return objects

static func _town_states_from_document(map_document: Variant) -> Array:
	var towns := []
	for object in _document_objects(map_document):
		if String(object.get("native_record_kind", object.get("kind", ""))) != "town" and String(object.get("kind", "")) != "town":
			continue
		var town_template := ContentService.get_town(String(object.get("town_id", "")))
		towns.append({
			"placement_id": String(object.get("placement_id", "")),
			"town_id": String(object.get("town_id", "")),
			"x": int(object.get("x", 0)),
			"y": int(object.get("y", 0)),
			"owner": String(object.get("owner", "neutral")),
			"built_buildings": town_template.get("starting_building_ids", []).duplicate(true) if town_template.get("starting_building_ids", []) is Array else [],
			"available_recruits": {},
			"garrison": town_template.get("garrison", []).duplicate(true) if town_template.get("garrison", []) is Array else [],
		})
	return towns

static func _resource_nodes_from_document(map_document: Variant) -> Array:
	var nodes := []
	for object in _document_objects(map_document):
		var kind := String(object.get("kind", ""))
		if not (kind in ["resource_site", "mine", "neutral_dwelling", "reward_reference"]):
			continue
		if String(object.get("site_id", "")) == "":
			continue
		var node: Dictionary = object.duplicate(true)
		node["collected"] = false
		nodes.append(node)
	return nodes

static func _decorative_objects_from_document(map_document: Variant) -> Array:
	var objects := []
	for object in _document_objects(map_document):
		var kind := String(object.get("kind", ""))
		var family := String(object.get("object_family_id", object.get("family_id", "")))
		if kind != "decorative_obstacle" and family != "decorative_obstacle":
			continue
		var node: Dictionary = object.duplicate(true)
		node["runtime_object_role"] = "decorative_blocker_sprite"
		node["collected"] = false
		objects.append(node)
	return objects

static func _enemy_states_from_document(scenario_document: Variant) -> Array:
	var enemies := []
	if scenario_document == null:
		return enemies
	for enemy in scenario_document.get_enemy_factions():
		if enemy is Dictionary:
			enemies.append(enemy.duplicate(true))
	return enemies
