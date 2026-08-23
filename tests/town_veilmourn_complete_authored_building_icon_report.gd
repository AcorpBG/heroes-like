extends "res://tests/town_embercourt_production_dwelling_icon_report.gd"

const VEILMOURN_FINAL_AUTHORED_BUILDING_IDS := [
	"building_veilmourn_bell_chain_watch",
	"building_veilmourn_black_sail_loft",
	"building_veilmourn_drowned_admiralty",
	"building_veilmourn_drowned_map_room",
	"building_veilmourn_fog_signal_buoys",
	"building_veilmourn_memory_anchor",
	"building_veilmourn_memory_rite_court",
	"building_veilmourn_mourner_pilot_guild",
	"building_veilmourn_salt_counting_house",
	"building_veilmourn_saltwake_factor",
	"building_veilmourn_tideglass_chapel",
	"building_veilmourn_wake_oratory",
]

func _target_building_ids() -> Array:
	return VEILMOURN_FINAL_AUTHORED_BUILDING_IDS

func _report_marker() -> String:
	return "TOWN_VEILMOURN_COMPLETE_AUTHORED_BUILDING_ICON_REPORT"

func _catalog_contract() -> Dictionary:
	var result: Dictionary = super._catalog_contract()
	var veilmourn_town_ids := []
	var remaining_fallback_ids := []
	for town_id in ContentService.get_content_ids(ContentService.TOWNS_PATH):
		var town_template: Dictionary = ContentService.get_town(town_id)
		if String(town_template.get("faction_id", "")) != "faction_veilmourn":
			continue
		veilmourn_town_ids.append(town_id)
		var building_ids := []
		building_ids.append_array(town_template.get("starting_building_ids", []))
		building_ids.append_array(town_template.get("buildable_building_ids", []))
		for building_id in building_ids:
			if ContentService.get_building_art(String(building_id)).is_empty() and String(building_id) not in remaining_fallback_ids:
				remaining_fallback_ids.append(String(building_id))
	result["veilmourn_town_ids"] = veilmourn_town_ids
	result["veilmourn_town_count"] = veilmourn_town_ids.size()
	result["remaining_veilmourn_fallback_ids"] = remaining_fallback_ids
	result["veilmourn_all_specific"] = veilmourn_town_ids.size() == 2 and remaining_fallback_ids.is_empty()
	result["ok"] = bool(result.get("ok", false)) and bool(result.get("veilmourn_all_specific", false))
	return result
