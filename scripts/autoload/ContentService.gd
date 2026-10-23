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

## The start-up checks of the live content files run native
## (core/content_validate.cpp); the archived authored content is loaded by id
## but no longer checked (owner decision 2026-10-23).
func _ready() -> void:
	_native.validate()

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
