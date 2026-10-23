class_name HeroesContentService
extends Node

const CONTENT_DIR := "res://content"
# Authored scenarios, campaigns and their terrain layers are archived (owner,
# 2026-10-08; archive/authored-scenarios-2026-10-08/README.md). They are not
# offered for play, but stay loadable by id as test setups and for old saves.
# Shipped builds may leave the archive out; it then reads as empty.
const AUTHORED_ARCHIVE_DIR := "res://archive/authored-scenarios-2026-10-08"
const SCENARIOS_PATH := "%s/scenarios.json" % AUTHORED_ARCHIVE_DIR
const ENCOUNTERS_PATH := "%s/encounters.json" % CONTENT_DIR
# Generated-guard companies carry their own encounter definitions
# (tools/build_generated_neutral_companies.py); get_encounter falls back to them.
const GENERATED_COMPANIES_PATH := "%s/generated_neutral_companies.json" % CONTENT_DIR
const GENERATED_COMPANY_ENCOUNTER_PREFIX := "encounter_company_"
const HEROES_PATH := "%s/heroes.json" % CONTENT_DIR
const HERO_ART_PATH := "%s/hero_art_manifest.json" % CONTENT_DIR
const FACTIONS_PATH := "%s/factions.json" % CONTENT_DIR
const FACTION_CRESTS_PATH := "%s/faction_crests.json" % CONTENT_DIR
const UNITS_PATH := "%s/units.json" % CONTENT_DIR
const UNIT_ART_PATH := "%s/unit_art_manifest.json" % CONTENT_DIR
const UNIT_ANIMATION_PATH := "%s/unit_animation_manifest.json" % CONTENT_DIR
const ARMY_GROUPS_PATH := "%s/army_groups.json" % CONTENT_DIR
const TOWNS_PATH := "%s/towns.json" % CONTENT_DIR
const BUILDINGS_PATH := "%s/buildings.json" % CONTENT_DIR
const BUILDING_ART_PATH := "%s/building_art_manifest.json" % CONTENT_DIR
const RESOURCES_PATH := "%s/resources.json" % CONTENT_DIR
const RESOURCE_SITES_PATH := "%s/resource_sites.json" % CONTENT_DIR
const BIOMES_PATH := "%s/biomes.json" % CONTENT_DIR
const TERRAIN_GRAMMAR_PATH := "%s/terrain_grammar.json" % CONTENT_DIR
const TERRAIN_LAYERS_PATH := "%s/terrain_layers.json" % AUTHORED_ARCHIVE_DIR
const MAP_OBJECTS_PATH := "%s/map_objects.json" % CONTENT_DIR
const NEUTRAL_DWELLINGS_PATH := "%s/neutral_dwellings.json" % CONTENT_DIR
const ARTIFACTS_PATH := "%s/artifacts.json" % CONTENT_DIR
const SPELLS_PATH := "%s/spells.json" % CONTENT_DIR
const SPELL_ICONS_PATH := "%s/spell_icons.json" % CONTENT_DIR
const SPELL_SCHOOL_ICONS_PATH := "%s/spell_school_icons.json" % CONTENT_DIR
const BUILDING_CATEGORY_ICONS_PATH := "%s/building_category_icons.json" % CONTENT_DIR
const CAMPAIGNS_PATH := "%s/campaigns.json" % AUTHORED_ARCHIVE_DIR
const AI_HERO_WEIGHTS_PATH := "%s/ai_hero_weights.json" % CONTENT_DIR
const BIOME_TERRAIN_INDEX_KEY := "%s#map_tile_ids" % BIOMES_PATH
const MAP_OBJECT_SITE_INDEX_KEY := "%s#resource_site_id" % MAP_OBJECTS_PATH
const ENCOUNTER_KEY := "%s#encounter" % ENCOUNTERS_PATH
const NATIVE_CLASS := "AurelionContent"
const NativeRules = preload("res://scripts/core/NativeRules.gd")

# The native content tables (docs/native-rules-engine-transition.md, Phase 7,
# slice 7.10): the files parsed, indexed and looked up in C++, each document
# and row one read-only Dictionary every caller shares, the port bridge
# included. The content revision is theirs too.
var _native: Object = null
# What this script asked the tables for, so a lookup by id answers without a
# native call: documents by path, and found rows by id, per path or lookup.
# Emptied when the tables reload (clear_cache, an override).
var _files: Dictionary = {}
var _rows: Dictionary = {}
var _generated_scenario_drafts: Dictionary = {}
var _generated_terrain_layer_drafts: Dictionary = {}

