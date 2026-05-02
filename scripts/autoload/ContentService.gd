class_name HeroesContentService
extends Node

const CONTENT_DIR := "res://content"
const SCENARIOS_PATH := "%s/scenarios.json" % CONTENT_DIR
const ENCOUNTERS_PATH := "%s/encounters.json" % CONTENT_DIR
const HEROES_PATH := "%s/heroes.json" % CONTENT_DIR
const FACTIONS_PATH := "%s/factions.json" % CONTENT_DIR
const UNITS_PATH := "%s/units.json" % CONTENT_DIR
const ARMY_GROUPS_PATH := "%s/army_groups.json" % CONTENT_DIR
const TOWNS_PATH := "%s/towns.json" % CONTENT_DIR
const BUILDINGS_PATH := "%s/buildings.json" % CONTENT_DIR
const RESOURCE_SITES_PATH := "%s/resource_sites.json" % CONTENT_DIR
const BIOMES_PATH := "%s/biomes.json" % CONTENT_DIR
const TERRAIN_GRAMMAR_PATH := "%s/terrain_grammar.json" % CONTENT_DIR
const TERRAIN_LAYERS_PATH := "%s/terrain_layers.json" % CONTENT_DIR
const MAP_OBJECTS_PATH := "%s/map_objects.json" % CONTENT_DIR
const NEUTRAL_DWELLINGS_PATH := "%s/neutral_dwellings.json" % CONTENT_DIR
const ARTIFACTS_PATH := "%s/artifacts.json" % CONTENT_DIR
const SPELLS_PATH := "%s/spells.json" % CONTENT_DIR
const CAMPAIGNS_PATH := "%s/campaigns.json" % CONTENT_DIR

var _cache: Dictionary = {}
var _generated_scenario_drafts: Dictionary = {}
var _generated_terrain_layer_drafts: Dictionary = {}

func _ready() -> void:
	_validate_content()

func clear_cache() -> void:
	_cache.clear()

func clear_generated_scenario_drafts() -> void:
	_generated_scenario_drafts.clear()
	_generated_terrain_layer_drafts.clear()

func load_json(path: String) -> Dictionary:
	if path in _cache:
		return _cache[path]

	if not path.begins_with("res://"):
		push_error("Only res:// content paths are supported: %s" % path)
		return {}

	if not FileAccess.file_exists(path):
		push_error("Missing content file: %s" % path)
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open content file: %s" % path)
		return {}

	var text := file.get_as_text()
	var parser := JSON.new()
	var error := parser.parse(text)
	if error != OK:
		push_error(
			"Invalid JSON for content file %s at line %d: %s"
			% [path, parser.get_error_line(), parser.get_error_message()]
		)
		return {}

	var parsed = parser.data
	if parsed is Dictionary:
		_cache[path] = parsed
		return parsed
	if parsed is Array:
		var wrapped := {"items": parsed}
		_cache[path] = wrapped
		return wrapped

	push_error("Unsupported JSON root for content file: %s" % path)
	return {}

func get_content_ids(path: String, list_key: String = "items") -> Array[String]:
	var raw := load_json(path)
	if raw.is_empty():
		return []
	var ids: Array[String] = []
	for item in _items_from_raw(raw, list_key):
		if item.has("id"):
			ids.append(String(item["id"]))
	return ids

func get_faction(id: String) -> Dictionary:
	return get_content_by_id(FACTIONS_PATH, id)

func get_hero(id: String) -> Dictionary:
	return get_content_by_id(HEROES_PATH, id)

func get_unit(id: String) -> Dictionary:
	return get_content_by_id(UNITS_PATH, id)

func get_army_group(id: String) -> Dictionary:
	return get_content_by_id(ARMY_GROUPS_PATH, id)

func get_town(id: String) -> Dictionary:
	return get_content_by_id(TOWNS_PATH, id)

func get_building(id: String) -> Dictionary:
	return get_content_by_id(BUILDINGS_PATH, id)

func get_resource_site(id: String) -> Dictionary:
	return get_content_by_id(RESOURCE_SITES_PATH, id)

func get_biome(id: String) -> Dictionary:
	return get_content_by_id(BIOMES_PATH, id)

func get_terrain_grammar() -> Dictionary:
	return load_json(TERRAIN_GRAMMAR_PATH)

func get_terrain_layers_for_scenario(scenario_id: String) -> Dictionary:
	var layers := get_content_by_id(TERRAIN_LAYERS_PATH, scenario_id)
	if not layers.is_empty():
		return layers.duplicate(true)
	var draft: Dictionary = _generated_terrain_layer_drafts.get(scenario_id, {})
	return draft.duplicate(true) if not draft.is_empty() else {}

func get_biome_for_terrain(terrain_id: String) -> Dictionary:
	var normalized_terrain := String(terrain_id)
	if normalized_terrain == "":
		return {}
	for biome in _items_from_raw(load_json(BIOMES_PATH)):
		if not (biome is Dictionary):
			continue
		if normalized_terrain in biome.get("map_tile_ids", []):
			return biome
	return {}

func get_map_object(id: String) -> Dictionary:
	return get_content_by_id(MAP_OBJECTS_PATH, id)

func get_map_object_for_resource_site(site_id: String) -> Dictionary:
	var normalized_site_id := site_id.strip_edges()
	if normalized_site_id == "":
		return {}
	var best := {}
	for item in _items_from_raw(load_json(MAP_OBJECTS_PATH)):
		if not (item is Dictionary):
			continue
		if String(item.get("resource_site_id", "")).strip_edges() != normalized_site_id:
			continue
		if best.is_empty():
			best = item
			continue
		if _map_object_footprint_area(item) > _map_object_footprint_area(best):
			best = item
	return best

func get_neutral_dwelling(id: String) -> Dictionary:
	return get_content_by_id(NEUTRAL_DWELLINGS_PATH, id)

func get_artifact(id: String) -> Dictionary:
	return get_content_by_id(ARTIFACTS_PATH, id)

func get_spell(id: String) -> Dictionary:
	return get_content_by_id(SPELLS_PATH, id)

func get_campaign(id: String) -> Dictionary:
	return get_content_by_id(CAMPAIGNS_PATH, id)

func get_scenario(id: String) -> Dictionary:
	var authored := get_authored_scenario(id)
	if not authored.is_empty():
		return authored
	var draft: Dictionary = _generated_scenario_drafts.get(id, {})
	return draft.duplicate(true) if not draft.is_empty() else {}

func get_scenario_dependency_record(id: String) -> Dictionary:
	var authored := get_content_by_id(SCENARIOS_PATH, id)
	if not authored.is_empty():
		return _scenario_dependency_record_from_source(id, authored, false)
	var draft: Dictionary = _generated_scenario_drafts.get(id, {})
	if not draft.is_empty():
		return _scenario_dependency_record_from_source(id, draft, true)
	return {}

func get_authored_scenario(id: String) -> Dictionary:
	var scenario := get_content_by_id(SCENARIOS_PATH, id)
	return scenario.duplicate(true) if not scenario.is_empty() else {}

func has_authored_scenario(id: String) -> bool:
	return not get_authored_scenario(id).is_empty()

func has_generated_scenario_draft(id: String) -> bool:
	return _generated_scenario_drafts.has(id)

func register_generated_scenario_draft(scenario_record: Dictionary, terrain_layers_record: Dictionary) -> Dictionary:
	var scenario_id := String(scenario_record.get("id", "")).strip_edges()
	if scenario_id == "":
		return {"ok": false, "message": "Generated scenario draft is missing an id."}
	if has_authored_scenario(scenario_id):
		return {"ok": false, "message": "Generated scenario id collides with authored content: %s." % scenario_id}
	if not bool(scenario_record.get("generated", false)):
		return {"ok": false, "message": "Generated scenario draft must mark generated=true."}
	var selection: Dictionary = scenario_record.get("selection", {}) if scenario_record.get("selection", {}) is Dictionary else {}
	var availability: Dictionary = selection.get("availability", {}) if selection.get("availability", {}) is Dictionary else {}
	if bool(availability.get("campaign", false)) or bool(availability.get("skirmish", false)):
		return {"ok": false, "message": "Generated scenario draft must not be campaign or skirmish selectable."}

	var scenario_copy: Dictionary = scenario_record.duplicate(true)
	scenario_copy["draft_source"] = "generated_random_map_transient_registry"
	_generated_scenario_drafts[scenario_id] = scenario_copy

	var terrain_copy: Dictionary = terrain_layers_record.duplicate(true)
	terrain_copy["scenario_id"] = scenario_id
	terrain_copy["draft_source"] = "generated_random_map_transient_registry"
	_generated_terrain_layer_drafts[scenario_id] = terrain_copy
	return {
		"ok": true,
		"scenario_id": scenario_id,
		"write_policy": "memory_only_no_authored_json_write",
		"menu_policy": "not_returned_by_authored_scenario_lists",
	}

func unregister_generated_scenario_draft(id: String) -> void:
	_generated_scenario_drafts.erase(id)
	_generated_terrain_layer_drafts.erase(id)

func get_encounter(id: String) -> Dictionary:
	return get_content_by_id(ENCOUNTERS_PATH, id)

func get_content_by_id(path: String, id: String, list_key: String = "items") -> Dictionary:
	var raw := load_json(path)
	if raw.is_empty():
		return {}
	for item in _items_from_raw(raw, list_key):
		if String(item.get("id", "")) == id:
			return item
	return {}

func _scenario_dependency_record_from_source(id: String, scenario: Dictionary, generated: bool) -> Dictionary:
	var objectives = scenario.get("objectives", {})
	var script_hooks = scenario.get("script_hooks", [])
	var record := {
		"id": id,
		"generated": generated,
		"objectives": objectives if objectives is Dictionary else objectives,
		"script_hooks": script_hooks if script_hooks is Array else script_hooks,
	}
	record["dependency_signature"] = str(JSON.stringify({
		"id": id,
		"objectives": record.get("objectives", {}),
		"script_hooks": record.get("script_hooks", []),
	}).hash())
	return record

func _items_from_raw(raw: Dictionary, list_key: String = "items") -> Array:
	var items = raw.get(list_key, raw.get("entries", []))
	return items if items is Array else []

func _index_items(items: Array) -> Dictionary:
	var index := {}
	for item in items:
		if item is Dictionary and item.has("id"):
			index[String(item["id"])] = item
	return index

func _map_object_footprint_area(item: Dictionary) -> int:
	var footprint = item.get("footprint", {})
	if not (footprint is Dictionary):
		return 1
	return max(1, int(footprint.get("width", 1))) * max(1, int(footprint.get("height", 1)))

