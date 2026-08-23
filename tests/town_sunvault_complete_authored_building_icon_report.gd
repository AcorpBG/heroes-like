extends "res://tests/town_embercourt_production_dwelling_icon_report.gd"

const SUNVAULT_FINAL_AUTHORED_BUILDING_IDS := [
	"building_shard_yard",
	"building_sunvault_relay_scribes",
	"building_prism_range",
	"building_mirror_forge",
	"building_lens_gallery",
	"building_duel_circle",
	"building_resonant_exchange",
	"building_harmonic_cloister",
	"building_aurora_spire",
	"building_daybreak_matrix",
	"building_sunvault_prism_oratory",
	"building_sunvault_halo_battery_yard",
	"building_sunvault_zenith_court",
]

func _target_building_ids() -> Array:
	return SUNVAULT_FINAL_AUTHORED_BUILDING_IDS

func _report_marker() -> String:
	return "TOWN_SUNVAULT_COMPLETE_AUTHORED_BUILDING_ICON_REPORT"

func _catalog_contract() -> Dictionary:
	var result: Dictionary = super._catalog_contract()
	var sunvault_town_ids := []
	var remaining_fallback_ids := []
	for town_id in ContentService.get_content_ids(ContentService.TOWNS_PATH):
		var town_template: Dictionary = ContentService.get_town(town_id)
		if String(town_template.get("faction_id", "")) != "faction_sunvault":
			continue
		sunvault_town_ids.append(town_id)
		var building_ids := []
		building_ids.append_array(town_template.get("starting_building_ids", []))
		building_ids.append_array(town_template.get("buildable_building_ids", []))
		for building_id in building_ids:
			if ContentService.get_building_art(String(building_id)).is_empty() and String(building_id) not in remaining_fallback_ids:
				remaining_fallback_ids.append(String(building_id))
	result["sunvault_town_ids"] = sunvault_town_ids
	result["sunvault_town_count"] = sunvault_town_ids.size()
	result["remaining_sunvault_fallback_ids"] = remaining_fallback_ids
	result["sunvault_all_specific"] = sunvault_town_ids.size() == 2 and remaining_fallback_ids.is_empty()
	result["ok"] = bool(result.get("ok", false)) and bool(result.get("sunvault_all_specific", false))
	return result