func _init() -> void:
	if ClassDB.class_exists(NATIVE_CLASS):
		_native = ClassDB.instantiate(NATIVE_CLASS)
	else:
		push_error("The native rules library is not loaded: %s." % NativeRules.REGISTER_HINT)

func _ready() -> void:
	_validate_content()

func clear_cache() -> void:
	_native.clear_cache()
	_files.clear()
	_rows.clear()

func get_content_revision() -> int:
	return _native.revision()

func clear_generated_scenario_drafts() -> void:
	_generated_scenario_drafts.clear()
	_generated_terrain_layer_drafts.clear()
	_native.bump_revision()

## The file's document (an Array root as {"items": ...}), read-only, or {} with
## an error printed.
func load_json(path: String) -> Dictionary:
	var document: Variant = _files.get(path)
	if document == null:
		document = _native.load_json(path)
		if document == null:
			return {}
		_files[path] = document
	return document

## Replaces a content file's document for this run; the file stays as it is.
## Like clear_cache it bumps the content revision, so whatever is memoized per
## revision reads the new document. Refused (false) for a path that is no
## content file or a document that does not keep the shipped one's shape.
func set_content_override(path: String, data: Dictionary) -> bool:
	if not _native.set_override(path, data):
		return false
	_files.clear()
	_rows.clear()
	return true

func clear_content_overrides() -> void:
	_native.clear_overrides()
	_files.clear()
	_rows.clear()

## The default overworld AI weight set (AiHeroRules, "Weights").
func default_ai_hero_weights() -> Dictionary:
	return load_json(AI_HERO_WEIGHTS_PATH).get("sets", {}).get("default", {})

func get_content_ids(path: String, list_key: String = "items") -> Array[String]:
	var ids: Array[String] = []
	ids.assign(_native.content_ids(path, list_key))
	return ids

func get_faction(id: String) -> Dictionary:
	return get_content_by_id(FACTIONS_PATH, id)

func get_faction_crest(faction_id: String) -> Dictionary:
	return get_content_by_id(FACTION_CRESTS_PATH, faction_id)

func get_hero(id: String) -> Dictionary:
	return get_content_by_id(HEROES_PATH, id)

func get_hero_art(id: String) -> Dictionary:
	return _indexed_content_row(HERO_ART_PATH, id, "items", "hero_id")

func get_unit(id: String) -> Dictionary:
	return get_content_by_id(UNITS_PATH, id)

func get_unit_art(id: String) -> Dictionary:
	return _indexed_content_row(UNIT_ART_PATH, id, "items", "unit_id")

func get_unit_animation(id: String) -> Dictionary:
	return _indexed_content_row(UNIT_ANIMATION_PATH, id, "items", "unit_id")

func get_army_group(id: String) -> Dictionary:
	return get_content_by_id(ARMY_GROUPS_PATH, id)

func get_town(id: String) -> Dictionary:
	return get_content_by_id(TOWNS_PATH, id)

func canonical_town_id(id: String) -> String:
	# Retired IDs are references only, never additional selectable templates.
	# Keeping placed IDs intact preserves old scenario objective/script targets.
	return _native.canonical_town_id(id)

func get_building(id: String) -> Dictionary:
	return get_content_by_id(BUILDINGS_PATH, id)

func get_building_art(building_id: String) -> Dictionary:
	return get_content_by_id(BUILDING_ART_PATH, building_id)

func get_resource(id: String) -> Dictionary:
	return get_content_by_id(RESOURCES_PATH, id)

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

func normalize_terrain_id(terrain_id: String) -> String:
	return _native.normalize_terrain_id(terrain_id)

func get_biome_for_terrain(terrain_id: String) -> Dictionary:
	var row: Variant = _known_row(BIOME_TERRAIN_INDEX_KEY, terrain_id)
	return row if row != null else _remember_row(BIOME_TERRAIN_INDEX_KEY, terrain_id, _native.biome_for_terrain(terrain_id))

func get_map_object(id: String) -> Dictionary:
	return get_content_by_id(MAP_OBJECTS_PATH, id)

func get_map_object_for_resource_site(site_id: String) -> Dictionary:
	var row: Variant = _known_row(MAP_OBJECT_SITE_INDEX_KEY, site_id)
	return row if row != null else _remember_row(MAP_OBJECT_SITE_INDEX_KEY, site_id, _native.map_object_for_resource_site(site_id))

