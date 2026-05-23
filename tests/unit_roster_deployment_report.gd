extends Node

const OverworldRulesScript = preload("res://scripts/core/OverworldRules.gd")

const OUTPUT_DIR := "res://.artifacts/unit_roster_deployment_report"
const CONTENT_PATHS := {
	"units": "res://content/units.json",
	"buildings": "res://content/buildings.json",
	"towns": "res://content/towns.json",
	"neutral_dwellings": "res://content/neutral_dwellings.json",
	"army_groups": "res://content/army_groups.json",
	"encounters": "res://content/encounters.json",
}

var _errors: Array[String] = []
var _report := {
	"ok": false,
	"unit_count": 0,
	"faction_unit_count": 0,
	"neutral_unit_count": 0,
	"faction_recruitable_count": 0,
	"neutral_deployed_count": 0,
	"units": [],
	"errors": [],
}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_ensure_output_dir()
	var units := _index_by_id(_items(ContentService.load_json(CONTENT_PATHS["units"])))
	var buildings := _index_by_id(_items(ContentService.load_json(CONTENT_PATHS["buildings"])))
	var towns := _index_by_id(_items(ContentService.load_json(CONTENT_PATHS["towns"])))
	var dwellings := _index_by_id(_items(ContentService.load_json(CONTENT_PATHS["neutral_dwellings"])))
	var army_groups := _index_by_id(_items(ContentService.load_json(CONTENT_PATHS["army_groups"])))
	var encounters := _index_by_id(_items(ContentService.load_json(CONTENT_PATHS["encounters"])))
	var deployment_indexes := _build_deployment_indexes(buildings, towns, dwellings, army_groups, encounters)
	_report["unit_count"] = units.size()
	for unit_id in units.keys():
		var unit: Dictionary = units[unit_id]
		var faction_id := String(unit.get("faction_id", "")).strip_edges()
		if faction_id == "":
			_report["neutral_unit_count"] = int(_report["neutral_unit_count"]) + 1
			_validate_neutral_unit(unit_id, unit, deployment_indexes)
		else:
			_report["faction_unit_count"] = int(_report["faction_unit_count"]) + 1
			_validate_faction_unit(unit_id, unit, deployment_indexes)
	_report["ok"] = _errors.is_empty()
	_report["errors"] = _errors.duplicate()
	_write_json("%s/report.json" % OUTPUT_DIR, _report)
	if _errors.is_empty():
		print("UNIT_ROSTER_DEPLOYMENT_REPORT %s" % JSON.stringify(_summary_payload()))
	get_tree().quit(0 if _errors.is_empty() else 1)

func _validate_faction_unit(unit_id: String, unit: Dictionary, indexes: Dictionary) -> void:
	var faction_id := String(unit.get("faction_id", "")).strip_edges()
	var building_ids: Array = indexes["unlock_buildings_by_unit"].get(unit_id, [])
	var all_town_ids: Array = indexes["towns_by_unit"].get(unit_id, [])
	var town_ids := []
	for town_id in all_town_ids:
		var town: Dictionary = indexes["towns"].get(town_id, {})
		if String(town.get("faction_id", "")).strip_edges() == faction_id:
			town_ids.append(town_id)
	var runtime_growth_towns := []
	for town_id in town_ids:
		var town: Dictionary = indexes["towns"].get(town_id, {})
		var building_id := _first_unlock_building_in_town(unit_id, building_ids, town)
		if building_id == "":
			continue
		var projected_town := {
			"town_id": town_id,
			"built_buildings": [building_id],
			"available_recruits": {},
		}
		var growth: Dictionary = OverworldRulesScript.town_weekly_growth(projected_town)
		if int(growth.get(unit_id, 0)) > 0:
			runtime_growth_towns.append(town_id)
	if building_ids.is_empty():
		_error("Faction unit %s has no building unlock." % unit_id)
	if town_ids.is_empty():
		_error("Faction unit %s is not present in any matching-faction town build tree." % unit_id)
	if runtime_growth_towns.is_empty():
		_error("Faction unit %s does not produce runtime weekly growth from any projected town unlock." % unit_id)
	if not building_ids.is_empty() and not town_ids.is_empty() and not runtime_growth_towns.is_empty():
		_report["faction_recruitable_count"] = int(_report["faction_recruitable_count"]) + 1
	_report["units"].append({
		"unit_id": unit_id,
		"name": String(unit.get("name", unit_id)),
		"deployment_kind": "faction_recruitment",
		"faction_id": faction_id,
		"unlock_building_ids": building_ids,
		"town_ids": town_ids,
		"runtime_growth_town_ids": runtime_growth_towns,
	})

