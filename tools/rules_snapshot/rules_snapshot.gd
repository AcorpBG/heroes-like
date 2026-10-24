extends RefCounted
## What the rules tools outside Godot read from the game (src/gdextension/rules/cli:
## battle_sim_cli, match_sim_cli): the content snapshot, which holds the content
## files, the content tables by id as ContentService's getters answer, and the
## rules scripts' static vars, and the snapshot file format (NativeRules
## snapshot_encode). The battle AI arena's worker and the AI match runner scene
## write them; nothing here is loaded by the game.
##
## Static funcs only, given the ContentService autoload: a -s script compiles
## before autoloads exist.

const CONTENT_DIR := "res://content"
# The art files that game setup reads through ContentService.load_json.
const ART_FILES := [
	"res://art/overworld/manifest.json",
	"res://art/overworld/creature_idle.json",
	"res://art/overworld/native_scenery.json",
]
# The scripts the native rules read static vars of: the rules, and the
# generated map adoption's.
const RULES_DIRS := ["res://scripts/core", "res://scripts/persistence"]
# The CLIs' content tables (state::ContentTable): the getter of each, and the
# file whose ids it is asked for. A generated map's session registers no
# scenario draft, so its scenario and terrain layers lookups answer {}.
const CONTENT_TABLES := {
	"Unit": ["get_unit", "res://content/units.json"],
	"Hero": ["get_hero", "res://content/heroes.json"],
	"Faction": ["get_faction", "res://content/factions.json"],
	"Spell": ["get_spell", "res://content/spells.json"],
	"Artifact": ["get_artifact", "res://content/artifacts.json"],
	"ResourceSite": ["get_resource_site", "res://content/resource_sites.json"],
	"Building": ["get_building", "res://content/buildings.json"],
	"Town": ["get_town", "res://content/towns.json"],
	"MapObject": ["get_map_object", "res://content/map_objects.json"],
	"Encounter": ["get_encounter", "res://content/encounters.json"],
	"ArmyGroup": ["get_army_group", "res://content/army_groups.json"],
	"Resource": ["get_resource", "res://content/resources.json"],
	"NeutralDwelling": ["get_neutral_dwelling", "res://content/neutral_dwellings.json"],
	"BuildingArt": ["get_building_art", "res://content/building_art_manifest.json"],
	"SpellIcon": ["get_spell_icon", "res://content/spell_icons.json"],
	"SpellSchoolIcon": ["get_spell_school_icon", "res://content/spell_school_icons.json"],
	"BuildingCategoryIcon": ["get_building_category_icon", "res://content/building_category_icons.json"],
	"FactionCrest": ["get_faction_crest", "res://content/faction_crests.json"],
	"Biome": ["get_biome", "res://content/biomes.json"],
	"Campaign": ["get_campaign", "res://archive/authored-scenarios-2026-10-08/campaigns.json"],
}
# The art rows found by the unit or hero id their items name.
const INDEXED_TABLES := {
	"UnitArt": ["get_unit_art", "res://content/unit_art_manifest.json", "unit_id"],
	"HeroArt": ["get_hero_art", "res://content/hero_art_manifest.json", "hero_id"],
	"UnitAnimation": ["get_unit_animation", "res://content/unit_animation_manifest.json", "unit_id"],
}
const GENERATED_COMPANIES_PATH := "res://content/generated_neutral_companies.json"


