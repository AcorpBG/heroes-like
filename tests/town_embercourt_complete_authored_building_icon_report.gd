extends "res://tests/town_embercourt_production_dwelling_icon_report.gd"

const EMBERCOURT_FINAL_AUTHORED_BUILDING_IDS := [
	"building_watch_barracks",
	"building_beacon_range",
	"building_river_granary_exchange",
	"building_quartermasters_depot",
	"building_citadel_pikehall",
	"building_embercourt_granary_lock_exchange",
	"building_embercourt_tollstone_weir",
	"building_embercourt_beacon_writs",
	"building_embercourt_lantern_court",
	"building_embercourt_relief_quay",
	"building_embercourt_charter_flame",
	"building_signal_citadel",
	"building_charter_bastion",
]

func _target_building_ids() -> Array:
	return EMBERCOURT_FINAL_AUTHORED_BUILDING_IDS

func _report_marker() -> String:
	return "TOWN_EMBERCOURT_COMPLETE_AUTHORED_BUILDING_ICON_REPORT"

func _catalog_contract() -> Dictionary:
	var result: Dictionary = super._catalog_contract()
	var embercourt_town_ids := []
	var remaining_fallback_ids := []
	for town_id in ContentService.get_content_ids(ContentService.TOWNS_PATH):
		var town_template: Dictionary = ContentService.get_town(town_id)
		if String(town_template.get("faction_id", "")) != "faction_embercourt":
			continue
		embercourt_town_ids.append(town_id)
		var building_ids := []
		building_ids.append_array(town_template.get("starting_building_ids", []))
		building_ids.append_array(town_template.get("buildable_building_ids", []))
		for building_id in building_ids:
			if ContentService.get_building_art(String(building_id)).is_empty() and String(building_id) not in remaining_fallback_ids:
				remaining_fallback_ids.append(String(building_id))
	result["embercourt_town_ids"] = embercourt_town_ids
	result["embercourt_town_count"] = embercourt_town_ids.size()
	result["remaining_embercourt_fallback_ids"] = remaining_fallback_ids
	result["embercourt_all_specific"] = embercourt_town_ids.size() == 2 and remaining_fallback_ids.is_empty()
	result["ok"] = bool(result.get("ok", false)) and bool(result.get("embercourt_all_specific", false))
	return result
