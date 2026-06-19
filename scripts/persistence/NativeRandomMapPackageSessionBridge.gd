class_name NativeRandomMapPackageSessionBridge
extends RefCounted

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const HeroCommandRulesScript = preload("res://scripts/core/HeroCommandRules.gd")
const OverworldRulesScript = preload("res://scripts/core/OverworldRules.gd")

const GENERATED_TOWN_COMMON_SOURCE_SITE_BY_RESOURCE := {
	"wood": {"site_id": "site_brightwood_sawmill", "object_id": "object_brightwood_sawmill"},
	"ore": {"site_id": "site_ridge_quarry", "object_id": "object_ridge_quarry"},
}
const GENERATED_TOWN_RARE_SOURCE_SITE_BY_RESOURCE := {
	"aetherglass": "site_aetherglass_lens_house",
	"embergrain": "site_embergrain_warm_granary",
	"peatwax": "site_peatwax_reed_yard",
	"verdant_grafts": "site_verdant_graft_nursery",
	"brass_scrip": "site_brass_scrip_mint",
	"memory_salt": "site_memory_salt_pan",
}
const GENERATED_TOWN_REQUIRED_SOURCE_SITE_ID := "site_generated_town_required_source_cache"
const H3M_TOWN_TYPE_PROJECT_IDENTITY := {
	"castle": {"faction_id": "faction_embercourt", "town_id": "town_riverwatch"},
	"rampart": {"faction_id": "faction_mireclaw", "town_id": "town_duskfen"},
	"tower": {"faction_id": "faction_sunvault", "town_id": "town_prismhearth"},
	"inferno": {"faction_id": "faction_veilmourn", "town_id": "town_veilmourn_bellwake_harbor"},
	"necropolis": {"faction_id": "faction_mireclaw", "town_id": "town_nightglass_redoubt"},
	"dungeon": {"faction_id": "faction_sunvault", "town_id": "town_halo_spire"},
	"stronghold": {"faction_id": "faction_embercourt", "town_id": "town_highwater_keep"},
	"fortress": {"faction_id": "faction_mireclaw", "town_id": "town_blackfen_gate"},
	"elemental": {"faction_id": "faction_sunvault", "town_id": "town_prismhearth"},
}

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
	var artifact_nodes := _artifact_nodes_from_document(map_document)
	var encounters := _ensure_generated_rare_source_guards(resource_nodes, _encounters_from_document(map_document))
	var map_objects := _map_objects_from_document(map_document)
	var overworld_state := {
		"map": map_rows,
		"map_size": map_size,
		"terrain_layers": terrain_layers,
		"active_hero_id": hero_id_from_doc,
		"player_heroes": [hero_state] if not hero_state.is_empty() else [],
		"hero_position": start,
		"hero": hero_state,
		"movement": hero_state.get("movement", {"current": 0, "max": 0}) if not hero_state.is_empty() else {"current": 0, "max": 0},
		"resources": _opening_resource_stockpile(),
		"army": hero_state.get("army", {}) if not hero_state.is_empty() else {},
		"encounters": encounters,
		"resolved_encounters": [],
		"towns": towns,
		"resource_nodes": resource_nodes,
		"map_objects": map_objects,
		"artifact_nodes": artifact_nodes,
		"enemy_states": _enemy_states_from_document(scenario_document),
		"map_package_ref": map_ref,
		"scenario_package_ref": scenario_ref,
		"native_random_map_package_session_adoption": boundary.duplicate(true),
		"generated_random_map_identity": adoption.get("generated_identity", {}),
		"generated_random_map_validation": adoption.get("validation_report", {}),
	}
	var runtime_scenario_record := _runtime_scenario_record_from_documents(
		scenario_id,
		map_document,
		scenario_document,
		overworld_state,
		hero_id_from_doc,
		start
	)
	if not runtime_scenario_record.is_empty():
		overworld_state["native_random_map_runtime_scenario_record"] = runtime_scenario_record
	var draft_registration := {
		"ok": true,
		"status": "skipped_package_session_uses_loaded_documents",
		"generated_scenario_draft_registry": false,
	}
	if bool(options.get("register_generated_scenario_draft", false)):
		draft_registration = _register_generated_scenario_draft_from_documents(
			scenario_id,
			map_document,
			scenario_document,
			overworld_state,
			hero_id_from_doc,
			start
		)
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
		"native_random_map_runtime_scenario_record": runtime_scenario_record,
		"native_random_map_scenario_draft_registration": draft_registration,
	}
	OverworldRulesScript.normalize_overworld_state(session)
	if _ensure_generated_town_source_route_support(session):
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
		var start_towns: Array = start_contract.get("player_start_towns", []) if start_contract.get("player_start_towns", []) is Array else []
		for town_value in start_towns:
			if town_value is Dictionary and String(town_value.get("owner", "")) == "player":
				var hero_start_tile: Dictionary = town_value.get("hero_start_tile", town_value.get("runtime_start_tile", {})) if town_value.get("hero_start_tile", town_value.get("runtime_start_tile", {})) is Dictionary else {}
				if not hero_start_tile.is_empty():
					return {"x": int(hero_start_tile.get("x", town_value.get("x", 0))), "y": int(hero_start_tile.get("y", town_value.get("y", 0)))}
				var visit_tile: Dictionary = town_value.get("visit_tile", {}) if town_value.get("visit_tile", {}) is Dictionary else {}
				if not visit_tile.is_empty():
					return {"x": int(visit_tile.get("x", town_value.get("x", 0))), "y": int(visit_tile.get("y", town_value.get("y", 0)))}
				var package_visit_tiles: Array = town_value.get("package_visit_tiles", []) if town_value.get("package_visit_tiles", []) is Array else []
				if not package_visit_tiles.is_empty() and package_visit_tiles[0] is Dictionary:
					var package_visit: Dictionary = package_visit_tiles[0]
					return {"x": int(package_visit.get("x", town_value.get("x", 0))), "y": int(package_visit.get("y", town_value.get("y", 0)))}
				return {"x": int(town_value.get("x", 0)), "y": int(town_value.get("y", 0))}
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

