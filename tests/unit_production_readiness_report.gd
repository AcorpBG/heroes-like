extends Node

const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")

const OUTPUT_DIR := "res://.artifacts/unit_production_readiness_report"
const UNIT_ART_MANIFEST := "res://content/unit_art_manifest.json"
const EXPECTED_ART_SIZES := {
	"portrait": Vector2i(384, 512),
	"battle_icon": Vector2i(160, 160),
	"overworld_icon": Vector2i(96, 96),
}
const CONTENT_REFERENCE_PATHS := {
	"factions": "res://content/factions.json",
	"buildings": "res://content/buildings.json",
	"towns": "res://content/towns.json",
	"army_groups": "res://content/army_groups.json",
	"neutral_dwellings": "res://content/neutral_dwellings.json",
	"resource_sites": "res://content/resource_sites.json",
	"encounters": "res://content/encounters.json",
	"scenarios": "res://content/scenarios.json",
}

var _errors: Array[String] = []
var _report := {
	"ok": false,
	"unit_count": 0,
	"stack_materialized_count": 0,
	"normalized_stack_count": 0,
	"art_surface_load_counts": {},
	"art_surface_unique_hash_counts": {},
	"units_without_live_reference": [],
	"units": [],
	"errors": [],
}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_ensure_output_dir()
	var units := _items(ContentService.load_json(ContentService.UNITS_PATH))
	var manifest_records := _items(ContentService.load_json(UNIT_ART_MANIFEST))
	var manifest_by_unit := _index_by_unit_id(manifest_records)
	var unit_ids := {}
	for unit in units:
		if unit is Dictionary:
			unit_ids[String(unit.get("id", ""))] = true
	var references := _build_unit_reference_index(unit_ids)
	_report["unit_count"] = units.size()
	var used_names := {}
	var art_hashes := {}
	for surface in EXPECTED_ART_SIZES.keys():
		_report["art_surface_load_counts"][surface] = 0
		_report["art_surface_unique_hash_counts"][surface] = 0
		art_hashes[surface] = {}
	for index in range(units.size()):
		var unit: Dictionary = units[index] if units[index] is Dictionary else {}
		if unit.is_empty():
			_error("Unit record %d is not a dictionary." % index)
			continue
		_validate_unit(unit, manifest_by_unit, references, used_names, art_hashes)
	for surface in EXPECTED_ART_SIZES.keys():
		_report["art_surface_unique_hash_counts"][surface] = art_hashes[surface].size()
	_report["ok"] = _errors.is_empty()
	_report["errors"] = _errors.duplicate()
	_write_json("%s/report.json" % OUTPUT_DIR, _report)
	if _errors.is_empty():
		print("UNIT_PRODUCTION_READINESS_REPORT %s" % JSON.stringify(_summary_payload()))
	get_tree().quit(0 if _errors.is_empty() else 1)

func _validate_unit(
	unit: Dictionary,
	manifest_by_unit: Dictionary,
	references: Dictionary,
	used_names: Dictionary,
	art_hashes: Dictionary
) -> void:
	var unit_id := String(unit.get("id", "")).strip_edges()
	var unit_name := String(unit.get("name", "")).strip_edges()
	if unit_id == "":
		_error("Unit record is missing id.")
		return
	if unit_name == "":
		_error("Unit %s is missing name." % unit_id)
	elif used_names.has(unit_name):
		_error("Unit name is duplicated: %s." % unit_name)
	used_names[unit_name] = unit_id

	_validate_unit_gameplay_fields(unit_id, unit)
	var source_ability_ids := _unit_ability_ids(unit)
	var stack: Dictionary = BattleRulesScript._build_battle_stack(unit_id, 3, "player", 0, {"source_type": "unit_production_readiness_report"})
	if stack.is_empty():
		_error("Unit %s could not materialize as a battle stack." % unit_id)
	else:
		_report["stack_materialized_count"] = int(_report["stack_materialized_count"]) + 1
		_validate_stack(unit_id, source_ability_ids, stack, "materialized")
	var normalized: Dictionary = BattleRulesScript._normalize_stack(stack)
	if normalized.is_empty():
		_error("Unit %s could not normalize as a battle stack." % unit_id)
	else:
		_report["normalized_stack_count"] = int(_report["normalized_stack_count"]) + 1
		_validate_stack(unit_id, source_ability_ids, normalized, "normalized")

	var art_summary := _validate_art(unit_id, manifest_by_unit.get(unit_id, {}), art_hashes)
	var unit_refs: Array = references.get(unit_id, []) if references.get(unit_id, []) is Array else []
	if unit_refs.is_empty():
		_report["units_without_live_reference"].append(unit_id)
		_error("Unit %s has no live content references." % unit_id)
	_report["units"].append({
		"unit_id": unit_id,
		"name": unit_name,
		"faction_id": String(unit.get("faction_id", "")),
		"content_status": String(unit.get("content_status", "")),
		"ability_ids": source_ability_ids,
		"reference_count": unit_refs.size(),
		"reference_sources": _unique_string_array(unit_refs),
		"art": art_summary,
	})

