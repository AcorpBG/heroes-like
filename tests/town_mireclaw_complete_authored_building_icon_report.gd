extends "res://tests/town_embercourt_production_dwelling_icon_report.gd"

const MIRECLAW_FINAL_AUTHORED_BUILDING_IDS := [
	"building_war_drum_circle",
	"building_floodtide_forge",
	"building_smugglers_flotilla",
	"building_nightglass_dominion",
]

func _target_building_ids() -> Array:
	return MIRECLAW_FINAL_AUTHORED_BUILDING_IDS

func _report_marker() -> String:
	return "TOWN_MIRECLAW_COMPLETE_AUTHORED_BUILDING_ICON_REPORT"

func _catalog_contract() -> Dictionary:
	var result: Dictionary = super._catalog_contract()
	var mireclaw_town_ids := []
	var remaining_fallback_ids := []
	for town_id in ContentService.get_content_ids(ContentService.TOWNS_PATH):
		var town_template: Dictionary = ContentService.get_town(town_id)
		if String(town_template.get("faction_id", "")) != "faction_mireclaw":
			continue
		mireclaw_town_ids.append(town_id)
		var building_ids := []
		building_ids.append_array(town_template.get("starting_building_ids", []))
		building_ids.append_array(town_template.get("buildable_building_ids", []))
		for building_id in building_ids:
			if ContentService.get_building_art(String(building_id)).is_empty() and String(building_id) not in remaining_fallback_ids:
				remaining_fallback_ids.append(String(building_id))
	result["mireclaw_town_ids"] = mireclaw_town_ids
	result["mireclaw_town_count"] = mireclaw_town_ids.size()
	result["remaining_mireclaw_fallback_ids"] = remaining_fallback_ids
	result["mireclaw_all_specific"] = mireclaw_town_ids.size() == 5 and remaining_fallback_ids.is_empty()
	result["ok"] = bool(result.get("ok", false)) and bool(result.get("mireclaw_all_specific", false))
	return result