static func _opening_resource_stockpile() -> Dictionary:
	var resources := {}
	for resource_key in OverworldRulesScript.LIVE_STOCKPILE_RESOURCE_KEYS:
		resources[resource_key] = 0
	resources["gold"] = 5000
	resources["wood"] = 10
	resources["ore"] = 10
	return resources

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
		var town_identity := _project_town_identity_from_h3m_record(object)
		var town_id := String(town_identity.get("town_id", object.get("town_id", "")))
		var town_faction_id := String(town_identity.get("faction_id", object.get("faction_id", "")))
		var town_template := ContentService.get_town(town_id)
		if ContentService.get_faction(town_faction_id).is_empty():
			town_faction_id = String(town_template.get("faction_id", town_faction_id))
		var owner_slot := _int_or_default(object.get("owner_slot", object.get("player_slot", -1)), -1)
		var player_slot := _int_or_default(object.get("player_slot", object.get("owner_slot", -1)), -1)
		towns.append({
			"placement_id": String(object.get("placement_id", "")),
			"town_id": town_id,
			"x": int(object.get("x", 0)),
			"y": int(object.get("y", 0)),
			"owner": String(object.get("owner", "neutral")),
			"owner_slot": owner_slot,
			"player_slot": player_slot,
			"player_type": String(object.get("player_type", "")),
			"team_id": String(object.get("team_id", "")),
			"faction_id": town_faction_id,
			"source_h3maped_faction_id": String(object.get("h3maped_faction_id", object.get("faction_id", ""))),
			"source_package_town_id": String(object.get("town_id", "")),
				"is_start_town": _bool_or_default(object.get("is_start_town", object.get("start_anchor", false)), false),
				"start_anchor": _bool_or_default(object.get("start_anchor", object.get("is_start_town", false)), false),
			"body_tiles": object.get("package_body_tiles", object.get("body_tiles", [])).duplicate(true) if object.get("package_body_tiles", object.get("body_tiles", [])) is Array else [],
			"package_block_tiles": object.get("package_block_tiles", []).duplicate(true) if object.get("package_block_tiles", []) is Array else [],
			"visit_tile": object.get("visit_tile", {}).duplicate(true) if object.get("visit_tile", {}) is Dictionary else {},
			"package_visit_tiles": object.get("package_visit_tiles", []).duplicate(true) if object.get("package_visit_tiles", []) is Array else [],
				"blocking_body": _bool_or_default(object.get("blocking_body", true), true),
			"built_buildings": town_template.get("starting_building_ids", []).duplicate(true) if town_template.get("starting_building_ids", []) is Array else [],
			"available_recruits": {},
			"garrison": town_template.get("garrison", []).duplicate(true) if town_template.get("garrison", []) is Array else [],
		})
	return towns