func _validate_content() -> void:
	var faction_index := _index_items(_items_from_raw(load_json(FACTIONS_PATH)))
	var hero_index := _index_items(_items_from_raw(load_json(HEROES_PATH)))
	var unit_index := _index_items(_items_from_raw(load_json(UNITS_PATH)))
	var army_group_index := _index_items(_items_from_raw(load_json(ARMY_GROUPS_PATH)))
	var town_index := _index_items(_items_from_raw(load_json(TOWNS_PATH)))
	var building_index := _index_items(_items_from_raw(load_json(BUILDINGS_PATH)))
	var resource_site_index := _index_items(_items_from_raw(load_json(RESOURCE_SITES_PATH)))
	var biome_index := _index_items(_items_from_raw(load_json(BIOMES_PATH)))
	var terrain_grammar := load_json(TERRAIN_GRAMMAR_PATH)
	var terrain_layer_index := _index_items(_items_from_raw(load_json(TERRAIN_LAYERS_PATH)))
	var map_object_index := _index_items(_items_from_raw(load_json(MAP_OBJECTS_PATH)))
	var neutral_dwelling_index := _index_items(_items_from_raw(load_json(NEUTRAL_DWELLINGS_PATH)))
	var artifact_index := _index_items(_items_from_raw(load_json(ARTIFACTS_PATH)))
	var spell_index := _index_items(_items_from_raw(load_json(SPELLS_PATH)))
	var campaign_index := _index_items(_items_from_raw(load_json(CAMPAIGNS_PATH)))
	var encounter_index := _index_items(_items_from_raw(load_json(ENCOUNTERS_PATH)))
	var scenario_index := _index_items(_items_from_raw(load_json(SCENARIOS_PATH)))

	_validate_terrain_grammar(terrain_grammar, biome_index)
	for terrain_layer in terrain_layer_index.values():
		_validate_terrain_layer(terrain_layer, scenario_index, terrain_grammar)
	for biome in biome_index.values():
		_validate_biome(biome)
	for resource_site in resource_site_index.values():
		_validate_resource_site(resource_site, unit_index, spell_index, neutral_dwelling_index, army_group_index, encounter_index)
	for map_object in map_object_index.values():
		_validate_map_object(map_object, biome_index, resource_site_index, faction_index)
	for neutral_dwelling in neutral_dwelling_index.values():
		_validate_neutral_dwelling(
			neutral_dwelling,
			unit_index,
			resource_site_index,
			map_object_index,
			army_group_index,
			encounter_index,
			biome_index
		)
	for faction in faction_index.values():
		_validate_faction(faction, town_index, hero_index)
	for hero in hero_index.values():
		_validate_hero(hero, faction_index, spell_index)
	for unit in unit_index.values():
		_validate_unit(unit, faction_index)
	for army_group in army_group_index.values():
		_validate_army_group(army_group, faction_index, unit_index)
	for building in building_index.values():
		_validate_building(building, building_index, unit_index)
	for town in town_index.values():
		_validate_town(town, faction_index, building_index, unit_index, spell_index)
	for artifact in artifact_index.values():
		_validate_artifact(artifact)
	for spell in spell_index.values():
		_validate_spell(spell)
	for encounter in encounter_index.values():
		_validate_encounter(encounter, army_group_index, spell_index)
	for scenario in scenario_index.values():
		_validate_scenario(
			scenario,
			faction_index,
			hero_index,
			army_group_index,
			town_index,
			building_index,
			unit_index,
			resource_site_index,
			artifact_index,
			encounter_index
		)
	for campaign in campaign_index.values():
		_validate_campaign(campaign, scenario_index)

func _supported_resource_site_families() -> Array:
	return [
		"one_shot_pickup",
		"mine",
		"neutral_dwelling",
		"faction_outpost",
		"frontier_shrine",
		"guarded_reward_site",
		"scouting_structure",
		"transit_object",
		"repeatable_service",
	]

func _supported_map_object_families() -> Array:
	return [
		"pickup",
		"mine",
		"neutral_dwelling",
		"neutral_encounter",
		"shrine",
		"guarded_reward_site",
		"scouting_structure",
		"transit_object",
		"repeatable_service",
		"blocker",
		"decoration",
		"faction_landmark",
	]

func _validate_terrain_grammar(grammar: Dictionary, biome_index: Dictionary) -> void:
	if String(grammar.get("rendering_model", "")) != "authored_autotile_layers":
		push_warning("Terrain grammar must declare rendering_model authored_autotile_layers.")
	if String(grammar.get("primary_base_model", "")) != "homm3_local_reference_prototype":
		push_warning("Terrain grammar must declare homm3_local_reference_prototype as the active local prototype base model.")
	if String(grammar.get("generated_source_policy", "")) != "deprecated_not_used_by_homm3_local_prototype":
		push_warning("Terrain grammar must mark generated terrain sheets deprecated and unused by the HoMM3 local prototype.")
	var classes = grammar.get("terrain_classes", [])
	if not (classes is Array) or classes.is_empty():
		push_warning("Terrain grammar must define terrain_classes.")
		return
	var terrain_ids: Array[String] = []
	for terrain_class in classes:
		if not (terrain_class is Dictionary):
			push_warning("Terrain grammar contains a non-dictionary terrain class.")
			continue
		var terrain_id := String(terrain_class.get("id", ""))
		if terrain_id == "":
			push_warning("Terrain grammar terrain classes must define id.")
			continue
		if terrain_id in terrain_ids:
			push_warning("Terrain grammar repeats terrain id %s." % terrain_id)
		terrain_ids.append(terrain_id)
		var biome_id := String(terrain_class.get("biome_id", ""))
		if biome_id == "" or not biome_index.has(biome_id):
			push_warning("Terrain grammar %s references missing biome %s." % [terrain_id, biome_id])
		for key in ["terrain_group", "autotile_family", "style_id", "pattern", "readability_role"]:
			if String(terrain_class.get(key, "")) == "":
				push_warning("Terrain grammar %s must define %s." % [terrain_id, key])
		for color_key in ["base_color", "detail_color", "edge_color"]:
			if not _looks_like_hex_color(String(terrain_class.get(color_key, ""))):
				push_warning("Terrain grammar %s must define %s as a hex color." % [terrain_id, color_key])
		if int(terrain_class.get("transition_priority", -1)) < 0:
			push_warning("Terrain grammar %s must define transition_priority >= 0." % terrain_id)
		var supports = terrain_class.get("supports", [])
		if not (supports is Array) or "edge_transitions" not in supports:
			push_warning("Terrain grammar %s must support edge_transitions." % terrain_id)
		if terrain_id in ["grass", "plains", "forest", "mire", "swamp", "hills", "ridge", "highland"]:
			_validate_terrain_tile_art(terrain_class, terrain_id)

	for required_id in ["grass", "plains", "forest", "mire", "swamp", "hills", "ridge", "highland"]:
		if required_id not in terrain_ids:
			push_warning("Terrain grammar must define authored terrain class %s." % required_id)
	_validate_editor_base_terrain_options(grammar, terrain_ids)

	var overlay_ids: Array[String] = []
	var overlays = grammar.get("overlay_classes", [])
	if not (overlays is Array) or overlays.is_empty():
		push_warning("Terrain grammar must define overlay_classes.")
		return
	for overlay in overlays:
		if not (overlay is Dictionary):
			push_warning("Terrain grammar contains a non-dictionary overlay class.")
			continue
		var overlay_id := String(overlay.get("id", ""))
		if overlay_id == "":
			push_warning("Terrain grammar overlay classes must define id.")
			continue
		overlay_ids.append(overlay_id)
		if String(overlay.get("layer", "")) != "road":
			push_warning("Terrain grammar overlay %s must currently use layer road." % overlay_id)
		for color_key in ["color", "edge_color", "shadow_color", "center_color"]:
			if not _looks_like_hex_color(String(overlay.get(color_key, ""))):
				push_warning("Terrain grammar overlay %s must define %s as a hex color." % [overlay_id, color_key])
		if float(overlay.get("width_fraction", 0.0)) <= 0.0:
			push_warning("Terrain grammar overlay %s must define width_fraction > 0." % overlay_id)
		if overlay_id == "road_dirt":
			_validate_road_overlay_tile_art(overlay, overlay_id)
	if "road_dirt" not in overlay_ids:
		push_warning("Terrain grammar must define the road_dirt overlay.")

func _validate_editor_base_terrain_options(grammar: Dictionary, terrain_ids: Array[String]) -> void:
	var expected_options := [
		{"id": "water", "label": "Water", "family": "water", "atlas": "watrtl"},
		{"id": "snow", "label": "Snow", "family": "snow", "atlas": "snowtl"},
		{"id": "grass", "label": "Grass", "family": "grass", "atlas": "grastl"},
		{"id": "wastes", "label": "Sand", "family": "sand", "atlas": "sandtl"},
		{"id": "badlands", "label": "Dirt", "family": "dirt", "atlas": "dirttl"},
		{"id": "lava", "label": "Lava", "family": "lava", "atlas": "lavatl"},
		{"id": "swamp", "label": "Swamp", "family": "swamp", "atlas": "swmptl"},
		{"id": "rock", "label": "Rock/None", "family": "rock", "atlas": "rocktl"},
	]
	var options = grammar.get("editor_base_terrain_options", [])
	if not (options is Array):
		push_warning("Terrain grammar must define editor_base_terrain_options for the map editor picker.")
		return
	if options.size() != expected_options.size():
		push_warning("Terrain grammar editor_base_terrain_options must expose the HoMM3-style base terrain family set.")
	var homm3 = grammar.get("homm3_local_prototype", {})
	var terrain_id_map = homm3.get("terrain_id_map", {}) if homm3 is Dictionary else {}
	var terrain_families = homm3.get("terrain_families", {}) if homm3 is Dictionary else {}
	for index in range(min(options.size(), expected_options.size())):
		var option = options[index]
		if not (option is Dictionary):
			push_warning("Terrain grammar editor_base_terrain_options contains a non-dictionary option.")
			continue
		var expected: Dictionary = expected_options[index]
		var terrain_id := String(option.get("id", ""))
		var label := String(option.get("label", ""))
		var family_id := String(option.get("homm3_family", ""))
		var atlas_id := String(option.get("homm3_atlas", ""))
		if terrain_id != String(expected.get("id", "")) or label != String(expected.get("label", "")):
			push_warning("Terrain grammar editor base terrain option %d must be %s labeled %s." % [index, String(expected.get("id", "")), String(expected.get("label", ""))])
		if terrain_id not in terrain_ids:
			push_warning("Terrain grammar editor base terrain option %s must reference an authored terrain id." % terrain_id)
		if family_id != String(expected.get("family", "")) or atlas_id != String(expected.get("atlas", "")):
			push_warning("Terrain grammar editor base terrain option %s must map to HoMM3 family %s / atlas %s." % [terrain_id, String(expected.get("family", "")), String(expected.get("atlas", ""))])
		var mapping = terrain_id_map.get(terrain_id, {}) if terrain_id_map is Dictionary else {}
		if mapping is Dictionary and String(mapping.get("family", "")) != family_id:
			push_warning("Terrain grammar editor base terrain option %s must agree with its HoMM3 terrain_id_map family." % terrain_id)
		var family = terrain_families.get(family_id, {}) if terrain_families is Dictionary else {}
		if family is Dictionary and String(family.get("atlas", "")) != atlas_id:
			push_warning("Terrain grammar editor base terrain option %s must agree with its HoMM3 family atlas." % terrain_id)