func _validate_unit_gameplay_fields(unit_id: String, unit: Dictionary) -> void:
	var faction_id := String(unit.get("faction_id", "")).strip_edges()
	var content_status := String(unit.get("content_status", "")).strip_edges()
	if faction_id == "" and content_status != "neutral_dwelling_slice":
		_error("Unit %s is neither faction-owned nor marked neutral_dwelling_slice." % unit_id)
	if int(unit.get("tier", 0)) <= 0:
		_error("Unit %s must define tier > 0." % unit_id)
	for field in ["hp", "attack", "defense", "speed", "initiative", "growth"]:
		if int(unit.get(field, 0)) <= 0:
			_error("Unit %s must define %s > 0." % [unit_id, field])
	if int(unit.get("max_damage", 0)) < int(unit.get("min_damage", 0)) or int(unit.get("min_damage", 0)) <= 0:
		_error("Unit %s has invalid damage range." % unit_id)
	if int(unit.get("retaliations", -1)) < 0:
		_error("Unit %s must define retaliations >= 0." % unit_id)
	var role := String(unit.get("role", ""))
	if role not in ["melee", "ranged"]:
		_error("Unit %s has unsupported role %s." % [unit_id, role])
	if bool(unit.get("ranged", false)) and int(unit.get("shots", 0)) <= 0:
		_error("Ranged unit %s must define shots > 0." % unit_id)
	var cost: Dictionary = unit.get("cost", {}) if unit.get("cost", {}) is Dictionary else {}
	if cost.is_empty():
		_error("Unit %s must define a non-empty cost." % unit_id)
	for resource_id in cost.keys():
		if String(resource_id).strip_edges() == "" or int(cost[resource_id]) <= 0:
			_error("Unit %s has invalid cost entry %s." % [unit_id, resource_id])
	var abilities: Array = unit.get("abilities", []) if unit.get("abilities", []) is Array else []
	if abilities.is_empty():
		_error("Unit %s must define at least one implemented ability." % unit_id)

func _validate_stack(unit_id: String, source_ability_ids: Array, stack: Dictionary, label: String) -> void:
	if String(stack.get("unit_id", "")) != unit_id:
		_error("Unit %s %s stack changed unit_id to %s." % [unit_id, label, stack.get("unit_id", "")])
	for field in ["unit_hp", "base_count", "attack", "defense", "min_damage", "max_damage", "initiative", "speed"]:
		if int(stack.get(field, 0)) <= 0:
			_error("Unit %s %s stack must define %s > 0." % [unit_id, label, field])
	var normalized_ability_ids := _unit_ability_ids(stack)
	if normalized_ability_ids.size() != source_ability_ids.size():
		_error("Unit %s %s stack ability count changed from %d to %d." % [unit_id, label, source_ability_ids.size(), normalized_ability_ids.size()])
	for ability_id in source_ability_ids:
		if ability_id not in normalized_ability_ids:
			_error("Unit %s %s stack dropped ability %s." % [unit_id, label, ability_id])