static func _project_town_identity_from_h3m_record(object: Dictionary) -> Dictionary:
	for key in ["h3maped_faction_id", "faction_id", "source_h3maped_faction_id"]:
		var token := String(object.get(key, "")).strip_edges()
		var identity := _project_town_identity_for_h3m_token(token)
		if not identity.is_empty():
			return identity
	var faction_id := String(object.get("faction_id", "")).strip_edges()
	if not ContentService.get_faction(faction_id).is_empty():
		var town_id := String(object.get("town_id", "")).strip_edges()
		if ContentService.get_town(town_id).is_empty():
			town_id = _project_town_id_for_faction(faction_id)
		return {"faction_id": faction_id, "town_id": town_id}
	return {"faction_id": "", "town_id": String(object.get("town_id", ""))}

static func _project_town_identity_for_h3m_token(token: String) -> Dictionary:
	var normalized := token.strip_edges().to_lower()
	if normalized.begins_with("h3_"):
		normalized = normalized.substr(3)
	if normalized.begins_with("h3m_"):
		normalized = normalized.substr(4)
	if H3M_TOWN_TYPE_PROJECT_IDENTITY.has(normalized):
		return (H3M_TOWN_TYPE_PROJECT_IDENTITY[normalized] as Dictionary).duplicate(true)
	return {}

static func _project_town_id_for_faction(faction_id: String) -> String:
	var faction := ContentService.get_faction(faction_id)
	var seed_town_id := String(faction.get("seed_town_id", ""))
	if not ContentService.get_town(seed_town_id).is_empty():
		return seed_town_id
	for town_id_value in faction.get("town_ids", []):
		var town_id := String(town_id_value)
		if not ContentService.get_town(town_id).is_empty():
			return town_id
	return "town_riverwatch"

static func _int_or_default(value: Variant, default_value: int) -> int:
	if value == null:
		return default_value
	return int(value)

static func _bool_or_default(value: Variant, default_value: bool) -> bool:
	if value == null:
		return default_value
	if value is bool:
		return value
	if value is int or value is float:
		return int(value) != 0
	var text := str(value).strip_edges().to_lower()
	if text in ["true", "1", "yes", "on"]:
		return true
	if text in ["false", "0", "no", "off", ""]:
		return false
	return default_value

static func _resource_nodes_from_document(map_document: Variant) -> Array:
	var nodes := []
	for object in _document_objects(map_document):
		var kind := String(object.get("kind", ""))
		if not (kind in ["resource_site", "mine", "neutral_dwelling", "reward_reference"]):
			continue
		var site_id := _resource_site_id_for_object(object)
		if site_id == "":
			continue
		var node: Dictionary = object.duplicate(true)
		node["site_id"] = site_id
		node["collected"] = false
		nodes.append(node)
	return nodes

static func _artifact_nodes_from_document(map_document: Variant) -> Array:
	var nodes := []
	for object in _document_objects(map_document):
		var artifact_id := String(object.get("artifact_id", ""))
		if artifact_id == "":
			continue
		var node: Dictionary = object.duplicate(true)
		node["collected"] = false
		nodes.append(node)
	return nodes

static func _encounters_from_document(map_document: Variant) -> Array:
	var encounters := []
	for object in _document_objects(map_document):
		var kind := String(object.get("kind", ""))
		var native_kind := String(object.get("native_record_kind", ""))
		if kind != "guard" and native_kind != "guard":
			continue
		var encounter: Dictionary = object.duplicate(true)
		var encounter_id := String(encounter.get("encounter_id", ""))
		if encounter_id == "":
			encounter_id = String(encounter.get("object_id", ""))
		if encounter_id != "" and ContentService.get_encounter(encounter_id).is_empty():
			encounter["native_guard_object_id"] = encounter_id
			encounter_id = ""
		if encounter_id == "":
			encounter_id = "encounter_mire_raid"
		encounter["encounter_id"] = encounter_id
		if String(encounter.get("object_id", "")) == "":
			encounter["object_id"] = encounter_id
		encounters.append(encounter)
	return encounters

static func _ensure_generated_rare_source_guards(resource_nodes: Array, encounters: Array) -> Array:
	var result := encounters.duplicate(true)
	for node_value in resource_nodes:
		if not (node_value is Dictionary):
			continue
		var node: Dictionary = node_value
		if not _generated_resource_node_is_rare_source(node):
			continue
		if _resource_node_has_linked_guard(result, node):
			continue
		result.append(_supplemental_rare_source_guard(node))
	return result

static func _generated_resource_node_is_rare_source(node: Dictionary) -> bool:
	var placement_id := String(node.get("placement_id", ""))
	if not placement_id.begins_with("h3maped_small_"):
		return false
	var site := ContentService.get_resource_site(String(node.get("site_id", "")))
	for bucket in [site.get("claim_rewards", site.get("rewards", {})), site.get("control_income", {})]:
		if not (bucket is Dictionary):
			continue
		for key in bucket.keys():
			var resource_id := String(key)
			if resource_id in ["aetherglass", "embergrain", "peatwax", "verdant_grafts", "brass_scrip", "memory_salt"] and int(bucket.get(key, 0)) > 0:
				return true
	return false