func _validate_terrain_tile_art(terrain_class: Dictionary, terrain_id: String) -> void:
	var tile_art = terrain_class.get("tile_art", {})
	if not (tile_art is Dictionary):
		push_warning("Terrain grammar %s must define tile_art for the original terrain tile bank." % terrain_id)
		return
	var base_tiles = tile_art.get("base_tiles", [])
	if not (base_tiles is Array) or base_tiles.is_empty():
		push_warning("Terrain grammar %s tile_art must define base_tiles." % terrain_id)
	else:
		for entry in base_tiles:
			if not (entry is Dictionary):
				push_warning("Terrain grammar %s tile_art contains a non-dictionary base tile." % terrain_id)
				continue
			var path := String(entry.get("path", ""))
			if String(entry.get("variant_key", "")) == "":
				push_warning("Terrain grammar %s base tile %s must define variant_key." % [terrain_id, path])
			_validate_art_path(path, "Terrain grammar %s base tile" % terrain_id)
	var edge_overlays = tile_art.get("edge_overlays", {})
	if not (edge_overlays is Dictionary):
		push_warning("Terrain grammar %s tile_art must define edge_overlays." % terrain_id)
		return
	for direction in ["N", "E", "S", "W"]:
		var path := String(edge_overlays.get(direction, ""))
		_validate_art_path(path, "Terrain grammar %s edge overlay %s" % [terrain_id, direction])

func _validate_road_overlay_tile_art(overlay: Dictionary, overlay_id: String) -> void:
	var tile_art = overlay.get("tile_art", {})
	if not (tile_art is Dictionary):
		push_warning("Terrain grammar overlay %s must define tile_art." % overlay_id)
		return
	_validate_art_path(String(tile_art.get("center", "")), "Terrain grammar overlay %s center tile" % overlay_id)
	var connectors = tile_art.get("connectors", {})
	if not (connectors is Dictionary):
		push_warning("Terrain grammar overlay %s tile_art must define connectors." % overlay_id)
		return
	for direction in ["N", "E", "S", "W", "NE", "SE", "SW", "NW"]:
		_validate_art_path(String(connectors.get(direction, "")), "Terrain grammar overlay %s connector %s" % [overlay_id, direction])
	var connection_pieces = tile_art.get("connection_pieces", {})
	if connection_pieces is Dictionary:
		for connection_key in ["NE+SW", "NW+SE"]:
			_validate_art_path(String(connection_pieces.get(connection_key, "")), "Terrain grammar overlay %s connection piece %s" % [overlay_id, connection_key])

func _validate_art_path(path: String, label: String) -> void:
	if path == "":
		push_warning("%s must define a runtime art path." % label)
		return
	if not path.begins_with("res://"):
		push_warning("%s path %s must be a res:// path." % [label, path])
		return
	if not FileAccess.file_exists(path):
		push_warning("%s path %s does not exist." % [label, path])

func _validate_terrain_layer(layer: Dictionary, scenario_index: Dictionary, grammar: Dictionary) -> void:
	var scenario_id := String(layer.get("id", ""))
	var scenario = scenario_index.get(scenario_id, {})
	if scenario_id == "" or scenario.is_empty():
		push_warning("Terrain layer references missing scenario %s." % scenario_id)
		return
	var map_data = scenario.get("map", [])
	var map_size = scenario.get("map_size", {})
	var width := int(map_size.get("width", 0)) if map_size is Dictionary else 0
	var height := int(map_size.get("height", 0)) if map_size is Dictionary else 0
	if width <= 0 and map_data is Array and not map_data.is_empty() and map_data[0] is Array:
		width = map_data[0].size()
	if height <= 0 and map_data is Array:
		height = map_data.size()
	var supported_terrain := _terrain_ids_supporting_roads(grammar)
	var overlay_ids := _terrain_overlay_ids(grammar)
	var roads = layer.get("roads", [])
	if not (roads is Array) or roads.is_empty():
		push_warning("Terrain layer %s must define at least one road overlay." % scenario_id)
		return
	for road in roads:
		if not (road is Dictionary):
			push_warning("Terrain layer %s contains a non-dictionary road." % scenario_id)
			continue
		var road_id := String(road.get("id", ""))
		if road_id == "":
			push_warning("Terrain layer %s road entries must define id." % scenario_id)
		var overlay_id := String(road.get("overlay_id", "road_dirt"))
		if overlay_id not in overlay_ids:
			push_warning("Terrain layer %s road %s references missing overlay %s." % [scenario_id, road_id, overlay_id])
		var tiles = road.get("tiles", [])
		if not (tiles is Array) or tiles.is_empty():
			push_warning("Terrain layer %s road %s must define tiles." % [scenario_id, road_id])
			continue
		for tile in tiles:
			if not (tile is Dictionary):
				push_warning("Terrain layer %s road %s contains a non-dictionary tile." % [scenario_id, road_id])
				continue
			var x := int(tile.get("x", -1))
			var y := int(tile.get("y", -1))
			if x < 0 or y < 0 or x >= width or y >= height:
				push_warning("Terrain layer %s road %s tile %d,%d is out of bounds." % [scenario_id, road_id, x, y])
				continue
			var terrain_id := _terrain_id_from_map(map_data, x, y)
			if terrain_id != "" and terrain_id not in supported_terrain:
				push_warning("Terrain layer %s road %s tile %d,%d uses terrain %s without road_overlay support." % [scenario_id, road_id, x, y, terrain_id])