func _validate_art(unit_id: String, record: Variant, art_hashes: Dictionary) -> Dictionary:
	var summary := {}
	if not (record is Dictionary) or record.is_empty():
		_error("Unit %s is missing a unit-art manifest record." % unit_id)
		return summary
	for surface in EXPECTED_ART_SIZES.keys():
		var path := String(record.get(surface, "")).strip_edges()
		var loaded := false
		var size := Vector2i.ZERO
		var hash := ""
		if path == "":
			_error("Unit %s missing %s art path." % [unit_id, surface])
		else:
			size = _png_size(path)
			loaded = size != Vector2i.ZERO and _texture_from_path(path) is Texture2D
			hash = FileAccess.get_md5(path) if FileAccess.file_exists(path) else ""
			if size != EXPECTED_ART_SIZES[surface]:
				_error("Unit %s %s expected %s but got %s." % [unit_id, surface, EXPECTED_ART_SIZES[surface], size])
			if not loaded:
				_error("Unit %s %s art does not load as a texture: %s." % [unit_id, surface, path])
			if hash == "":
				_error("Unit %s %s art has no readable hash: %s." % [unit_id, surface, path])
			elif art_hashes[surface].has(hash):
				_error("Unit %s %s art duplicates PNG bytes with %s." % [unit_id, surface, art_hashes[surface][hash]])
			else:
				art_hashes[surface][hash] = unit_id
		if loaded:
			_report["art_surface_load_counts"][surface] = int(_report["art_surface_load_counts"].get(surface, 0)) + 1
		summary[surface] = {
			"path": path,
			"loaded": loaded,
			"size": {"x": size.x, "y": size.y},
			"hash": hash,
		}
	return summary

func _build_unit_reference_index(unit_ids: Dictionary) -> Dictionary:
	var references := {}
	for unit_id in unit_ids.keys():
		references[unit_id] = []
	for source_name in CONTENT_REFERENCE_PATHS.keys():
		var payload := ContentService.load_json(CONTENT_REFERENCE_PATHS[source_name])
		_collect_unit_references(payload, source_name, unit_ids, references)
	return references

func _collect_unit_references(value: Variant, source_name: String, unit_ids: Dictionary, references: Dictionary) -> void:
	if value is Dictionary:
		for key in value.keys():
			if key is String and unit_ids.has(String(key)):
				references[String(key)].append(source_name)
			_collect_unit_references(value[key], source_name, unit_ids, references)
	elif value is Array:
		for item in value:
			_collect_unit_references(item, source_name, unit_ids, references)
	elif value is String and unit_ids.has(String(value)):
		references[String(value)].append(source_name)

func _unit_ability_ids(unit_or_stack: Dictionary) -> Array:
	var ids := []
	for ability in unit_or_stack.get("abilities", []):
		if ability is Dictionary:
			var ability_id := String(ability.get("id", "")).strip_edges()
			if ability_id != "":
				ids.append(ability_id)
	return ids

func _unique_string_array(values: Array) -> Array:
	var seen := {}
	var result := []
	for value in values:
		var key := String(value)
		if key == "" or seen.has(key):
			continue
		seen[key] = true
		result.append(key)
	return result

func _index_by_unit_id(records: Array) -> Dictionary:
	var indexed := {}
	for record in records:
		if record is Dictionary:
			var unit_id := String(record.get("unit_id", record.get("id", "")))
			if unit_id != "":
				indexed[unit_id] = record
	return indexed

func _items(raw: Dictionary) -> Array:
	var items = raw.get("items", [])
	return items if items is Array else []

func _texture_from_path(path: String):
	if path == "":
		return null
	if ResourceLoader.exists(path):
		var resource = load(path)
		if resource is Texture2D:
			return resource
	if FileAccess.file_exists(path):
		var image := Image.new()
		if image.load(path) == OK:
			return ImageTexture.create_from_image(image)
	return null

func _png_size(path: String) -> Vector2i:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return Vector2i.ZERO
	var header := file.get_buffer(24)
	if header.size() < 24:
		return Vector2i.ZERO
	var signature := PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10])
	for index in range(signature.size()):
		if header[index] != signature[index]:
			return Vector2i.ZERO
	var width := _be_u32(header, 16)
	var height := _be_u32(header, 20)
	return Vector2i(width, height)

func _be_u32(bytes: PackedByteArray, offset: int) -> int:
	return (
		(int(bytes[offset]) << 24)
		| (int(bytes[offset + 1]) << 16)
		| (int(bytes[offset + 2]) << 8)
		| int(bytes[offset + 3])
	)

func _summary_payload() -> Dictionary:
	return {
		"ok": true,
		"unit_count": _report["unit_count"],
		"stack_materialized_count": _report["stack_materialized_count"],
		"normalized_stack_count": _report["normalized_stack_count"],
		"art_surface_load_counts": _report["art_surface_load_counts"],
		"art_surface_unique_hash_counts": _report["art_surface_unique_hash_counts"],
		"units_without_live_reference": _report["units_without_live_reference"],
	}

func _ensure_output_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))

func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.WRITE)
	if file == null:
		_error("Failed to write %s." % path)
		return
	file.store_string(JSON.stringify(payload, "\t"))

func _error(message: String) -> void:
	push_error(message)
	_errors.append(message)