static func _resource_node_has_linked_guard(encounters: Array, node: Dictionary) -> bool:
	var placement_id := String(node.get("placement_id", ""))
	for encounter_value in encounters:
		if not (encounter_value is Dictionary):
			continue
		var encounter: Dictionary = encounter_value
		if String(encounter.get("target_kind", "")) == "resource" and String(encounter.get("target_placement_id", "")) == placement_id:
			return true
		var guard_link: Dictionary = encounter.get("guard_link", {}) if encounter.get("guard_link", {}) is Dictionary else {}
		if String(guard_link.get("target_placement_id", "")) == placement_id:
			return true
	return false

static func _supplemental_rare_source_guard(node: Dictionary) -> Dictionary:
	var placement_id := String(node.get("placement_id", ""))
	var x := int(node.get("x", 0))
	var y := int(node.get("y", 0))
	var level := int(node.get("level", 0))
	var tile := {"x": x, "y": y, "level": level}
	var guard_link := {
		"guard_role": "guards_resource_source",
		"target_kind": "resource_node",
		"target_id": String(node.get("site_id", "")),
		"target_placement_id": placement_id,
		"blocks_approach": true,
		"clear_required_for_target": true,
		"source": "generated_package_rare_source_guard_pressure_runtime_adoption",
	}
	return {
		"placement_id": "h3maped_small_rare_source_guard_%s" % placement_id,
		"kind": "guard",
		"package_kind": "guard",
		"encounter_id": "encounter_mire_raid",
		"object_id": "encounter_mire_raid",
		"native_guard_object_id": "encounter_h3maped_mine_guard",
		"generated_package_guard_policy": "rare_economy_source_requires_runtime_guard_link",
		"target_kind": "resource",
		"target_placement_id": placement_id,
		"guard_link": guard_link,
		"guard_value": 600,
		"x": x,
		"y": y,
		"level": level,
		"primary_tile": tile,
		"body_tiles": [tile],
		"package_body_tiles": [tile],
		"package_block_tiles": [tile],
		"package_visit_tiles": [tile],
		"visit_tile": tile,
		"blocking_body": true,
		"passability_class": "neutral_stack_blocking",
		"package_guard_engagement_tiles": [tile],
		"package_guard_engagement_tile_count": 1,
	}

static func _ensure_generated_town_source_route_support(session: SessionStateStoreScript.SessionData) -> bool:
	if session == null or not bool(session.flags.get("generated_random_map", false)):
		return false
	var changed := false
	var towns: Array = session.overworld.get("towns", []) if session.overworld.get("towns", []) is Array else []
	for town_value in towns:
		if not (town_value is Dictionary):
			continue
		var town: Dictionary = town_value
		if not (String(town.get("owner", "")) in ["player", "enemy", "neutral"]):
			continue
		var start_tile := _generated_town_source_start_tile(session, town)
		var required_resource_ids := _generated_town_required_source_ids(town)
		if required_resource_ids.is_empty():
			continue
		var support_tile := start_tile if _generated_source_route_start_tile_usable(session, start_tile) else Vector2i(-1, -1)
		if support_tile == Vector2i(-1, -1) and _generated_source_route_start_tile_usable(session, start_tile):
			support_tile = start_tile
		if support_tile == Vector2i(-1, -1):
			support_tile = _generated_town_source_support_tile(session, start_tile, 0)
		if support_tile == Vector2i(-1, -1):
			support_tile = _existing_generated_town_support_tile(session, town)
		if support_tile == Vector2i(-1, -1):
			continue
		var node := _supplemental_generated_town_source_node(town, "required_sources", support_tile)
		if node.is_empty():
			continue
		node["generated_package_source_resource_ids"] = required_resource_ids
		node["generated_package_source_route_start_tile"] = {
			"x": support_tile.x,
			"y": support_tile.y,
			"level": int(town.get("level", 0)),
		}
		var nodes: Array = session.overworld.get("resource_nodes", []) if session.overworld.get("resource_nodes", []) is Array else []
		nodes.append(node)
		session.overworld["resource_nodes"] = nodes
		var encounters: Array = session.overworld.get("encounters", []) if session.overworld.get("encounters", []) is Array else []
		encounters.append(_supplemental_rare_source_guard(node))
		session.overworld["encounters"] = encounters
		changed = true
		OverworldRulesScript.normalize_overworld_state(session)
	return changed

