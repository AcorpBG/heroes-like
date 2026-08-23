extends "res://tests/town_embercourt_production_dwelling_icon_report.gd"

const THORNWAKE_FINAL_AUTHORED_BUILDING_IDS := [
	"building_thornwake_rootlaw_moot",
	"building_thornwake_pollen_litany",
	"building_thornwake_root_cairn_watch",
	"building_thornwake_mycorrhizal_store",
	"building_thornwake_sap_chandler_grove",
	"building_thornwake_rootroad_markers",
	"building_thornwake_rootweave_tithe",
	"building_thornwake_bramblewall_coppice",
	"building_thornwake_bastion_seed_conclave",
	"building_thornwake_bramble_marshal_moot",
	"building_thornwake_spore_oath_chantry",
	"building_thornwake_thornwarden_husk_yard",
	"building_thornwake_old_grove_accord",
	"building_thornwake_verdant_concord_seat",
]

func _target_building_ids() -> Array:
	return THORNWAKE_FINAL_AUTHORED_BUILDING_IDS

func _report_marker() -> String:
	return "TOWN_THORNWAKE_COMPLETE_AUTHORED_BUILDING_ICON_REPORT"

func _catalog_contract() -> Dictionary:
	var result: Dictionary = super._catalog_contract()
	var thornwake_town_ids := []
	var remaining_fallback_ids := []
	for town_id in ContentService.get_content_ids(ContentService.TOWNS_PATH):
		var town_template: Dictionary = ContentService.get_town(town_id)
		if String(town_template.get("faction_id", "")) != "faction_thornwake":
			continue
		thornwake_town_ids.append(town_id)
		var building_ids := []
		building_ids.append_array(town_template.get("starting_building_ids", []))
		building_ids.append_array(town_template.get("buildable_building_ids", []))
		for building_id in building_ids:
			if ContentService.get_building_art(String(building_id)).is_empty() and String(building_id) not in remaining_fallback_ids:
				remaining_fallback_ids.append(String(building_id))
	result["thornwake_town_ids"] = thornwake_town_ids
	result["thornwake_town_count"] = thornwake_town_ids.size()
	result["remaining_thornwake_fallback_ids"] = remaining_fallback_ids
	result["thornwake_all_specific"] = thornwake_town_ids.size() == 2 and remaining_fallback_ids.is_empty()
	result["ok"] = bool(result.get("ok", false)) and bool(result.get("thornwake_all_specific", false))
	return result