## The content snapshot: {files, tables, statics, revision}. The static vars are
## the scripts' values now, so a caller that wants them as a game starts calls
## this before playing anything.
static func content_snapshot(content) -> Dictionary:
	var files := {}
	for name in DirAccess.get_files_at(CONTENT_DIR):
		if name.get_extension() == "json":
			var path := CONTENT_DIR.path_join(name)
			files[path] = content.load_json(path)
	for path in ART_FILES:
		files[path] = content.load_json(path)
	var tables := {}
	for table in CONTENT_TABLES:
		var getter := String(CONTENT_TABLES[table][0])
		var path := String(CONTENT_TABLES[table][1])
		# "" too: an item without an id is the row of id "".
		var ids: Array = [""]
		ids.append_array(content.get_content_ids(path))
		if table == "Town":
			ids.append_array((content.load_json(path).get("legacy_aliases", {}) as Dictionary).keys())
		elif table == "Encounter":
			ids.append_array(content.get_content_ids(GENERATED_COMPANIES_PATH, "encounters"))
		var rows := {}
		for id in ids:
			var row: Dictionary = content.call(getter, String(id))
			if not rows.has(String(id)) and not row.is_empty():
				rows[String(id)] = row
		tables[table] = rows
	# By the id each lookup asks with: the stripped site id, the normalized terrain.
	var by_site := {}
	for item in content._items_from_raw(content.load_json("res://content/map_objects.json")):
		var site_id := String(item.get("resource_site_id", "")).strip_edges() if item is Dictionary else ""
		if site_id != "" and not by_site.has(site_id):
			by_site[site_id] = content.get_map_object_for_resource_site(site_id)
	tables["MapObjectForResourceSite"] = by_site
	var by_terrain := {}
	for biome in content._items_from_raw(content.load_json("res://content/biomes.json")):
		if not (biome is Dictionary) or not (biome.get("map_tile_ids", []) is Array):
			continue
		for tile_id in biome.get("map_tile_ids", []):
			var terrain := String(tile_id) if tile_id is String or tile_id is StringName else ""
			if terrain != "" and content.normalize_terrain_id(terrain) == terrain and not by_terrain.has(terrain):
				var row: Dictionary = content.get_biome_for_terrain(terrain)
				if not row.is_empty():
					by_terrain[terrain] = row
	tables["BiomeForTerrain"] = by_terrain
	for table in INDEXED_TABLES:
		var getter := String(INDEXED_TABLES[table][0])
		var field := String(INDEXED_TABLES[table][2])
		var rows := {}
		for item in content._items_from_raw(content.load_json(String(INDEXED_TABLES[table][1]))):
			var id := String(item.get(field, "")) if item is Dictionary else ""
			if not rows.has(id):
				var row: Dictionary = content.call(getter, id)
				if not row.is_empty():
					rows[id] = row
		tables[table] = rows
	return {"files": files, "tables": tables, "statics": static_vars(), "revision": content.get_content_revision()}


## Each rules script's static vars, by its path and their names.
static func static_vars() -> Dictionary:
	var declaration := RegEx.create_from_string("^static var ([A-Za-z_][A-Za-z0-9_]*)")
	var statics := {}
	for dir in RULES_DIRS:
		for name in DirAccess.get_files_at(dir):
			if name.get_extension() != "gd":
				continue
			var path := String(dir).path_join(name)
			var names := []
			for line in FileAccess.get_file_as_string(path).split("\n"):
				var found := declaration.search(line)
				if found != null:
					names.append(found.get_string(1))
			var script = load(path) if not names.is_empty() else null
			if script == null:
				continue
			var values := {}
			for var_name in names:
				values[var_name] = script.get(var_name)
			statics[path] = values
	return statics


## value as a snapshot file at path (an absolute or res:// path). It is written
## under a name of this process first and takes its name when whole, so a
## reader never sees half a file, and processes writing the same file (the
## same content snapshot) do not mix.
static func write(path: String, value: Variant) -> bool:
	var bytes: PackedByteArray = load("res://scripts/core/NativeRules.gd").api().snapshot_encode(value)
	if bytes.is_empty():
		return false
	var part := "%s.%d.part" % [path, OS.get_process_id()]
	var file := FileAccess.open(part, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(bytes)
	file.close()
	var target := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(target)
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(part), target) == OK:
		return true
	DirAccess.remove_absolute(ProjectSettings.globalize_path(part))
	return FileAccess.file_exists(path)