static func _generated_town_required_source_ids(town: Dictionary) -> Array:
	var result := {}
	var town_template := ContentService.get_town(String(town.get("town_id", "")))
	for building_id_value in town_template.get("buildable_building_ids", []):
		var building := ContentService.get_building(String(building_id_value))
		var cost: Dictionary = building.get("cost", {}) if building.get("cost", {}) is Dictionary else {}
		for resource_id_value in cost.keys():
			var resource_id := String(resource_id_value)
			if resource_id == "gold":
				continue
			if GENERATED_TOWN_COMMON_SOURCE_SITE_BY_RESOURCE.has(resource_id) or GENERATED_TOWN_RARE_SOURCE_SITE_BY_RESOURCE.has(resource_id):
				result[resource_id] = true
	var ordered := []
	for resource_id in ["wood", "ore"]:
		if bool(result.get(resource_id, false)):
			ordered.append(resource_id)
	for resource_id in ["aetherglass", "brass_scrip", "embergrain", "memory_salt", "peatwax", "verdant_grafts"]:
		if bool(result.get(resource_id, false)):
			ordered.append(resource_id)
	return ordered

static func _supplemental_generated_town_source_node(town: Dictionary, resource_id: String, tile: Vector2i) -> Dictionary:
	var site_id := ""
	var object_id := ""
	if resource_id == "required_sources":
		site_id = GENERATED_TOWN_REQUIRED_SOURCE_SITE_ID
	elif GENERATED_TOWN_COMMON_SOURCE_SITE_BY_RESOURCE.has(resource_id):
		var record: Dictionary = GENERATED_TOWN_COMMON_SOURCE_SITE_BY_RESOURCE[resource_id]
		site_id = String(record.get("site_id", ""))
		object_id = String(record.get("object_id", ""))
	else:
		site_id = String(GENERATED_TOWN_RARE_SOURCE_SITE_BY_RESOURCE.get(resource_id, ""))
	if site_id == "" or ContentService.get_resource_site(site_id).is_empty():
		return {}
	var placement_id := "h3maped_small_town_source_support_%s_%s" % [
		String(town.get("placement_id", "town")),
		resource_id,
	]
	var tile_payload := {"x": tile.x, "y": tile.y, "level": int(town.get("level", 0))}
	return {
		"placement_id": placement_id,
		"kind": "mine",
		"package_kind": "mine",
		"site_id": site_id,
		"object_id": object_id,
		"owner": "neutral",
		"player_slot": 0,
		"player_type": "neutral",
		"generated_kind": "mine",
		"generated_package_source_policy": "town_required_source_route_support",
		"generated_package_source_town_placement_id": String(town.get("placement_id", "")),
		"resource_id": resource_id,
		"x": tile.x,
		"y": tile.y,
		"level": int(town.get("level", 0)),
		"primary_tile": tile_payload,
		"visit_tile": tile_payload,
		"body_tiles": [tile_payload],
		"package_body_tiles": [tile_payload],
		"package_block_tiles": [],
		"package_visit_tiles": [tile_payload],
		"approach_tiles": [tile_payload],
		"blocking_body": false,
		"object_footprint_catalog_ref": {"source": "generated_package_town_source_route_support"},
		"collected": false,
	}