func get_neutral_dwelling(id: String) -> Dictionary:
	return get_content_by_id(NEUTRAL_DWELLINGS_PATH, id)

func get_artifact(id: String) -> Dictionary:
	return get_content_by_id(ARTIFACTS_PATH, id)

func get_spell(id: String) -> Dictionary:
	return get_content_by_id(SPELLS_PATH, id)

func get_spell_icon(spell_id: String) -> Dictionary:
	return get_content_by_id(SPELL_ICONS_PATH, spell_id)

func get_spell_school_icon(school_id: String) -> Dictionary:
	return get_content_by_id(SPELL_SCHOOL_ICONS_PATH, school_id)

func get_building_category_icon(category_id: String) -> Dictionary:
	return get_content_by_id(BUILDING_CATEGORY_ICONS_PATH, category_id)

func get_campaign(id: String) -> Dictionary:
	return get_content_by_id(CAMPAIGNS_PATH, id)

func get_scenario(id: String) -> Dictionary:
	var authored := get_authored_scenario(id)
	if not authored.is_empty():
		return authored
	var draft: Dictionary = _generated_scenario_drafts.get(id, {})
	return draft.duplicate(true) if not draft.is_empty() else {}

# Immutable runtime queries must use this accessor. Generated scenarios can contain
# tens of megabytes of terrain and object records, so deep-copying the full draft
# for every objective/front lookup is prohibitively expensive on Large maps. Code
# which edits or exports a scenario must continue to use get_scenario().
func get_scenario_readonly(id: String) -> Dictionary:
	var authored := get_content_by_id(SCENARIOS_PATH, id)
	if not authored.is_empty():
		return authored
	var draft: Dictionary = _generated_scenario_drafts.get(id, {})
	return draft if not draft.is_empty() else {}

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
	_native.bump_revision()
	return {
		"ok": true,
		"scenario_id": scenario_id,
		"write_policy": "memory_only_no_authored_json_write",
		"menu_policy": "not_returned_by_authored_scenario_lists",
	}

func unregister_generated_scenario_draft(id: String) -> void:
	_generated_scenario_drafts.erase(id)
	_generated_terrain_layer_drafts.erase(id)
	_native.bump_revision()

func get_encounter(id: String) -> Dictionary:
	var row: Variant = _known_row(ENCOUNTER_KEY, id)
	return row if row != null else _remember_row(ENCOUNTER_KEY, id, _native.encounter(id))

## The first row of the list with that id (the towns by their canonical id), or {}.
func get_content_by_id(path: String, id: String, list_key: String = "items") -> Dictionary:
	# Rules ask for rows by id millions of times a game: a row found once is
	# answered from _rows until the tables reload.
	var key := path if list_key == "items" else "%s#%s" % [path, list_key]
	var rows: Variant = _rows.get(key)
	if rows != null:
		var row: Variant = rows.get(id)
		if row != null:
			return row
	return _remember_row(key, id, _native.content_by_id(path, id, list_key))

## The first row whose id_field (else "id") is id, or {}.
func _indexed_content_row(path: String, id: String, list_key: String, id_field: String) -> Dictionary:
	var key := "%s#%s#%s" % [path, list_key, id_field]
	var row: Variant = _known_row(key, id)
	return row if row != null else _remember_row(key, id, _native.indexed_row(path, id, list_key, id_field))

## The row remembered for id under key, or null.
func _known_row(key: String, id: String) -> Variant:
	var rows: Variant = _rows.get(key)
	return rows.get(id) if rows != null else null

## A native lookup's row for id (null for none) remembered under key; {} for none.
func _remember_row(key: String, id: String, found: Variant) -> Dictionary:
	if found == null:
		return {}
	var rows: Variant = _rows.get(key)
	if rows == null:
		rows = {}
		_rows[key] = rows
	rows[id] = found
	return found

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