func _validate_neutral_unit(unit_id: String, unit: Dictionary, indexes: Dictionary) -> void:
	var dwelling_ids: Array = indexes["dwellings_by_unit"].get(unit_id, [])
	var army_group_ids: Array = indexes["army_groups_by_unit"].get(unit_id, [])
	var encounter_ids: Array = []
	for army_group_id in army_group_ids:
		for encounter_id in indexes["encounters_by_army_group"].get(army_group_id, []):
			if encounter_id not in encounter_ids:
				encounter_ids.append(encounter_id)
	if dwelling_ids.is_empty():
		_error("Neutral unit %s is not listed by any neutral dwelling." % unit_id)
	if army_group_ids.is_empty():
		_error("Neutral unit %s is not deployed in any army group." % unit_id)
	if encounter_ids.is_empty():
		_error("Neutral unit %s has no encounter reachable through its dwelling army groups." % unit_id)
	if not dwelling_ids.is_empty() and not army_group_ids.is_empty() and not encounter_ids.is_empty():
		_report["neutral_deployed_count"] = int(_report["neutral_deployed_count"]) + 1
	_report["units"].append({
		"unit_id": unit_id,
		"name": String(unit.get("name", unit_id)),
		"deployment_kind": "neutral_dwelling_guard",
		"dwelling_ids": dwelling_ids,
		"army_group_ids": army_group_ids,
		"encounter_ids": encounter_ids,
	})

func _build_deployment_indexes(
	buildings: Dictionary,
	towns: Dictionary,
	dwellings: Dictionary,
	army_groups: Dictionary,
	encounters: Dictionary
) -> Dictionary:
	var unlock_buildings_by_unit := {}
	for building_id in buildings.keys():
		var unit_id := String(buildings[building_id].get("unlock_unit_id", "")).strip_edges()
		if unit_id != "":
			_append_index(unlock_buildings_by_unit, unit_id, building_id)
	var towns_by_unit := {}
	for town_id in towns.keys():
		var town: Dictionary = towns[town_id]
		var town_buildings := []
		town_buildings.append_array(_string_array(town.get("starting_building_ids", [])))
		town_buildings.append_array(_string_array(town.get("buildable_building_ids", [])))
		for building_id in town_buildings:
			var unit_id := String(buildings.get(building_id, {}).get("unlock_unit_id", "")).strip_edges()
			if unit_id == "":
				continue
			_append_index(towns_by_unit, unit_id, town_id)
	var dwellings_by_unit := {}
	for dwelling_id in dwellings.keys():
		for unit_id in _string_array(dwellings[dwelling_id].get("unit_ids", [])):
			_append_index(dwellings_by_unit, unit_id, dwelling_id)
	var army_groups_by_unit := {}
	for army_group_id in army_groups.keys():
		for stack in army_groups[army_group_id].get("stacks", []):
			if not (stack is Dictionary):
				continue
			var unit_id := String(stack.get("unit_id", "")).strip_edges()
			if unit_id != "":
				_append_index(army_groups_by_unit, unit_id, army_group_id)
	var encounters_by_army_group := {}
	for encounter_id in encounters.keys():
		var army_group_id := String(encounters[encounter_id].get("enemy_group_id", "")).strip_edges()
		if army_group_id != "":
			_append_index(encounters_by_army_group, army_group_id, encounter_id)
	return {
		"buildings": buildings,
		"towns": towns,
		"unlock_buildings_by_unit": unlock_buildings_by_unit,
		"towns_by_unit": towns_by_unit,
		"dwellings_by_unit": dwellings_by_unit,
		"army_groups_by_unit": army_groups_by_unit,
		"encounters_by_army_group": encounters_by_army_group,
	}

func _first_unlock_building_in_town(unit_id: String, building_ids: Array, town: Dictionary) -> String:
	var town_buildings := []
	town_buildings.append_array(_string_array(town.get("starting_building_ids", [])))
	town_buildings.append_array(_string_array(town.get("buildable_building_ids", [])))
	for building_id in building_ids:
		if String(building_id) in town_buildings:
			return String(building_id)
	return ""

func _append_index(index: Dictionary, key: String, value: String) -> void:
	if key == "" or value == "":
		return
	if not index.has(key):
		index[key] = []
	if value not in index[key]:
		index[key].append(value)

func _string_array(value: Variant) -> Array:
	var result := []
	if value is Array:
		for entry in value:
			var text := String(entry).strip_edges()
			if text != "":
				result.append(text)
	return result

func _index_by_id(records: Array) -> Dictionary:
	var indexed := {}
	for record in records:
		if record is Dictionary:
			var record_id := String(record.get("id", "")).strip_edges()
			if record_id != "":
				indexed[record_id] = record
	return indexed

func _items(raw: Dictionary) -> Array:
	var items = raw.get("items", [])
	return items if items is Array else []

func _ensure_output_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))

func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.WRITE)
	if file == null:
		_error("Failed to open %s for writing." % path)
		return
	file.store_string(JSON.stringify(payload, "\t"))

func _summary_payload() -> Dictionary:
	return {
		"ok": bool(_report.get("ok", false)),
		"unit_count": int(_report.get("unit_count", 0)),
		"faction_unit_count": int(_report.get("faction_unit_count", 0)),
		"neutral_unit_count": int(_report.get("neutral_unit_count", 0)),
		"faction_recruitable_count": int(_report.get("faction_recruitable_count", 0)),
		"neutral_deployed_count": int(_report.get("neutral_deployed_count", 0)),
	}

func _error(message: String) -> void:
	_errors.append(message)
	push_error(message)