static func _existing_generated_town_support_tile(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Vector2i:
	var town_placement_id := String(town.get("placement_id", ""))
	for node_value in session.overworld.get("resource_nodes", []):
		if not (node_value is Dictionary):
			continue
		var node: Dictionary = node_value
		if String(node.get("generated_package_source_town_placement_id", "")) != town_placement_id:
			continue
		return _generated_source_target_tile(node)
	return Vector2i(-1, -1)

static func _generated_town_source_support_tile(
	session: SessionStateStoreScript.SessionData,
	start_tile: Vector2i,
	source_index: int
) -> Vector2i:
	var map_size := OverworldRulesScript.derive_map_size(session)
	if not _generated_source_in_bounds(start_tile, map_size):
		return Vector2i(-1, -1)
	var queue := [start_tile]
	var distances := {_generated_source_tile_key(start_tile): 0}
	var candidates := []
	var near_candidates := []
	var stackable_candidates := []
	var head := 0
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		var current_distance := int(distances.get(_generated_source_tile_key(current), 0))
		if current_distance > 6:
			continue
		if current_distance >= 2 and _generated_source_tile_available(session, current):
			candidates.append(current)
		elif current_distance == 1 and _generated_source_tile_available(session, current):
			near_candidates.append(current)
		elif current_distance >= 2 and _generated_source_tile_stackable(session, current):
			stackable_candidates.append(current)
		for neighbor in _generated_source_route_neighbors(current):
			if not _generated_source_in_bounds(neighbor, map_size):
				continue
			var neighbor_key := _generated_source_tile_key(neighbor)
			if distances.has(neighbor_key):
				continue
			if OverworldRulesScript.tile_step_cuts_blocked_corner(session, current, neighbor):
				continue
			if OverworldRulesScript.tile_is_blocked(session, neighbor.x, neighbor.y):
				if _generated_source_tile_stackable(session, neighbor):
					stackable_candidates.append(neighbor)
				continue
			if OverworldRulesScript.tile_has_route_interaction(session, neighbor.x, neighbor.y):
				continue
			distances[neighbor_key] = current_distance + 1
			queue.append(neighbor)
	if candidates.is_empty():
		if not near_candidates.is_empty():
			return near_candidates[source_index % near_candidates.size()]
		if stackable_candidates.is_empty():
			return Vector2i(-1, -1)
		return stackable_candidates[source_index % stackable_candidates.size()]
	return candidates[source_index % candidates.size()]

static func _generated_source_tile_available(session: SessionStateStoreScript.SessionData, tile: Vector2i) -> bool:
	if OverworldRulesScript.tile_is_blocked(session, tile.x, tile.y):
		return false
	if OverworldRulesScript.tile_has_route_interaction(session, tile.x, tile.y):
		return false
	for node_value in session.overworld.get("resource_nodes", []):
		if node_value is Dictionary and int(node_value.get("x", -9999)) == tile.x and int(node_value.get("y", -9999)) == tile.y:
			return false
	for encounter_value in session.overworld.get("encounters", []):
		if encounter_value is Dictionary and int(encounter_value.get("x", -9999)) == tile.x and int(encounter_value.get("y", -9999)) == tile.y:
			return false
	return true

static func _generated_source_tile_stackable(session: SessionStateStoreScript.SessionData, tile: Vector2i) -> bool:
	for node_value in session.overworld.get("resource_nodes", []):
		if not (node_value is Dictionary):
			continue
		var node: Dictionary = node_value
		if int(node.get("x", -9999)) == tile.x and int(node.get("y", -9999)) == tile.y:
			return true
		var visit_tile: Dictionary = node.get("visit_tile", {}) if node.get("visit_tile", {}) is Dictionary else {}
		if int(visit_tile.get("x", -9999)) == tile.x and int(visit_tile.get("y", -9999)) == tile.y:
			return true
	return not OverworldRulesScript.tile_is_blocked(session, tile.x, tile.y)

static func _generated_source_target_tile(node: Dictionary) -> Vector2i:
	for key in ["visit_tile", "primary_tile", "action_tile"]:
		var tile: Dictionary = node.get(key, {}) if node.get(key, {}) is Dictionary else {}
		if not tile.is_empty():
			return Vector2i(int(tile.get("x", node.get("x", 0))), int(tile.get("y", node.get("y", 0))))
	for key in ["package_visit_tiles", "action_tiles", "package_action_tiles", "approach_tiles"]:
		var tiles: Array = node.get(key, []) if node.get(key, []) is Array else []
		for tile_value in tiles:
			if tile_value is Dictionary:
				return Vector2i(int(tile_value.get("x", node.get("x", 0))), int(tile_value.get("y", node.get("y", 0))))
	return Vector2i(int(node.get("x", 0)), int(node.get("y", 0)))

static func _generated_town_source_start_tile(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Vector2i:
	for key in ["hero_start_tile", "runtime_start_tile"]:
		var tile: Dictionary = town.get(key, {}) if town.get(key, {}) is Dictionary else {}
		if not tile.is_empty():
			return Vector2i(int(tile.get("x", town.get("x", 0))), int(tile.get("y", town.get("y", 0))))
	var fallback := Vector2i(-1, -1)
	for key in ["approach_tiles", "package_visit_tiles"]:
		var tiles: Array = town.get(key, []) if town.get(key, []) is Array else []
		for tile_value in tiles:
			if tile_value is Dictionary:
				var candidate := Vector2i(int(tile_value.get("x", town.get("x", 0))), int(tile_value.get("y", town.get("y", 0))))
				if fallback == Vector2i(-1, -1):
					fallback = candidate
				if _generated_source_route_start_tile_usable(session, candidate):
					return candidate
	for key in ["visit_tile", "primary_tile"]:
		var tile: Dictionary = town.get(key, {}) if town.get(key, {}) is Dictionary else {}
		if not tile.is_empty():
			var candidate := Vector2i(int(tile.get("x", town.get("x", 0))), int(tile.get("y", town.get("y", 0))))
			if _generated_source_route_start_tile_usable(session, candidate):
				return candidate
			if fallback == Vector2i(-1, -1):
				fallback = candidate
	var nearest := _generated_nearest_source_route_start_tile(
		session,
		Vector2i(int(town.get("x", fallback.x if fallback != Vector2i(-1, -1) else 0)), int(town.get("y", fallback.y if fallback != Vector2i(-1, -1) else 0)))
	)
	if nearest != Vector2i(-1, -1):
		return nearest
	if fallback != Vector2i(-1, -1):
		return fallback
	return Vector2i(int(town.get("x", 0)), int(town.get("y", 0)))

static func _generated_source_route_start_tile_usable(session: SessionStateStoreScript.SessionData, tile: Vector2i) -> bool:
	var map_size := OverworldRulesScript.derive_map_size(session)
	if not _generated_source_in_bounds(tile, map_size):
		return false
	if OverworldRulesScript.tile_is_blocked(session, tile.x, tile.y):
		return false
	return not OverworldRulesScript.tile_has_route_interaction(session, tile.x, tile.y)

static func _generated_nearest_source_route_start_tile(
	session: SessionStateStoreScript.SessionData,
	origin: Vector2i,
	max_distance: int = 8
) -> Vector2i:
	var map_size := OverworldRulesScript.derive_map_size(session)
	if not _generated_source_in_bounds(origin, map_size):
		return Vector2i(-1, -1)
	var queue := [origin]
	var distances := {_generated_source_tile_key(origin): 0}
	var head := 0
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		var current_distance := int(distances.get(_generated_source_tile_key(current), 0))
		if current_distance > max_distance:
			continue
		if current_distance > 0 and _generated_source_route_start_tile_usable(session, current):
			return current
		for neighbor in _generated_source_route_neighbors(current):
			if not _generated_source_in_bounds(neighbor, map_size):
				continue
			var neighbor_key := _generated_source_tile_key(neighbor)
			if distances.has(neighbor_key):
				continue
			distances[neighbor_key] = current_distance + 1
			queue.append(neighbor)
	return Vector2i(-1, -1)

static func _generated_source_route_neighbors(tile: Vector2i) -> Array:
	return [
		Vector2i(tile.x - 1, tile.y - 1),
		Vector2i(tile.x, tile.y - 1),
		Vector2i(tile.x + 1, tile.y - 1),
		Vector2i(tile.x - 1, tile.y),
		Vector2i(tile.x + 1, tile.y),
		Vector2i(tile.x - 1, tile.y + 1),
		Vector2i(tile.x, tile.y + 1),
		Vector2i(tile.x + 1, tile.y + 1),
	]

static func _generated_source_in_bounds(tile: Vector2i, map_size: Variant) -> bool:
	if map_size is Vector2i:
		return tile.x >= 0 and tile.y >= 0 and tile.x < map_size.x and tile.y < map_size.y
	if map_size is Dictionary:
		return tile.x >= 0 and tile.y >= 0 and tile.x < int(map_size.get("x", map_size.get("width", 0))) and tile.y < int(map_size.get("y", map_size.get("height", 0)))
	return false

static func _generated_source_tile_key(tile: Vector2i) -> String:
	return "%d,%d" % [tile.x, tile.y]

static func _map_objects_from_document(map_document: Variant) -> Array:
	var objects := []
	for object in _document_objects(map_document):
		var kind := String(object.get("kind", ""))
		var native_kind := String(object.get("native_record_kind", ""))
		if kind == "town" or native_kind == "town":
			continue
		if kind == "guard" or native_kind == "guard":
			continue
		if kind in ["resource_site", "mine", "neutral_dwelling", "reward_reference"] or native_kind in ["resource_site", "mine", "neutral_dwelling", "reward_reference"]:
			continue
		var family := String(object.get("object_family_id", object.get("family_id", "")))
		if kind != "decorative_obstacle" and family != "decorative_obstacle" and String(object.get("object_id", "")) == "":
			continue
		var node: Dictionary = object.duplicate(true)
		if kind == "decorative_obstacle" or family == "decorative_obstacle":
			node["runtime_object_role"] = "decorative_blocker_sprite"
		node["collected"] = false
		objects.append(node)
	return objects

static func _resource_site_id_for_object(object: Dictionary) -> String:
	var rare_mine_site_id := _live_rare_site_id_for_h3m_mine(object)
	if rare_mine_site_id != "":
		return rare_mine_site_id
	var site_id := String(object.get("site_id", "")).strip_edges()
	if site_id != "":
		return site_id
	var object_id := String(object.get("object_id", "")).strip_edges()
	if object_id == "":
		return ""
	var map_object := ContentService.get_map_object(object_id)
	return String(map_object.get("resource_site_id", "")).strip_edges()

static func _live_rare_site_id_for_h3m_mine(object: Dictionary) -> String:
	var kind := String(object.get("kind", ""))
	var native_kind := String(object.get("native_record_kind", ""))
	if kind != "mine" and native_kind != "mine":
		return ""
	var object_id := String(object.get("object_id", "")).strip_edges()
	match object_id:
		"object_marsh_peat_yard":
			return "site_peatwax_reed_yard"
		"object_floodplain_sluice_camp":
			return "site_embergrain_warm_granary"
		"object_cinder_ore_face":
			return "site_aetherglass_lens_house"
		"object_badlands_coin_sluice":
			return "site_memory_salt_pan"
	return ""

static func _register_generated_scenario_draft_from_documents(
	scenario_id: String,
	map_document: Variant,
	scenario_document: Variant,
	overworld_state: Dictionary,
	hero_id: String,
	start: Dictionary
) -> Dictionary:
	if scenario_id == "" or map_document == null or scenario_document == null:
		return {"ok": false, "message": "Package-backed generated scenario draft is missing required documents."}
	var scenario_record := _runtime_scenario_record_from_documents(
		scenario_id,
		map_document,
		scenario_document,
		overworld_state,
		hero_id,
		start
	)
	if scenario_record.is_empty():
		return {"ok": false, "message": "Package-backed generated scenario draft could not build a scenario record."}
	return ContentService.register_generated_scenario_draft(scenario_record, overworld_state.get("terrain_layers", {}))

static func _runtime_scenario_record_from_documents(
	scenario_id: String,
	map_document: Variant,
	scenario_document: Variant,
	overworld_state: Dictionary,
	hero_id: String,
	start: Dictionary
) -> Dictionary:
	if scenario_id == "" or map_document == null or scenario_document == null:
		return {}
	var selection: Dictionary = scenario_document.get_selection() if scenario_document.has_method("get_selection") else {}
	var objectives: Dictionary = scenario_document.get_objectives() if scenario_document.has_method("get_objectives") else {}
	return {
		"id": scenario_id,
		"name": String(selection.get("name", scenario_id)),
		"generated": true,
		"source": "native_rmg_disk_package_runtime",
		"selection": selection,
		"map_size": overworld_state.get("map_size", {}),
		"map": overworld_state.get("map", []),
		"player_faction_id": _player_faction_from_document(scenario_document, overworld_state),
		"starting_hero_id": hero_id,
		"hero_id": hero_id,
		"starting_position": start,
		"towns": overworld_state.get("towns", []),
		"resource_nodes": overworld_state.get("resource_nodes", []),
		"artifact_nodes": overworld_state.get("artifact_nodes", []),
		"encounters": overworld_state.get("encounters", []),
		"map_objects": overworld_state.get("map_objects", []),
		"objectives": objectives,
		"script_hooks": scenario_document.get_script_hooks() if scenario_document.has_method("get_script_hooks") else [],
		"enemy_factions": scenario_document.get_enemy_factions() if scenario_document.has_method("get_enemy_factions") else [],
		"native_generated_package": {
			"schema_id": "aurelion_native_rmg_disk_package_runtime_record_v1",
			"map_ref": overworld_state.get("map_package_ref", {}),
			"scenario_ref": overworld_state.get("scenario_package_ref", {}),
		},
	}

static func _player_faction_from_document(scenario_document: Variant, overworld_state: Dictionary) -> String:
	if scenario_document != null and scenario_document.has_method("get_start_contract"):
		var start_contract: Dictionary = scenario_document.get_start_contract()
		var starts: Array = start_contract.get("player_starts", []) if start_contract.get("player_starts", []) is Array else []
		for start in starts:
			if start is Dictionary and String(start.get("owner", "")) == "player":
				var start_faction_id := String(start.get("faction_id", ""))
				if not ContentService.get_faction(start_faction_id).is_empty():
					return start_faction_id
	var towns: Array = overworld_state.get("towns", []) if overworld_state.get("towns", []) is Array else []
	for town in towns:
		if town is Dictionary and String(town.get("owner", "")) == "player":
			return String(town.get("faction_id", ""))
	return "faction_embercourt"

static func _enemy_states_from_document(scenario_document: Variant) -> Array:
	var enemies := []
	if scenario_document == null:
		return enemies
	for enemy in scenario_document.get_enemy_factions():
		if enemy is Dictionary:
			enemies.append(enemy.duplicate(true))
	return enemies