## The start-up checks of the content: the live files' in C++
## (core/content_validate.cpp), then those of the archived authored scenarios,
## campaigns and terrain layers, which stay here until the campaign rework.
func _validate_content() -> void:
	_native.validate()
	var scenario_index := _index_items(_items_from_raw(load_json(SCENARIOS_PATH)))
	var terrain_grammar := load_json(TERRAIN_GRAMMAR_PATH)
	for terrain_layer in _index_items(_items_from_raw(load_json(TERRAIN_LAYERS_PATH))).values():
		_validate_terrain_layer(terrain_layer, scenario_index, terrain_grammar)
	if not scenario_index.is_empty():
		var artifact_raw := load_json(ARTIFACTS_PATH)
		var faction_index := _index_items(_items_from_raw(load_json(FACTIONS_PATH)))
		var hero_index := _index_items(_items_from_raw(load_json(HEROES_PATH)))
		var army_group_index := _index_items(_items_from_raw(load_json(ARMY_GROUPS_PATH)))
		var town_index := _index_items(_items_from_raw(load_json(TOWNS_PATH)))
		var building_index := _index_items(_items_from_raw(load_json(BUILDINGS_PATH)))
		var unit_index := _index_items(_items_from_raw(load_json(UNITS_PATH)))
		var resource_site_index := _index_items(_items_from_raw(load_json(RESOURCE_SITES_PATH)))
		var artifact_index := _index_items(_items_from_raw(artifact_raw))
		var artifact_set_index := _index_items(artifact_raw.get("sets", []) if artifact_raw is Dictionary else [])
		var encounter_index := _index_items(_items_from_raw(load_json(ENCOUNTERS_PATH)))
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
				artifact_set_index,
				encounter_index
			)
	for campaign in _index_items(_items_from_raw(load_json(CAMPAIGNS_PATH))).values():
		_validate_campaign(campaign, scenario_index)

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
			var normalized_terrain_id := normalize_terrain_id(terrain_id)
			if normalized_terrain_id != "" and normalized_terrain_id not in supported_terrain:
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
	artifact_set_index: Dictionary,
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
		if town_id == "" or not town_index.has(canonical_town_id(town_id)):
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
	var resource_placement_ids: Array[String] = []
	for placement in scenario.get("resource_nodes", []):
		if placement is Dictionary:
			resource_placement_ids.append(String(placement.get("placement_id", "")))

	var encounter_placement_ids: Array[String] = []
	for placement in scenario.get("encounters", []):
		if placement is Dictionary:
			_append_unique_string(encounter_placement_ids, String(placement.get("placement_id", "")))
	var script_hooks = scenario.get("script_hooks", [])
	if script_hooks is Array:
		_append_hook_spawn_placements(script_hooks, "spawn_encounter", encounter_placement_ids)

	var objectives = scenario.get("objectives", {})
	var objective_ids: Array[String] = []
	if objectives is Dictionary:
		for objective in objectives.get("victory", []):
			if objective is Dictionary:
				_append_unique_string(objective_ids, String(objective.get("id", "")))
				_validate_objective(scenario_id, objective, faction_index, hero_index, unit_index, building_index, artifact_index, artifact_set_index, hero_starts, town_placement_ids, resource_placement_ids, encounter_placement_ids)
		for objective in objectives.get("defeat", []):
			if objective is Dictionary:
				_append_unique_string(objective_ids, String(objective.get("id", "")))
				_validate_objective(scenario_id, objective, faction_index, hero_index, unit_index, building_index, artifact_index, artifact_set_index, hero_starts, town_placement_ids, resource_placement_ids, encounter_placement_ids)

	if scenario.has("script_hooks") and not (script_hooks is Array):
		push_warning("Scenario %s script_hooks must be an array." % scenario_id)
	elif script_hooks is Array:
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
	hero_index: Dictionary,
	unit_index: Dictionary,
	building_index: Dictionary,
	artifact_index: Dictionary,
	artifact_set_index: Dictionary,
	hero_starts: Variant,
	town_placement_ids: Array[String],
	resource_placement_ids: Array[String],
	encounter_placement_ids: Array[String]
) -> void:
	var objective_type := String(objective.get("type", ""))
	match objective_type:
		"artifact_owned_by_player":
			var artifact_id := String(objective.get("artifact_id", ""))
			if artifact_id == "" or not artifact_index.has(artifact_id):
				push_warning("Scenario %s objective %s references missing artifact_id %s." % [scenario_id, String(objective.get("id", "")), artifact_id])
		"hero_artifact_set_equipped":
			var set_hero_id := String(objective.get("hero_id", ""))
			var set_id := String(objective.get("set_id", ""))
			if set_hero_id == "" or not hero_index.has(set_hero_id):
				push_warning("Scenario %s objective %s references missing hero_id %s." % [scenario_id, String(objective.get("id", "")), set_hero_id])
			elif not (hero_starts is Array) or set_hero_id not in hero_starts:
				push_warning("Scenario %s objective %s hero_id %s must be a controlled starting hero." % [scenario_id, String(objective.get("id", "")), set_hero_id])
			if set_id == "" or not artifact_set_index.has(set_id):
				push_warning("Scenario %s objective %s references missing artifact set %s." % [scenario_id, String(objective.get("id", "")), set_id])
			else:
				var artifact_set: Dictionary = artifact_set_index.get(set_id, {})
				var set_piece_ids = artifact_set.get("piece_ids", [])
				if not (set_piece_ids is Array) or set_piece_ids.is_empty():
					push_warning("Scenario %s objective %s artifact set %s must define non-empty piece_ids." % [scenario_id, String(objective.get("id", "")), set_id])
				else:
					var seen_piece_ids: Array[String] = []
					for set_piece_id_value in set_piece_ids:
						var set_piece_id := String(set_piece_id_value)
						if set_piece_id == "" or not artifact_index.has(set_piece_id):
							push_warning("Scenario %s objective %s set %s references missing artifact %s." % [scenario_id, String(objective.get("id", "")), set_id, set_piece_id])
						elif set_piece_id in seen_piece_ids:
							push_warning("Scenario %s objective %s set %s repeats artifact %s." % [scenario_id, String(objective.get("id", "")), set_id, set_piece_id])
						else:
							seen_piece_ids.append(set_piece_id)
		"spell_known_by_player":
			var spell_id := String(objective.get("spell_id", ""))
			if spell_id == "" or get_spell(spell_id).is_empty():
				push_warning("Scenario %s objective %s references missing spell_id %s." % [scenario_id, String(objective.get("id", "")), spell_id])
		"building_built_in_player_town":
			var building_placement_id := String(objective.get("placement_id", ""))
			var objective_building_id := String(objective.get("building_id", ""))
			if building_placement_id == "" or building_placement_id not in town_placement_ids:
				push_warning("Scenario %s objective %s references missing town placement %s." % [scenario_id, String(objective.get("id", "")), building_placement_id])
			if objective_building_id == "" or not building_index.has(objective_building_id):
				push_warning("Scenario %s objective %s references missing building_id %s." % [scenario_id, String(objective.get("id", "")), objective_building_id])
		"hero_stationed_at_player_town":
			var stationed_hero_id := String(objective.get("hero_id", ""))
			var stationed_placement_id := String(objective.get("placement_id", ""))
			if stationed_hero_id == "" or not hero_index.has(stationed_hero_id):
				push_warning("Scenario %s objective %s references missing hero_id %s." % [scenario_id, String(objective.get("id", "")), stationed_hero_id])
			if stationed_placement_id == "" or stationed_placement_id not in town_placement_ids:
				push_warning("Scenario %s objective %s references missing town placement %s." % [scenario_id, String(objective.get("id", "")), stationed_placement_id])
		"reserve_delivery_completed":
			var delivery_site_placement_id := String(objective.get("site_placement_id", ""))
			var delivery_target_kind := String(objective.get("target_kind", "town"))
			var delivery_target_id := String(objective.get("target_id", ""))
			if delivery_site_placement_id == "" or delivery_site_placement_id not in resource_placement_ids:
				push_warning("Scenario %s objective %s references missing relay placement %s." % [scenario_id, String(objective.get("id", "")), delivery_site_placement_id])
			if delivery_target_kind == "town":
				if delivery_target_id == "" or delivery_target_id not in town_placement_ids:
					push_warning("Scenario %s objective %s references missing delivery town %s." % [scenario_id, String(objective.get("id", "")), delivery_target_id])
			elif delivery_target_kind == "hero":
				if delivery_target_id == "" or not hero_index.has(delivery_target_id):
					push_warning("Scenario %s objective %s references missing delivery hero %s." % [scenario_id, String(objective.get("id", "")), delivery_target_id])
			else:
				push_warning("Scenario %s objective %s has unsupported delivery target_kind %s." % [scenario_id, String(objective.get("id", "")), delivery_target_kind])
			if int(objective.get("minimum_count", 1)) <= 0:
				push_warning("Scenario %s objective %s must define minimum_count > 0." % [scenario_id, String(objective.get("id", ""))])
		"map_explored_at_least":
			var minimum_percent := int(objective.get("minimum_percent", 0))
			if minimum_percent <= 0 or minimum_percent > 100:
				push_warning("Scenario %s objective %s must define minimum_percent from 1 through 100." % [scenario_id, String(objective.get("id", ""))])
		"resource_stockpile_at_least":
			var stockpile_requirements = objective.get("requirements", {})
			if not (stockpile_requirements is Dictionary) or stockpile_requirements.is_empty():
				push_warning("Scenario %s objective %s must define non-empty resource requirements." % [scenario_id, String(objective.get("id", ""))])
			else:
				for resource_id in stockpile_requirements.keys():
					if String(resource_id) == "" or get_resource(String(resource_id)).is_empty():
						push_warning("Scenario %s objective %s references missing resource_id %s." % [scenario_id, String(objective.get("id", "")), String(resource_id)])
					if int(stockpile_requirements.get(resource_id, 0)) <= 0:
						push_warning("Scenario %s objective %s resource %s must define minimum_count > 0." % [scenario_id, String(objective.get("id", "")), String(resource_id)])
		"resource_sites_controlled_at_least":
			var controlled_site_ids = objective.get("placement_ids", [])
			if not (controlled_site_ids is Array) or controlled_site_ids.is_empty():
				push_warning("Scenario %s objective %s must define non-empty resource-site placement_ids." % [scenario_id, String(objective.get("id", ""))])
			else:
				var seen_controlled_site_ids: Array[String] = []
				for placement_id in controlled_site_ids:
					var controlled_site_id := String(placement_id)
					if controlled_site_id == "" or controlled_site_id not in resource_placement_ids:
						push_warning("Scenario %s objective %s references missing resource-site placement %s." % [scenario_id, String(objective.get("id", "")), controlled_site_id])
					elif controlled_site_id in seen_controlled_site_ids:
						push_warning("Scenario %s objective %s repeats resource-site placement %s." % [scenario_id, String(objective.get("id", "")), controlled_site_id])
					else:
						seen_controlled_site_ids.append(controlled_site_id)
				var minimum_controlled_sites := int(objective.get("minimum_count", 0))
				if minimum_controlled_sites <= 0 or minimum_controlled_sites > seen_controlled_site_ids.size():
					push_warning("Scenario %s objective %s minimum_count must be within its unique placement count." % [scenario_id, String(objective.get("id", ""))])
		"hero_army_meets_requirements":
			var objective_hero_id := String(objective.get("hero_id", ""))
			if objective_hero_id == "" or not hero_index.has(objective_hero_id):
				push_warning("Scenario %s objective %s references missing hero_id %s." % [scenario_id, String(objective.get("id", "")), objective_hero_id])
			elif not (hero_starts is Array) or objective_hero_id not in hero_starts:
				push_warning("Scenario %s objective %s hero_id %s must be a controlled starting hero." % [scenario_id, String(objective.get("id", "")), objective_hero_id])
			var requirements = objective.get("requirements", [])
			if not (requirements is Array) or requirements.is_empty():
				push_warning("Scenario %s objective %s must define non-empty army requirements." % [scenario_id, String(objective.get("id", ""))])
			else:
				var seen_requirement_unit_ids: Array[String] = []
				for requirement in requirements:
					if not (requirement is Dictionary):
						push_warning("Scenario %s objective %s contains a non-dictionary army requirement." % [scenario_id, String(objective.get("id", ""))])
						continue
					var requirement_unit_id := String(requirement.get("unit_id", ""))
					if requirement_unit_id == "" or not unit_index.has(requirement_unit_id):
						push_warning("Scenario %s objective %s references missing unit_id %s." % [scenario_id, String(objective.get("id", "")), requirement_unit_id])
					elif requirement_unit_id in seen_requirement_unit_ids:
						push_warning("Scenario %s objective %s repeats unit_id %s." % [scenario_id, String(objective.get("id", "")), requirement_unit_id])
					else:
						seen_requirement_unit_ids.append(requirement_unit_id)
					if int(requirement.get("minimum_count", 0)) <= 0:
						push_warning("Scenario %s objective %s unit %s must define minimum_count > 0." % [scenario_id, String(objective.get("id", "")), requirement_unit_id])
		"town_garrison_meets_requirements":
			var garrison_placement_id := String(objective.get("placement_id", ""))
			if garrison_placement_id == "" or garrison_placement_id not in town_placement_ids:
				push_warning("Scenario %s objective %s references missing town placement %s." % [scenario_id, String(objective.get("id", "")), garrison_placement_id])
			var requirements = objective.get("requirements", [])
			if not (requirements is Array) or requirements.is_empty():
				push_warning("Scenario %s objective %s must define non-empty garrison requirements." % [scenario_id, String(objective.get("id", ""))])
			else:
				var seen_requirement_unit_ids: Array[String] = []
				for requirement in requirements:
					if not (requirement is Dictionary):
						push_warning("Scenario %s objective %s contains a non-dictionary garrison requirement." % [scenario_id, String(objective.get("id", ""))])
						continue
					var requirement_unit_id := String(requirement.get("unit_id", ""))
					if requirement_unit_id == "" or not unit_index.has(requirement_unit_id):
						push_warning("Scenario %s objective %s references missing unit_id %s." % [scenario_id, String(objective.get("id", "")), requirement_unit_id])
					elif requirement_unit_id in seen_requirement_unit_ids:
						push_warning("Scenario %s objective %s repeats unit_id %s." % [scenario_id, String(objective.get("id", "")), requirement_unit_id])
					else:
						seen_requirement_unit_ids.append(requirement_unit_id)
					if int(requirement.get("minimum_count", 0)) <= 0:
						push_warning("Scenario %s objective %s unit %s must define minimum_count > 0." % [scenario_id, String(objective.get("id", "")), requirement_unit_id])
		"hero_progression_meets_requirements":
			var progression_hero_id := String(objective.get("hero_id", ""))
			if progression_hero_id == "" or not hero_index.has(progression_hero_id):
				push_warning("Scenario %s objective %s references missing hero_id %s." % [scenario_id, String(objective.get("id", "")), progression_hero_id])
			elif not (hero_starts is Array) or progression_hero_id not in hero_starts:
				push_warning("Scenario %s objective %s hero_id %s must be a controlled starting hero." % [scenario_id, String(objective.get("id", "")), progression_hero_id])
			var minimum_level := int(objective.get("minimum_level", 0))
			var minimum_choices := int(objective.get("minimum_resolved_specialty_choices", -1))
			if minimum_level < 2:
				push_warning("Scenario %s objective %s must define minimum_level >= 2." % [scenario_id, String(objective.get("id", ""))])
			if minimum_choices < 1 or minimum_choices > max(0, minimum_level - 1):
				push_warning("Scenario %s objective %s must define resolved specialty choices between 1 and minimum_level - 1." % [scenario_id, String(objective.get("id", ""))])
			if not (objective.get("require_no_pending_specialty_choices", false) is bool):
				push_warning("Scenario %s objective %s pending-specialty requirement must be boolean." % [scenario_id, String(objective.get("id", ""))])
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
		"town_add_garrison":
			var garrison_placement_id := String(effect.get("placement_id", ""))
			if garrison_placement_id == "" or garrison_placement_id not in town_placement_ids:
				push_warning("Scenario %s hook %s references missing town placement %s." % [scenario_id, hook_id, garrison_placement_id])
			var garrison = effect.get("garrison", {})
			if not (garrison is Dictionary) or garrison.is_empty():
				push_warning("Scenario %s hook %s town_add_garrison effects must define garrison." % [scenario_id, hook_id])
			elif garrison is Dictionary:
				for unit_id_value in garrison.keys():
					var unit_id := String(unit_id_value)
					if unit_id == "" or not unit_index.has(unit_id):
						push_warning("Scenario %s hook %s references missing garrison unit id %s." % [scenario_id, hook_id, unit_id])
					if int(garrison[unit_id_value]) <= 0:
						push_warning("Scenario %s hook %s garrison counts must be > 0 for unit %s." % [scenario_id, hook_id, unit_id])
		"add_army_units":
			var army_units = effect.get("units", {})
			if not (army_units is Dictionary) or army_units.is_empty():
				push_warning("Scenario %s hook %s add_army_units effects must define units." % [scenario_id, hook_id])
			elif army_units is Dictionary:
				for unit_id_value in army_units.keys():
					var unit_id := String(unit_id_value)
					if unit_id == "" or not unit_index.has(unit_id):
						push_warning("Scenario %s hook %s references missing active-army unit id %s." % [scenario_id, hook_id, unit_id])
					if int(army_units[unit_id_value]) <= 0:
						push_warning("Scenario %s hook %s active-army unit counts must be > 0 for unit %s." % [scenario_id, hook_id, unit_id])
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
	var expected_emblem_id := "campaign_emblem_%s" % campaign_id.trim_prefix("campaign_")
	var emblem_path := String(campaign.get("emblem_path", "")).strip_edges()
	var emblem_source_path := String(campaign.get("emblem_source_path", "")).strip_edges()
	var emblem_alt_text := String(campaign.get("emblem_alt_text", "")).strip_edges()
	if String(campaign.get("emblem_id", "")) != expected_emblem_id:
		push_warning("Campaign %s must define exact emblem id %s." % [campaign_id, expected_emblem_id])
	if not emblem_path.begins_with("res://art/campaigns/runtime/emblems/") or not emblem_path.ends_with(".png"):
		push_warning("Campaign %s must define a runtime campaign emblem PNG." % campaign_id)
	elif not ResourceLoader.exists(emblem_path, "Texture2D"):
		push_warning("Campaign %s references missing emblem texture %s." % [campaign_id, emblem_path])
	if not emblem_source_path.begins_with("res://art/campaigns/source/generated/emblems/") or not emblem_source_path.ends_with("_source.png"):
		push_warning("Campaign %s must retain exact generated emblem-source provenance." % campaign_id)
	elif OS.has_feature("editor") and not FileAccess.file_exists(emblem_source_path):
		push_warning("Campaign %s references missing emblem source %s." % [campaign_id, emblem_source_path])
	if emblem_alt_text == "":
		push_warning("Campaign %s must define non-color emblem alt text." % campaign_id)
	for hash_key in ["emblem_source_sha256", "emblem_runtime_sha256"]:
		if String(campaign.get(hash_key, "")).length() != 64:
			push_warning("Campaign %s must define a full %s digest." % [campaign_id, hash_key])
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

		_validate_campaign_chapter_seal(campaign_id, scenario_id, scenario_entry)
		_validate_campaign_requirements(campaign_id, scenario_id, scenario_entry, scenario_index)
		_validate_campaign_carryover(campaign_id, scenario_id, scenario_entry, scenario_index)

	var starting_scenario_id := String(campaign.get("starting_scenario_id", ""))
	if starting_scenario_id == "" or starting_scenario_id not in scenario_index:
		push_warning("Campaign %s must define a valid starting_scenario_id." % campaign_id)
	elif starting_scenario_id not in seen_scenarios:
		push_warning("Campaign %s starting_scenario_id %s is not listed in campaign scenarios." % [campaign_id, starting_scenario_id])