func _terrain_ids_supporting_roads(grammar: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	var classes = grammar.get("terrain_classes", [])
	if not (classes is Array):
		return ids
	for terrain_class in classes:
		if not (terrain_class is Dictionary):
			continue
		var supports = terrain_class.get("supports", [])
		if supports is Array and "road_overlay" in supports:
			ids.append(String(terrain_class.get("id", "")))
	return ids

func _terrain_overlay_ids(grammar: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	var overlays = grammar.get("overlay_classes", [])
	if not (overlays is Array):
		return ids
	for overlay in overlays:
		if overlay is Dictionary:
			ids.append(String(overlay.get("id", "")))
	return ids

func _terrain_id_from_map(map_data: Variant, x: int, y: int) -> String:
	if not (map_data is Array) or y < 0 or y >= map_data.size():
		return ""
	var row = map_data[y]
	if not (row is Array) or x < 0 or x >= row.size():
		return ""
	return String(row[x])

func _looks_like_hex_color(value: String) -> bool:
	return value.begins_with("#") and value.length() in [7, 9]

func _validate_biome(biome: Dictionary) -> void:
	var biome_id := String(biome.get("id", ""))
	if String(biome.get("name", "")) == "":
		push_warning("Biome %s must define a name." % biome_id)
	var map_tile_ids = biome.get("map_tile_ids", [])
	if not (map_tile_ids is Array) or map_tile_ids.is_empty():
		push_warning("Biome %s must define at least one map_tile_id." % biome_id)
	elif map_tile_ids is Array:
		for tile_id_value in map_tile_ids:
			if String(tile_id_value) == "":
				push_warning("Biome %s cannot contain an empty map_tile_id." % biome_id)
	if int(biome.get("movement_cost", 0)) <= 0:
		push_warning("Biome %s must define movement_cost > 0." % biome_id)
	if not biome.has("passable"):
		push_warning("Biome %s must explicitly define passable." % biome_id)
	for family_id_value in biome.get("allowed_site_families", []):
		var family_id := String(family_id_value)
		if family_id != "" and family_id not in _supported_resource_site_families():
			push_warning("Biome %s references unsupported site family %s." % [biome_id, family_id])
	for list_key in ["encounter_palette_tags", "decoration_palette", "blocker_palette", "route_roles"]:
		var values = biome.get(list_key, [])
		if not (values is Array) or values.is_empty():
			push_warning("Biome %s must define non-empty %s." % [biome_id, list_key])

func _unit_is_neutral(unit: Dictionary) -> bool:
	return bool(unit.get("neutral", false)) or String(unit.get("affiliation", "")) == "neutral"

func _validate_recruit_payload(
	label: String,
	recruits: Variant,
	unit_index: Dictionary,
	require_neutral_units: bool = false
) -> void:
	if recruits == null:
		return
	if not (recruits is Dictionary):
		push_warning("%s must be a dictionary." % label)
		return
	var payload: Dictionary = recruits
	for unit_id_value in payload.keys():
		var unit_id := String(unit_id_value)
		if unit_id == "" or not unit_index.has(unit_id):
			push_warning("%s references missing unit %s." % [label, unit_id])
			continue
		if int(payload[unit_id_value]) <= 0:
			push_warning("%s must define positive recruit counts for %s." % [label, unit_id])
		if require_neutral_units and not _unit_is_neutral(unit_index.get(unit_id, {})):
			push_warning("%s must use neutral units; %s is faction-linked." % [label, unit_id])

func _validate_resource_site(
	site: Dictionary,
	unit_index: Dictionary,
	spell_index: Dictionary,
	neutral_dwelling_index: Dictionary,
	army_group_index: Dictionary,
	encounter_index: Dictionary
) -> void:
	var site_id := String(site.get("id", ""))
	if String(site.get("name", "")) == "":
		push_warning("Resource site %s must define a name." % site_id)
	var family := String(site.get("family", "one_shot_pickup"))
	if family == "":
		family = "one_shot_pickup"
	if family not in _supported_resource_site_families():
		push_warning("Resource site %s uses unsupported family %s." % [site_id, family])

	for resource_key in ["rewards", "claim_rewards", "control_income", "service_cost"]:
		var resources = site.get(resource_key, {})
		if site.has(resource_key) and not (resources is Dictionary):
			push_warning("Resource site %s %s must be a dictionary." % [site_id, resource_key])
		elif resources is Dictionary:
			for key in resources.keys():
				if String(key) == "":
					push_warning("Resource site %s %s cannot contain an empty resource key." % [site_id, resource_key])
				if int(resources[key]) < 0:
					push_warning("Resource site %s %s values must be >= 0 for %s." % [site_id, resource_key, String(key)])

	for recruit_key in ["claim_recruits", "weekly_recruits"]:
		var recruits = site.get(recruit_key, {})
		if site.has(recruit_key) and not (recruits is Dictionary):
			push_warning("Resource site %s %s must be a dictionary." % [site_id, recruit_key])
		elif recruits is Dictionary:
			_validate_recruit_payload("Resource site %s %s" % [site_id, recruit_key], recruits, unit_index)

	var neutral_roster = site.get("neutral_roster", {})
	if site.has("neutral_roster"):
		if not (neutral_roster is Dictionary):
			push_warning("Resource site %s neutral_roster must be a dictionary." % site_id)
		else:
			_validate_recruit_payload(
				"Resource site %s neutral_roster claim_recruits" % site_id,
				neutral_roster.get("claim_recruits", {}),
				unit_index,
				true
			)
			_validate_recruit_payload(
				"Resource site %s neutral_roster weekly_recruits" % site_id,
				neutral_roster.get("weekly_recruits", {}),
				unit_index,
				true
			)
			var guard_army_group_id := String(neutral_roster.get("guard_army_group_id", ""))
			if guard_army_group_id != "" and not army_group_index.has(guard_army_group_id):
				push_warning("Resource site %s neutral_roster references missing guard army group %s." % [site_id, guard_army_group_id])
			var guard_encounter_id := String(neutral_roster.get("guard_encounter_id", ""))
			if guard_encounter_id != "" and not encounter_index.has(guard_encounter_id):
				push_warning("Resource site %s neutral_roster references missing guard encounter %s." % [site_id, guard_encounter_id])

	var spell_id := String(site.get("learn_spell_id", ""))
	if spell_id != "":
		if not spell_index.has(spell_id):
			push_warning("Resource site %s references missing learn_spell_id %s." % [site_id, spell_id])
		elif String(spell_index.get(spell_id, {}).get("context", "")) != "overworld":
			push_warning("Resource site %s learn_spell_id %s must be an overworld spell." % [site_id, spell_id])

	match family:
		"mine":
			if not bool(site.get("persistent_control", false)):
				push_warning("Mine site %s must be persistent-control content." % site_id)
			if not (site.get("control_income", {}) is Dictionary) or site.get("control_income", {}).is_empty():
				push_warning("Mine site %s must define control_income." % site_id)
		"neutral_dwelling":
			var dwelling_family_id := String(site.get("neutral_dwelling_family_id", ""))
			if dwelling_family_id != "" and not neutral_dwelling_index.has(dwelling_family_id):
				push_warning("Neutral dwelling site %s references missing neutral dwelling family %s." % [site_id, dwelling_family_id])
			var scope := String(site.get("dwelling_scope", ""))
			if scope != "" and scope not in ["neutral", "faction_linked", "biome_linked"]:
				push_warning("Neutral dwelling site %s uses unsupported dwelling_scope %s." % [site_id, scope])
			if scope == "neutral" and not (neutral_roster is Dictionary and not neutral_roster.is_empty()):
				push_warning("Neutral dwelling site %s must define neutral_roster when dwelling_scope is neutral." % site_id)
		"scouting_structure":
			if not bool(site.get("persistent_control", false)):
				push_warning("Scouting site %s must be persistent-control content." % site_id)
			if int(site.get("vision_radius", 0)) <= 0:
				push_warning("Scouting site %s must define vision_radius > 0." % site_id)
		"guarded_reward_site":
			if not bool(site.get("guarded", false)):
				push_warning("Guarded reward site %s must set guarded=true." % site_id)
			var guard_profile = site.get("guard_profile", {})
			if not (guard_profile is Dictionary) or guard_profile.is_empty():
				push_warning("Guarded reward site %s must define guard_profile." % site_id)
		"transit_object":
			var transit_profile = site.get("transit_profile", {})
			if not (transit_profile is Dictionary) or transit_profile.is_empty():
				push_warning("Transit site %s must define transit_profile." % site_id)
		"repeatable_service":
			if not bool(site.get("repeatable", false)):
				push_warning("Repeatable service site %s must set repeatable=true." % site_id)
			if int(site.get("visit_cooldown_days", 0)) <= 0:
				push_warning("Repeatable service site %s must define visit_cooldown_days > 0." % site_id)

func _validate_map_object(
	map_object: Dictionary,
	biome_index: Dictionary,
	resource_site_index: Dictionary,
	faction_index: Dictionary
) -> void:
	var object_id := String(map_object.get("id", ""))
	if String(map_object.get("name", "")) == "":
		push_warning("Map object %s must define a name." % object_id)
	var family := String(map_object.get("family", ""))
	if family == "" or family not in _supported_map_object_families():
		push_warning("Map object %s uses unsupported family %s." % [object_id, family])
	var biome_ids = map_object.get("biome_ids", [])
	if not (biome_ids is Array) or biome_ids.is_empty():
		push_warning("Map object %s must define at least one biome_id." % object_id)
	elif biome_ids is Array:
		for biome_id_value in biome_ids:
			var biome_id := String(biome_id_value)
			if biome_id == "" or not biome_index.has(biome_id):
				push_warning("Map object %s references missing biome %s." % [object_id, biome_id])
	var site_id := String(map_object.get("resource_site_id", ""))
	if site_id != "" and not resource_site_index.has(site_id):
		push_warning("Map object %s references missing resource_site_id %s." % [object_id, site_id])
	var faction_id := String(map_object.get("faction_id", ""))
	if faction_id != "" and not faction_index.has(faction_id):
		push_warning("Map object %s references missing faction_id %s." % [object_id, faction_id])
	var footprint = map_object.get("footprint", {})
	if not (footprint is Dictionary):
		push_warning("Map object %s must define a footprint dictionary." % object_id)
	else:
		if int(footprint.get("width", 0)) <= 0 or int(footprint.get("height", 0)) <= 0:
			push_warning("Map object %s footprint dimensions must be > 0." % object_id)
	if not map_object.has("passable"):
		push_warning("Map object %s must explicitly define passable." % object_id)
	if not map_object.has("visitable"):
		push_warning("Map object %s must explicitly define visitable." % object_id)
	var roles = map_object.get("map_roles", [])
	if not (roles is Array) or roles.is_empty():
		push_warning("Map object %s must define non-empty map_roles." % object_id)

func _validate_neutral_dwelling(
	dwelling: Dictionary,
	unit_index: Dictionary,
	resource_site_index: Dictionary,
	map_object_index: Dictionary,
	army_group_index: Dictionary,
	encounter_index: Dictionary,
	biome_index: Dictionary
) -> void:
	var dwelling_id := String(dwelling.get("id", ""))
	if String(dwelling.get("name", "")) == "":
		push_warning("Neutral dwelling %s must define a name." % dwelling_id)
	if String(dwelling.get("summary", "")) == "":
		push_warning("Neutral dwelling %s must define a summary." % dwelling_id)
	for biome_id_value in dwelling.get("biome_ids", []):
		var biome_id := String(biome_id_value)
		if biome_id == "" or not biome_index.has(biome_id):
			push_warning("Neutral dwelling %s references missing biome %s." % [dwelling_id, biome_id])
	var unit_ids = dwelling.get("unit_ids", [])
	if not (unit_ids is Array) or unit_ids.is_empty():
		push_warning("Neutral dwelling %s must define unit_ids." % dwelling_id)
	elif unit_ids is Array:
		for unit_id_value in unit_ids:
			var unit_id := String(unit_id_value)
			if unit_id == "" or not unit_index.has(unit_id):
				push_warning("Neutral dwelling %s references missing unit %s." % [dwelling_id, unit_id])
			elif not _unit_is_neutral(unit_index.get(unit_id, {})):
				push_warning("Neutral dwelling %s unit %s must be authored as neutral." % [dwelling_id, unit_id])
	for site_id_value in dwelling.get("site_ids", []):
		var site_id := String(site_id_value)
		if site_id == "" or not resource_site_index.has(site_id):
			push_warning("Neutral dwelling %s references missing site %s." % [dwelling_id, site_id])
			continue
		var site: Dictionary = resource_site_index.get(site_id, {})
		if String(site.get("family", "")) != "neutral_dwelling":
			push_warning("Neutral dwelling %s site %s must use family neutral_dwelling." % [dwelling_id, site_id])
		if String(site.get("neutral_dwelling_family_id", "")) not in ["", dwelling_id]:
			push_warning("Neutral dwelling %s site %s references a different neutral_dwelling_family_id." % [dwelling_id, site_id])
	for object_id_value in dwelling.get("map_object_ids", []):
		var object_id := String(object_id_value)
		if object_id == "" or not map_object_index.has(object_id):
			push_warning("Neutral dwelling %s references missing map object %s." % [dwelling_id, object_id])
			continue
		if String(map_object_index.get(object_id, {}).get("family", "")) != "neutral_dwelling":
			push_warning("Neutral dwelling %s map object %s must use family neutral_dwelling." % [dwelling_id, object_id])
	for group_id_value in dwelling.get("army_group_ids", []):
		var group_id := String(group_id_value)
		if group_id == "" or not army_group_index.has(group_id):
			push_warning("Neutral dwelling %s references missing army group %s." % [dwelling_id, group_id])
			continue
		if String(army_group_index.get(group_id, {}).get("affiliation", "")) != "neutral":
			push_warning("Neutral dwelling %s army group %s must be neutral." % [dwelling_id, group_id])
	for encounter_id_value in dwelling.get("encounter_ids", []):
		var encounter_id := String(encounter_id_value)
		if encounter_id == "" or not encounter_index.has(encounter_id):
			push_warning("Neutral dwelling %s references missing encounter %s." % [dwelling_id, encounter_id])
			continue
		var encounter_group_id := String(encounter_index.get(encounter_id, {}).get("enemy_group_id", ""))
		if encounter_group_id != "" and army_group_index.has(encounter_group_id):
			if String(army_group_index.get(encounter_group_id, {}).get("affiliation", "")) != "neutral":
				push_warning("Neutral dwelling %s encounter %s must use a neutral army group." % [dwelling_id, encounter_id])

func _validate_faction(faction: Dictionary, town_index: Dictionary, hero_index: Dictionary) -> void:
	var faction_id := String(faction.get("id", ""))
	for town_id_value in faction.get("town_ids", []):
		var town_id := String(town_id_value)
		if town_id != "" and not town_index.has(town_id):
			push_warning("Faction %s references missing town id %s." % [faction_id, town_id])
	for hero_id_value in faction.get("hero_ids", []):
		var hero_id := String(hero_id_value)
		if hero_id != "" and not hero_index.has(hero_id):
			push_warning("Faction %s references missing hero id %s." % [faction_id, hero_id])

func _validate_hero(hero: Dictionary, faction_index: Dictionary, spell_index: Dictionary) -> void:
	var hero_id := String(hero.get("id", ""))
	var faction_id := String(hero.get("faction_id", ""))
	if faction_id == "" or not faction_index.has(faction_id):
		push_warning("Hero %s references missing faction id %s." % [hero_id, faction_id])
	elif hero_id not in faction_index.get(faction_id, {}).get("hero_ids", []):
		push_warning("Hero %s must be listed in faction %s hero_ids." % [hero_id, faction_id])
	if int(hero.get("base_movement", 0)) <= 0:
		push_warning("Hero %s must define base_movement > 0." % hero_id)
	var recruit_cost = hero.get("recruit_cost", {})
	if hero.has("recruit_cost") and not (recruit_cost is Dictionary):
		push_warning("Hero %s recruit_cost must be a dictionary." % hero_id)
	elif recruit_cost is Dictionary:
		for resource_key in recruit_cost.keys():
			if String(resource_key) == "":
				push_warning("Hero %s recruit_cost cannot contain an empty resource key." % hero_id)
			if int(recruit_cost[resource_key]) < 0:
				push_warning("Hero %s recruit_cost must be >= 0 for %s." % [hero_id, String(resource_key)])
	for spell_id_value in hero.get("starting_spell_ids", []):
		var spell_id := String(spell_id_value)
		if spell_id != "" and not spell_index.has(spell_id):
			push_warning("Hero %s references missing starting spell id %s." % [hero_id, spell_id])

func _validate_unit(unit: Dictionary, faction_index: Dictionary) -> void:
	var unit_id := String(unit.get("id", ""))
	var faction_id := String(unit.get("faction_id", ""))
	if _unit_is_neutral(unit):
		if faction_id != "":
			push_warning("Neutral unit %s should not reference faction id %s." % [unit_id, faction_id])
	elif faction_id == "" or not faction_index.has(faction_id):
		push_warning("Unit %s references missing faction id %s." % [unit_id, faction_id])
	if int(unit.get("hp", 0)) <= 0:
		push_warning("Unit %s must define hp > 0." % unit_id)
	if int(unit.get("max_damage", 0)) <= 0:
		push_warning("Unit %s must define max_damage > 0." % unit_id)

func _validate_army_group(army_group: Dictionary, faction_index: Dictionary, unit_index: Dictionary) -> void:
	var group_id := String(army_group.get("id", ""))
	var faction_id := String(army_group.get("faction_id", ""))
	var affiliation := String(army_group.get("affiliation", ""))
	if affiliation == "neutral":
		if faction_id != "":
			push_warning("Neutral army group %s should not reference faction id %s." % [group_id, faction_id])
	elif faction_id == "":
		push_warning("Army group %s must define faction_id or affiliation=neutral." % group_id)
	elif not faction_index.has(faction_id):
		push_warning("Army group %s references missing faction id %s." % [group_id, faction_id])

	var stacks = army_group.get("stacks", [])
	if not (stacks is Array) or stacks.is_empty():
		push_warning("Army group %s has no stacks." % group_id)
		return

	for stack in stacks:
		if not (stack is Dictionary):
			continue
		var unit_id := String(stack.get("unit_id", ""))
		if unit_id == "" or not unit_index.has(unit_id):
			push_warning("Army group %s references missing unit id %s." % [group_id, unit_id])
		elif affiliation == "neutral" and not _unit_is_neutral(unit_index.get(unit_id, {})):
			push_warning("Neutral army group %s stack %s must use neutral units." % [group_id, unit_id])
		if int(stack.get("count", 0)) <= 0:
			push_warning("Army group %s has non-positive stack count for unit %s." % [group_id, unit_id])

func _validate_building(building: Dictionary, building_index: Dictionary, unit_index: Dictionary) -> void:
	var building_id := String(building.get("id", ""))
	var unlock_unit_id := String(building.get("unlock_unit_id", ""))
	if unlock_unit_id != "" and not unit_index.has(unlock_unit_id):
		push_warning("Building %s references missing unlock_unit_id %s." % [building_id, unlock_unit_id])
	if building.has("spell_tier") and int(building.get("spell_tier", 0)) <= 0:
		push_warning("Building %s must define spell_tier > 0 when present." % building_id)

	var requires = building.get("requires", [])
	if requires is Array:
		for requirement in requires:
			var requirement_id := String(requirement)
			if requirement_id != "" and not building_index.has(requirement_id):
				push_warning("Building %s references missing requirement %s." % [building_id, requirement_id])

func _validate_town(
	town: Dictionary,
	faction_index: Dictionary,
	building_index: Dictionary,
	unit_index: Dictionary,
	spell_index: Dictionary
) -> void:
	var town_id := String(town.get("id", ""))
	var faction_id := String(town.get("faction_id", ""))
	if faction_id == "" or not faction_index.has(faction_id):
		push_warning("Town %s references missing faction id %s." % [town_id, faction_id])

	for building_id_value in town.get("starting_building_ids", []):
		var building_id := String(building_id_value)
		if building_id != "" and not building_index.has(building_id):
			push_warning("Town %s references missing starting building id %s." % [town_id, building_id])

	for building_id_value in town.get("buildable_building_ids", []):
		var building_id := String(building_id_value)
		if building_id != "" and not building_index.has(building_id):
			push_warning("Town %s references missing buildable building id %s." % [town_id, building_id])

	for garrison_stack in town.get("garrison", []):
		if not (garrison_stack is Dictionary):
			continue
		var unit_id := String(garrison_stack.get("unit_id", ""))
		if unit_id == "" or not unit_index.has(unit_id):
			push_warning("Town %s references missing garrison unit id %s." % [town_id, unit_id])

	var spell_library = town.get("spell_library", [])
	if spell_library is Array:
		for entry in spell_library:
			if not (entry is Dictionary):
				push_warning("Town %s contains a non-dictionary spell library entry." % town_id)
				continue
			if int(entry.get("tier", 0)) <= 0:
				push_warning("Town %s spell library entries must define tier > 0." % town_id)
			for spell_id_value in entry.get("spell_ids", []):
				var spell_id := String(spell_id_value)
				if spell_id == "" or not spell_index.has(spell_id):
					push_warning("Town %s references missing spell library id %s." % [town_id, spell_id])

func _validate_encounter(encounter: Dictionary, army_group_index: Dictionary, spell_index: Dictionary) -> void:
	var encounter_id := String(encounter.get("id", ""))
	var enemy_group_id := String(encounter.get("enemy_group_id", ""))
	if enemy_group_id == "" or not army_group_index.has(enemy_group_id):
		push_warning("Encounter %s references missing enemy_group_id %s." % [encounter_id, enemy_group_id])
	if int(encounter.get("max_rounds", 0)) <= 0:
		push_warning("Encounter %s must define max_rounds > 0." % encounter_id)
	var commander = encounter.get("enemy_commander", {})
	if encounter.has("enemy_commander") and not (commander is Dictionary):
		push_warning("Encounter %s enemy commander must be a dictionary." % encounter_id)
	if commander is Dictionary and not commander.is_empty():
		if not (commander.get("command", {}) is Dictionary):
			push_warning("Encounter %s enemy commander must define a command dictionary." % encounter_id)
		for spell_id_value in commander.get("starting_spell_ids", []):
			var spell_id := String(spell_id_value)
			if spell_id == "" or not spell_index.has(spell_id):
				push_warning("Encounter %s references missing enemy commander spell id %s." % [encounter_id, spell_id])
				continue
			var spell = spell_index.get(spell_id, {})
			if String(spell.get("context", "")) != "battle":
				push_warning("Encounter %s enemy commander spell %s must be a battle spell." % [encounter_id, spell_id])

func _validate_artifact(artifact: Dictionary) -> void:
	var artifact_id := String(artifact.get("id", ""))
	var slot := String(artifact.get("slot", ""))
	if slot == "":
		push_warning("Artifact %s must define a slot." % artifact_id)
	elif slot not in ["boots", "banner", "armor", "trinket"]:
		push_warning("Artifact %s uses unsupported slot %s." % [artifact_id, slot])

	var bonuses = artifact.get("bonuses", {})
	if not (bonuses is Dictionary) or bonuses.is_empty():
		push_warning("Artifact %s must define at least one bonus." % artifact_id)

func _validate_spell(spell: Dictionary) -> void:
	var spell_id := String(spell.get("id", ""))
	var school_id := String(spell.get("school_id", ""))
	var tier := int(spell.get("tier", 0))
	var accord_family := String(spell.get("accord_family", ""))
	var primary_role := String(spell.get("primary_role", ""))
	var role_categories = spell.get("role_categories", [])
	var context := String(spell.get("context", ""))
	if school_id not in ["beacon", "mire", "lens", "root", "furnace", "veil", "old_measure"]:
		push_warning("Spell %s uses unsupported school_id %s." % [spell_id, school_id])
	if tier < 1 or tier > 5:
		push_warning("Spell %s tier must be between 1 and 5." % spell_id)
	if accord_family == "":
		push_warning("Spell %s must define accord_family." % spell_id)
	if primary_role == "":
		push_warning("Spell %s must define primary_role." % spell_id)
	if not (role_categories is Array) or role_categories.is_empty():
		push_warning("Spell %s must define role_categories." % spell_id)
	elif "economy_map_utility" in role_categories and context != "overworld":
		push_warning("Spell %s economy_map_utility role must use overworld context." % spell_id)
	if context not in ["overworld", "battle"]:
		push_warning("Spell %s uses unsupported context %s." % [spell_id, context])
	if int(spell.get("mana_cost", 0)) <= 0:
		push_warning("Spell %s must define mana_cost > 0." % spell_id)

	var effect = spell.get("effect", {})
	if not (effect is Dictionary):
		push_warning("Spell %s must define an effect payload." % spell_id)
		return

	match String(effect.get("type", "")):
		"restore_movement":
			if int(effect.get("amount", 0)) <= 0:
				push_warning("Spell %s must define restore_movement amount > 0." % spell_id)
		"damage_enemy":
			if int(effect.get("base_damage", 0)) <= 0:
				push_warning("Spell %s must define damage base_damage > 0." % spell_id)
			if int(effect.get("power_scale", -1)) < 0:
				push_warning("Spell %s must define damage power_scale >= 0." % spell_id)
		"defense_buff", "initiative_buff", "attack_buff":
			if int(effect.get("amount", 0)) <= 0:
				push_warning("Spell %s must define buff amount > 0." % spell_id)
			if int(effect.get("duration_rounds", 0)) <= 0:
				push_warning("Spell %s must define duration_rounds > 0." % spell_id)
		"control_enemy":
			var status_effect = effect.get("status_effect", {})
			if not (status_effect is Dictionary) or String(status_effect.get("effect_id", "")) == "":
				push_warning("Spell %s must define control status_effect.effect_id." % spell_id)
			if int(status_effect.get("duration_rounds", 0)) <= 0:
				push_warning("Spell %s must define control duration_rounds > 0." % spell_id)
		"recover_ally":
			if int(effect.get("base_restore", effect.get("amount", 0))) <= 0:
				push_warning("Spell %s must define recovery amount > 0." % spell_id)
			if int(effect.get("duration_rounds", 0)) <= 0:
				push_warning("Spell %s must define duration_rounds > 0." % spell_id)
		"cleanse_ally":
			var cleanse_effect_ids = effect.get("cleanse_effect_ids", [])
			if not (cleanse_effect_ids is Array) or cleanse_effect_ids.is_empty():
				push_warning("Spell %s must define cleanse_effect_ids." % spell_id)
			if int(effect.get("duration_rounds", 0)) <= 0:
				push_warning("Spell %s must define duration_rounds > 0." % spell_id)
		_:
			push_warning("Spell %s uses unsupported effect type %s." % [spell_id, String(effect.get("type", ""))])

func _validate_scenario(
	scenario: Dictionary,
	faction_index: Dictionary,
	hero_index: Dictionary,
	army_group_index: Dictionary,
	town_index: Dictionary,
	building_index: Dictionary,
	unit_index: Dictionary,
	resource_site_index: Dictionary,
	artifact_index: Dictionary,
	encounter_index: Dictionary
) -> void:
	var scenario_id := String(scenario.get("id", ""))
	var map = scenario.get("map", [])
	var map_height: int = map.size() if map is Array else 0
	var map_width := 0
	if map_height > 0 and map[0] is Array:
		map_width = map[0].size()

	var map_size_value = scenario.get("map_size", {})
	var map_size: Dictionary = map_size_value if map_size_value is Dictionary else {}
	if not map_size.is_empty():
		var declared_width := int(map_size.get("width", map_width))
		var declared_height := int(map_size.get("height", map_height))
		if declared_width != map_width or declared_height != map_height:
			push_warning(
				"Scenario %s map_size does not match authored map dimensions (%d x %d)."
				% [scenario_id, map_width, map_height]
			)

	var start_value = scenario.get("start", {})
	var start: Dictionary = start_value if start_value is Dictionary else {}
	if not start.is_empty() and map_width > 0 and map_height > 0:
		var start_x := int(start.get("x", -1))
		var start_y := int(start.get("y", -1))
		if start_x < 0 or start_y < 0 or start_x >= map_width or start_y >= map_height:
			push_warning("Scenario %s has an out-of-bounds start position." % scenario_id)

	var faction_id := String(scenario.get("player_faction_id", ""))
	if faction_id == "" or not faction_index.has(faction_id):
		push_warning("Scenario %s references missing player_faction_id %s." % [scenario_id, faction_id])

	var hero_id := String(scenario.get("hero_id", ""))
	if hero_id == "" or not hero_index.has(hero_id):
		push_warning("Scenario %s references missing hero_id %s." % [scenario_id, hero_id])
	elif faction_index.has(faction_id) and hero_id not in faction_index.get(faction_id, {}).get("hero_ids", []):
		push_warning("Scenario %s hero_id %s must belong to player faction %s." % [scenario_id, hero_id, faction_id])

	var hero_starts = scenario.get("hero_starts", [])
	if scenario.has("hero_starts") and (not (hero_starts is Array) or hero_starts.is_empty()):
		push_warning("Scenario %s hero_starts must be a non-empty array when present." % scenario_id)
	elif hero_starts is Array and not hero_starts.is_empty():
		var seen_hero_starts: Array[String] = []
		for hero_id_value in hero_starts:
			var start_hero_id := String(hero_id_value)
			if start_hero_id == "" or not hero_index.has(start_hero_id):
				push_warning("Scenario %s hero_starts references missing hero %s." % [scenario_id, start_hero_id])
				continue
			if faction_index.has(faction_id) and start_hero_id not in faction_index.get(faction_id, {}).get("hero_ids", []):
				push_warning("Scenario %s hero_starts hero %s must belong to player faction %s." % [scenario_id, start_hero_id, faction_id])
			if start_hero_id in seen_hero_starts:
				push_warning("Scenario %s hero_starts repeats hero %s." % [scenario_id, start_hero_id])
			else:
				seen_hero_starts.append(start_hero_id)
		if hero_id != "" and hero_id not in seen_hero_starts:
			push_warning("Scenario %s hero_starts must include primary hero_id %s." % [scenario_id, hero_id])

	var player_army_id := String(scenario.get("player_army_id", ""))
	if player_army_id == "" or not army_group_index.has(player_army_id):
		push_warning("Scenario %s references missing player_army_id %s." % [scenario_id, player_army_id])

	var selection = scenario.get("selection", {})
	if not (selection is Dictionary) or selection.is_empty():
		push_warning("Scenario %s must define selection metadata for skirmish/setup UX." % scenario_id)
	else:
		if String(selection.get("summary", "")) == "":
			push_warning("Scenario %s selection metadata must define summary." % scenario_id)
		if String(selection.get("recommended_difficulty", "")) not in ["story", "normal", "hard"]:
			push_warning("Scenario %s selection metadata must define a supported recommended_difficulty." % scenario_id)
		if String(selection.get("map_size_label", "")) == "":
			push_warning("Scenario %s selection metadata must define map_size_label." % scenario_id)
		if String(selection.get("player_summary", "")) == "":
			push_warning("Scenario %s selection metadata must define player_summary." % scenario_id)
		if String(selection.get("enemy_summary", "")) == "":
			push_warning("Scenario %s selection metadata must define enemy_summary." % scenario_id)
		var availability = selection.get("availability", {})
		if not (availability is Dictionary):
			push_warning("Scenario %s selection metadata must define an availability dictionary." % scenario_id)
		else:
			var campaign_enabled := bool(availability.get("campaign", false))
			var skirmish_enabled := bool(availability.get("skirmish", false))
			if not campaign_enabled and not skirmish_enabled:
				push_warning("Scenario %s must be available to at least one launch mode." % scenario_id)
			var campaign_id := _campaign_id_for_scenario(scenario_id)
			if campaign_enabled != (campaign_id != ""):
				push_warning("Scenario %s campaign availability must match authored campaign membership." % scenario_id)

	for placement in scenario.get("towns", []):
		if not (placement is Dictionary):
			continue
		var town_id := String(placement.get("town_id", ""))
		if town_id == "" or not town_index.has(town_id):
			push_warning("Scenario %s references missing town id %s." % [scenario_id, town_id])

	for placement in scenario.get("resource_nodes", []):
		if not (placement is Dictionary):
			continue
		var site_id := String(placement.get("site_id", ""))
		if site_id == "" or not resource_site_index.has(site_id):
			push_warning("Scenario %s references missing resource site id %s." % [scenario_id, site_id])

	var artifact_placement_ids: Array[String] = []
	var authored_artifact_ids: Array[String] = []
	for placement in scenario.get("artifact_nodes", []):
		if not (placement is Dictionary):
			continue
		var placement_id := String(placement.get("placement_id", ""))
		if placement_id == "":
			push_warning("Scenario %s artifact placements must define placement_id." % scenario_id)
		elif placement_id in artifact_placement_ids:
			push_warning("Scenario %s repeats artifact placement_id %s." % [scenario_id, placement_id])
		else:
			artifact_placement_ids.append(placement_id)
		var artifact_id := String(placement.get("artifact_id", ""))
		if artifact_id == "" or not artifact_index.has(artifact_id):
			push_warning("Scenario %s references missing artifact id %s." % [scenario_id, artifact_id])
		elif artifact_id in authored_artifact_ids:
			push_warning("Scenario %s repeats artifact id %s in authored artifact nodes." % [scenario_id, artifact_id])
		else:
			authored_artifact_ids.append(artifact_id)
		var artifact_x := int(placement.get("x", -1))
		var artifact_y := int(placement.get("y", -1))
		if artifact_x < 0 or artifact_y < 0 or artifact_x >= map_width or artifact_y >= map_height:
			push_warning("Scenario %s has an out-of-bounds artifact placement." % scenario_id)

	for placement in scenario.get("encounters", []):
		if not (placement is Dictionary):
			continue
		var encounter_id := String(placement.get("encounter_id", placement.get("id", "")))
		if encounter_id == "" or not encounter_index.has(encounter_id):
			push_warning("Scenario %s references missing encounter id %s." % [scenario_id, encounter_id])

	var town_placement_ids: Array[String] = []
	for placement in scenario.get("towns", []):
		if placement is Dictionary:
			town_placement_ids.append(String(placement.get("placement_id", "")))

	var encounter_placement_ids: Array[String] = []
	for placement in scenario.get("encounters", []):
		if placement is Dictionary:
			_append_unique_string(encounter_placement_ids, String(placement.get("placement_id", "")))

	var objectives = scenario.get("objectives", {})
	var objective_ids: Array[String] = []
	if objectives is Dictionary:
		for objective in objectives.get("victory", []):
			if objective is Dictionary:
				_append_unique_string(objective_ids, String(objective.get("id", "")))
				_validate_objective(scenario_id, objective, faction_index, town_placement_ids, encounter_placement_ids)
		for objective in objectives.get("defeat", []):
			if objective is Dictionary:
				_append_unique_string(objective_ids, String(objective.get("id", "")))
				_validate_objective(scenario_id, objective, faction_index, town_placement_ids, encounter_placement_ids)

	var script_hooks = scenario.get("script_hooks", [])
	if scenario.has("script_hooks") and not (script_hooks is Array):
		push_warning("Scenario %s script_hooks must be an array." % scenario_id)
	elif script_hooks is Array:
		_append_hook_spawn_placements(script_hooks, "spawn_encounter", encounter_placement_ids)
		for hook in script_hooks:
			if hook is Dictionary:
				_validate_script_hook(
					scenario_id,
					hook,
					faction_index,
					unit_index,
					building_index,
					resource_site_index,
					artifact_index,
					encounter_index,
					town_placement_ids,
					encounter_placement_ids,
					objective_ids,
					map_width,
					map_height
				)

	var enemy_factions = scenario.get("enemy_factions", [])
	if enemy_factions is Array:
		for enemy_faction in enemy_factions:
			if enemy_faction is Dictionary:
				_validate_enemy_faction(
					scenario_id,
					enemy_faction,
					faction_index,
					encounter_index,
					town_placement_ids,
					map_width,
					map_height
				)

func _validate_objective(
	scenario_id: String,
	objective: Dictionary,
	faction_index: Dictionary,
	town_placement_ids: Array[String],
	encounter_placement_ids: Array[String]
) -> void:
	var objective_type := String(objective.get("type", ""))
	match objective_type:
		"town_owned_by_player", "town_not_owned_by_player":
			var placement_id := String(objective.get("placement_id", ""))
			if placement_id == "" or placement_id not in town_placement_ids:
				push_warning("Scenario %s objective %s references missing placement_id %s." % [scenario_id, String(objective.get("id", "")), placement_id])
		"flag_true":
			if String(objective.get("flag", "")) == "":
				push_warning("Scenario %s objective %s must define a flag." % [scenario_id, String(objective.get("id", ""))])
		"session_flag_equals":
			if String(objective.get("flag", "")) == "":
				push_warning("Scenario %s objective %s must define a flag." % [scenario_id, String(objective.get("id", ""))])
		"enemy_pressure_at_least":
			var faction_id := String(objective.get("faction_id", ""))
			if faction_id == "" or not faction_index.has(faction_id):
				push_warning("Scenario %s objective %s references missing faction_id %s." % [scenario_id, String(objective.get("id", "")), faction_id])
			if int(objective.get("threshold", 0)) <= 0:
				push_warning("Scenario %s objective %s must define threshold > 0." % [scenario_id, String(objective.get("id", ""))])
		"encounter_resolved":
			var encounter_placement_id := String(objective.get("placement_id", ""))
			if encounter_placement_id == "" or encounter_placement_id not in encounter_placement_ids:
				push_warning("Scenario %s objective %s references missing encounter placement %s." % [scenario_id, String(objective.get("id", "")), encounter_placement_id])
		"hook_fired":
			if String(objective.get("hook_id", "")) == "":
				push_warning("Scenario %s objective %s must define hook_id." % [scenario_id, String(objective.get("id", ""))])
		"day_at_least":
			if int(objective.get("day", 0)) <= 0:
				push_warning("Scenario %s objective %s must define day > 0." % [scenario_id, String(objective.get("id", ""))])
		_:
			push_warning("Scenario %s has unsupported objective type %s." % [scenario_id, objective_type])

func _validate_script_hook(
	scenario_id: String,
	hook: Dictionary,
	faction_index: Dictionary,
	unit_index: Dictionary,
	building_index: Dictionary,
	resource_site_index: Dictionary,
	artifact_index: Dictionary,
	encounter_index: Dictionary,
	town_placement_ids: Array[String],
	encounter_placement_ids: Array[String],
	objective_ids: Array[String],
	map_width: int,
	map_height: int
) -> void:
	var hook_id := String(hook.get("id", ""))
	if hook_id == "":
		push_warning("Scenario %s contains a script hook without an id." % scenario_id)
	var conditions = hook.get("conditions", [])
	if not (conditions is Array) or conditions.is_empty():
		push_warning("Scenario %s hook %s must define at least one condition." % [scenario_id, hook_id])
	elif conditions is Array:
		for condition in conditions:
			if condition is Dictionary:
				_validate_script_condition(
					scenario_id,
					hook_id,
					condition,
					faction_index,
					town_placement_ids,
					encounter_placement_ids,
					objective_ids
				)
			else:
				push_warning("Scenario %s hook %s contains a non-dictionary condition." % [scenario_id, hook_id])

	var effects = hook.get("effects", [])
	if not (effects is Array) or effects.is_empty():
		push_warning("Scenario %s hook %s must define at least one effect." % [scenario_id, hook_id])
	elif effects is Array:
		for effect in effects:
			if effect is Dictionary:
				_validate_script_effect(
					scenario_id,
					hook_id,
					effect,
					faction_index,
					unit_index,
					building_index,
					resource_site_index,
					artifact_index,
					encounter_index,
					town_placement_ids,
					map_width,
					map_height
				)
			else:
				push_warning("Scenario %s hook %s contains a non-dictionary effect." % [scenario_id, hook_id])

func _validate_script_condition(
	scenario_id: String,
	hook_id: String,
	condition: Dictionary,
	faction_index: Dictionary,
	town_placement_ids: Array[String],
	encounter_placement_ids: Array[String],
	objective_ids: Array[String]
) -> void:
	var condition_type := String(condition.get("type", ""))
	match condition_type:
		"day_at_least":
			if int(condition.get("day", 0)) <= 0:
				push_warning("Scenario %s hook %s day_at_least conditions must define day > 0." % [scenario_id, hook_id])
		"town_owned_by_player", "town_not_owned_by_player":
			var placement_id := String(condition.get("placement_id", ""))
			if placement_id == "" or placement_id not in town_placement_ids:
				push_warning("Scenario %s hook %s references missing town placement %s." % [scenario_id, hook_id, placement_id])
		"flag_true", "session_flag_equals":
			if String(condition.get("flag", "")) == "":
				push_warning("Scenario %s hook %s %s conditions must define a flag." % [scenario_id, hook_id, condition_type])
		"enemy_pressure_at_least":
			var faction_id := String(condition.get("faction_id", ""))
			if faction_id == "" or not faction_index.has(faction_id):
				push_warning("Scenario %s hook %s references missing faction %s." % [scenario_id, hook_id, faction_id])
			if int(condition.get("threshold", 0)) <= 0:
				push_warning("Scenario %s hook %s enemy_pressure_at_least conditions must define threshold > 0." % [scenario_id, hook_id])
		"encounter_resolved":
			var encounter_placement_id := String(condition.get("placement_id", ""))
			if encounter_placement_id == "" or encounter_placement_id not in encounter_placement_ids:
				push_warning("Scenario %s hook %s references missing encounter placement %s." % [scenario_id, hook_id, encounter_placement_id])
		"objective_met", "objective_not_met":
			var objective_id := String(condition.get("objective_id", ""))
			if objective_id == "" or objective_id not in objective_ids:
				push_warning("Scenario %s hook %s references missing objective id %s." % [scenario_id, hook_id, objective_id])
		"active_raid_count_at_least", "active_raid_count_at_most":
			var raid_faction_id := String(condition.get("faction_id", ""))
			if raid_faction_id == "" or not faction_index.has(raid_faction_id):
				push_warning("Scenario %s hook %s references missing faction %s." % [scenario_id, hook_id, raid_faction_id])
			if int(condition.get("threshold", -1)) < 0:
				push_warning("Scenario %s hook %s %s conditions must define threshold >= 0." % [scenario_id, hook_id, condition_type])
		"hook_fired", "hook_not_fired":
			if String(condition.get("hook_id", "")) == "":
				push_warning("Scenario %s hook %s %s conditions must define hook_id." % [scenario_id, hook_id, condition_type])
		_:
			push_warning("Scenario %s hook %s has unsupported condition type %s." % [scenario_id, hook_id, condition_type])

func _validate_script_effect(
	scenario_id: String,
	hook_id: String,
	effect: Dictionary,
	faction_index: Dictionary,
	unit_index: Dictionary,
	building_index: Dictionary,
	resource_site_index: Dictionary,
	artifact_index: Dictionary,
	encounter_index: Dictionary,
	town_placement_ids: Array[String],
	map_width: int,
	map_height: int
) -> void:
	var effect_type := String(effect.get("type", ""))
	match effect_type:
		"message":
			if String(effect.get("text", "")) == "":
				push_warning("Scenario %s hook %s message effects must define text." % [scenario_id, hook_id])
		"set_flag":
			if String(effect.get("flag", "")) == "":
				push_warning("Scenario %s hook %s set_flag effects must define a flag." % [scenario_id, hook_id])
		"add_resources":
			var resources = effect.get("resources", {})
			if not (resources is Dictionary) or resources.is_empty():
				push_warning("Scenario %s hook %s add_resources effects must define a non-empty resources dictionary." % [scenario_id, hook_id])
		"award_experience":
			if int(effect.get("amount", 0)) <= 0:
				push_warning("Scenario %s hook %s award_experience effects must define amount > 0." % [scenario_id, hook_id])
		"award_artifact":
			var award_artifact_id := String(effect.get("artifact_id", ""))
			if award_artifact_id == "" or not artifact_index.has(award_artifact_id):
				push_warning("Scenario %s hook %s references missing award artifact id %s." % [scenario_id, hook_id, award_artifact_id])
		"spawn_resource_node":
			_validate_script_placement(
				scenario_id,
				hook_id,
				effect.get("placement", {}),
				"site_id",
				resource_site_index,
				map_width,
				map_height
			)
		"spawn_artifact_node":
			_validate_script_placement(
				scenario_id,
				hook_id,
				effect.get("placement", {}),
				"artifact_id",
				artifact_index,
				map_width,
				map_height
			)
		"spawn_encounter":
			_validate_script_placement(
				scenario_id,
				hook_id,
				effect.get("placement", {}),
				"encounter_id",
				encounter_index,
				map_width,
				map_height
			)
		"town_add_building":
			var building_placement_id := String(effect.get("placement_id", ""))
			if building_placement_id == "" or building_placement_id not in town_placement_ids:
				push_warning("Scenario %s hook %s references missing town placement %s." % [scenario_id, hook_id, building_placement_id])
			var building_id := String(effect.get("building_id", ""))
			if building_id == "" or not building_index.has(building_id):
				push_warning("Scenario %s hook %s references missing building id %s." % [scenario_id, hook_id, building_id])
		"town_add_recruits":
			var recruit_placement_id := String(effect.get("placement_id", ""))
			if recruit_placement_id == "" or recruit_placement_id not in town_placement_ids:
				push_warning("Scenario %s hook %s references missing town placement %s." % [scenario_id, hook_id, recruit_placement_id])
			var recruits = effect.get("recruits", {})
			if not (recruits is Dictionary) or recruits.is_empty():
				push_warning("Scenario %s hook %s town_add_recruits effects must define recruits." % [scenario_id, hook_id])
			elif recruits is Dictionary:
				for unit_id_value in recruits.keys():
					var unit_id := String(unit_id_value)
					if unit_id == "" or not unit_index.has(unit_id):
						push_warning("Scenario %s hook %s references missing recruit unit id %s." % [scenario_id, hook_id, unit_id])
					if int(recruits[unit_id_value]) <= 0:
						push_warning("Scenario %s hook %s recruit counts must be > 0 for unit %s." % [scenario_id, hook_id, unit_id])
		"add_enemy_pressure":
			var faction_id := String(effect.get("faction_id", ""))
			if faction_id == "" or not faction_index.has(faction_id):
				push_warning("Scenario %s hook %s references missing faction %s." % [scenario_id, hook_id, faction_id])
			if int(effect.get("amount", 0)) <= 0 and int(effect.get("minimum", 0)) <= 0:
				push_warning("Scenario %s hook %s add_enemy_pressure effects must define amount > 0 or minimum > 0." % [scenario_id, hook_id])
		_:
			push_warning("Scenario %s hook %s has unsupported effect type %s." % [scenario_id, hook_id, effect_type])

func _validate_script_placement(
	scenario_id: String,
	hook_id: String,
	placement: Variant,
	reference_key: String,
	reference_index: Dictionary,
	map_width: int,
	map_height: int
) -> void:
	if not (placement is Dictionary):
		push_warning("Scenario %s hook %s contains a non-dictionary scripted placement." % [scenario_id, hook_id])
		return
	var placement_id := String(placement.get("placement_id", ""))
	if placement_id == "":
		push_warning("Scenario %s hook %s scripted placements must define placement_id." % [scenario_id, hook_id])
	var reference_id := String(placement.get(reference_key, ""))
	if reference_id == "" or not reference_index.has(reference_id):
		push_warning("Scenario %s hook %s references missing %s %s." % [scenario_id, hook_id, reference_key, reference_id])
	var x := int(placement.get("x", -1))
	var y := int(placement.get("y", -1))
	if x < 0 or y < 0 or x >= map_width or y >= map_height:
		push_warning("Scenario %s hook %s contains an out-of-bounds scripted placement." % [scenario_id, hook_id])

func _append_hook_spawn_placements(hooks: Array, effect_type: String, placement_ids: Array[String]) -> void:
	for hook in hooks:
		if not (hook is Dictionary):
			continue
		for effect in hook.get("effects", []):
			if not (effect is Dictionary) or String(effect.get("type", "")) != effect_type:
				continue
			var placement = effect.get("placement", {})
			if placement is Dictionary:
				_append_unique_string(placement_ids, String(placement.get("placement_id", "")))

func _append_unique_string(values: Array[String], value: String) -> void:
	if value != "" and value not in values:
		values.append(value)

func _validate_campaign(campaign: Dictionary, scenario_index: Dictionary) -> void:
	var campaign_id := String(campaign.get("id", ""))
	var scenarios = campaign.get("scenarios", [])
	if not (scenarios is Array) or scenarios.is_empty():
		push_warning("Campaign %s must define at least one scenario entry." % campaign_id)
		return

	var seen_scenarios: Array[String] = []
	for scenario_entry in scenarios:
		if not (scenario_entry is Dictionary):
			push_warning("Campaign %s contains a non-dictionary scenario entry." % campaign_id)
			continue
		var scenario_id := String(scenario_entry.get("scenario_id", ""))
		if scenario_id == "" or not scenario_index.has(scenario_id):
			push_warning("Campaign %s references missing scenario %s." % [campaign_id, scenario_id])
		elif scenario_id in seen_scenarios:
			push_warning("Campaign %s repeats scenario %s." % [campaign_id, scenario_id])
		else:
			seen_scenarios.append(scenario_id)

		_validate_campaign_requirements(campaign_id, scenario_id, scenario_entry, scenario_index)
		_validate_campaign_carryover(campaign_id, scenario_id, scenario_entry, scenario_index)

	var starting_scenario_id := String(campaign.get("starting_scenario_id", ""))
	if starting_scenario_id == "" or starting_scenario_id not in scenario_index:
		push_warning("Campaign %s must define a valid starting_scenario_id." % campaign_id)
	elif starting_scenario_id not in seen_scenarios:
		push_warning("Campaign %s starting_scenario_id %s is not listed in campaign scenarios." % [campaign_id, starting_scenario_id])

func _validate_campaign_requirements(
	campaign_id: String,
	scenario_id: String,
	scenario_entry: Dictionary,
	scenario_index: Dictionary
) -> void:
	var requirements = scenario_entry.get("unlock_requirements", [])
	if scenario_entry.has("unlock_requirements") and not (requirements is Array):
		push_warning("Campaign %s scenario %s unlock_requirements must be an array." % [campaign_id, scenario_id])
		return
	if not (requirements is Array):
		return
	for requirement in requirements:
		if not (requirement is Dictionary):
			push_warning("Campaign %s scenario %s contains a non-dictionary unlock requirement." % [campaign_id, scenario_id])
			continue
		match String(requirement.get("type", "")):
			"scenario_status":
				var dependency_id := String(requirement.get("scenario_id", ""))
				if dependency_id == "" or not scenario_index.has(dependency_id):
					push_warning("Campaign %s scenario %s references missing unlock dependency %s." % [campaign_id, scenario_id, dependency_id])
				var required_status := String(requirement.get("status", ""))
				if required_status not in ["victory", "defeat"]:
					push_warning("Campaign %s scenario %s uses unsupported unlock status %s." % [campaign_id, scenario_id, required_status])
			"scenario_flag_true":
				var flag_dependency_id := String(requirement.get("scenario_id", ""))
				if flag_dependency_id == "" or not scenario_index.has(flag_dependency_id):
					push_warning("Campaign %s scenario %s references missing flag dependency scenario %s." % [campaign_id, scenario_id, flag_dependency_id])
				if String(requirement.get("flag", "")) == "":
					push_warning("Campaign %s scenario %s scenario_flag_true requirements must define a flag." % [campaign_id, scenario_id])
			_:
				push_warning("Campaign %s scenario %s uses unsupported unlock requirement type %s." % [campaign_id, scenario_id, String(requirement.get("type", ""))])

func _validate_campaign_carryover(
	campaign_id: String,
	scenario_id: String,
	scenario_entry: Dictionary,
	scenario_index: Dictionary
) -> void:
	var carryover_export = scenario_entry.get("carryover_export", {})
	if scenario_entry.has("carryover_export") and not (carryover_export is Dictionary):
		push_warning("Campaign %s scenario %s carryover_export must be a dictionary." % [campaign_id, scenario_id])
	elif carryover_export is Dictionary and not carryover_export.is_empty():
		var resource_fraction := float(carryover_export.get("resource_fraction", 0.0))
		if resource_fraction < 0.0 or resource_fraction > 1.0:
			push_warning("Campaign %s scenario %s carryover_export resource_fraction must be between 0 and 1." % [campaign_id, scenario_id])
		for flag_id_value in carryover_export.get("flag_ids", []):
			if String(flag_id_value) == "":
				push_warning("Campaign %s scenario %s carryover_export cannot contain empty flag ids." % [campaign_id, scenario_id])

	var carryover_import = scenario_entry.get("carryover_import", {})
	if scenario_entry.has("carryover_import") and not (carryover_import is Dictionary):
		push_warning("Campaign %s scenario %s carryover_import must be a dictionary." % [campaign_id, scenario_id])
	elif carryover_import is Dictionary and not carryover_import.is_empty():
		var from_scenario_id := String(carryover_import.get("from_scenario_id", ""))
		if from_scenario_id == "" or not scenario_index.has(from_scenario_id):
			push_warning("Campaign %s scenario %s carryover_import references missing from_scenario_id %s." % [campaign_id, scenario_id, from_scenario_id])

func _campaign_id_for_scenario(scenario_id: String) -> String:
	if scenario_id == "":
		return ""
	for campaign in load_json(CAMPAIGNS_PATH).get("items", []):
		if not (campaign is Dictionary):
			continue
		for scenario_entry in campaign.get("scenarios", []):
			if scenario_entry is Dictionary and String(scenario_entry.get("scenario_id", "")) == scenario_id:
				return String(campaign.get("id", ""))
	return ""

func _validate_enemy_faction(
	scenario_id: String,
	enemy_faction: Dictionary,
	faction_index: Dictionary,
	encounter_index: Dictionary,
	town_placement_ids: Array[String],
	map_width: int,
	map_height: int
) -> void:
	var faction_id := String(enemy_faction.get("faction_id", ""))
	if faction_id == "" or not faction_index.has(faction_id):
		push_warning("Scenario %s references missing enemy faction id %s." % [scenario_id, faction_id])

	if int(enemy_faction.get("raid_threshold", 0)) <= 0:
		push_warning("Scenario %s enemy faction %s must define raid_threshold > 0." % [scenario_id, faction_id])

	var encounter_pool = enemy_faction.get("raid_encounter_ids", [])
	if encounter_pool is Array:
		for encounter_id_value in encounter_pool:
			var encounter_id := String(encounter_id_value)
			if encounter_id == "" or not encounter_index.has(encounter_id):
				push_warning("Scenario %s enemy faction %s references missing raid encounter id %s." % [scenario_id, faction_id, encounter_id])

	var spawn_points = enemy_faction.get("spawn_points", [])
	if spawn_points is Array:
		for spawn_point in spawn_points:
			if not (spawn_point is Dictionary):
				continue
			var x := int(spawn_point.get("x", -1))
			var y := int(spawn_point.get("y", -1))
			if x < 0 or y < 0 or x >= map_width or y >= map_height:
				push_warning("Scenario %s enemy faction %s has an out-of-bounds spawn point." % [scenario_id, faction_id])

	var siege_target := String(enemy_faction.get("siege_target_placement_id", ""))
	if siege_target != "" and siege_target not in town_placement_ids:
		push_warning("Scenario %s enemy faction %s references missing siege target %s." % [scenario_id, faction_id, siege_target])