func _validate_campaign_chapter_seal(campaign_id: String, scenario_id: String, scenario_entry: Dictionary) -> void:
	var seal_id := String(scenario_entry.get("seal_id", "")).strip_edges()
	var seal_path := String(scenario_entry.get("seal_path", "")).strip_edges()
	var source_path := String(scenario_entry.get("seal_source_path", "")).strip_edges()
	var alt_text := String(scenario_entry.get("seal_alt_text", "")).strip_edges()
	var has_seal_data := seal_id != "" or seal_path != "" or source_path != "" or alt_text != ""
	if not has_seal_data:
		return
	var expected_id := "campaign_chapter_seal_%s" % scenario_id.replace("-", "_")
	if seal_id != expected_id:
		push_warning("Campaign %s scenario %s must define exact seal id %s." % [campaign_id, scenario_id, expected_id])
	if not seal_path.begins_with("res://art/campaigns/runtime/chapter_seals/") or not seal_path.ends_with(".png"):
		push_warning("Campaign %s scenario %s must define a runtime chapter-seal PNG." % [campaign_id, scenario_id])
	elif not ResourceLoader.exists(seal_path, "Texture2D"):
		push_warning("Campaign %s scenario %s references missing chapter seal %s." % [campaign_id, scenario_id, seal_path])
	if not source_path.begins_with("res://art/campaigns/source/generated/chapter_seals/") or not source_path.ends_with("_source.png"):
		push_warning("Campaign %s scenario %s must retain generated chapter-seal provenance." % [campaign_id, scenario_id])
	elif OS.has_feature("editor") and not FileAccess.file_exists(source_path):
		push_warning("Campaign %s scenario %s references missing chapter-seal source %s." % [campaign_id, scenario_id, source_path])
	if alt_text == "":
		push_warning("Campaign %s scenario %s must define non-color chapter-seal alt text." % [campaign_id, scenario_id])
	for hash_key in ["seal_source_sha256", "seal_runtime_sha256"]:
		if String(scenario_entry.get(hash_key, "")).length() != 64:
			push_warning("Campaign %s scenario %s must define a full %s digest." % [campaign_id, scenario_id, hash_key])

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
