extends "res://tests/town_embercourt_production_dwelling_icon_report.gd"

const BRASSHOLLOW_FINAL_AUTHORED_BUILDING_IDS := [
	"building_brasshollow_clause_court",
	"building_brasshollow_heatwright_vestry",
	"building_brasshollow_gauge_arsenal",
	"building_brasshollow_debtworks_vault",
	"building_brasshollow_ledger_mint",
	"building_brasshollow_foreman_clausehouse",
	"building_brasshollow_caliper_sanctum",
	"building_brasshollow_redline_assembly_yard",
	"building_brasshollow_brassbound_directorate",
	"building_brasshollow_quenchwright_bay",
	"building_brasshollow_rail_tax_office",
	"building_brasshollow_warrant_engine_house",
]

func _target_building_ids() -> Array:
	return BRASSHOLLOW_FINAL_AUTHORED_BUILDING_IDS

func _report_marker() -> String:
	return "TOWN_BRASSHOLLOW_COMPLETE_AUTHORED_BUILDING_ICON_REPORT"

func _catalog_contract() -> Dictionary:
	var result: Dictionary = super._catalog_contract()
	var brasshollow_town_ids := []
	var remaining_fallback_ids := []
	for town_id in ContentService.get_content_ids(ContentService.TOWNS_PATH):
		var town_template: Dictionary = ContentService.get_town(town_id)
		if String(town_template.get("faction_id", "")) != "faction_brasshollow":
			continue
		brasshollow_town_ids.append(town_id)
		var building_ids := []
		building_ids.append_array(town_template.get("starting_building_ids", []))
		building_ids.append_array(town_template.get("buildable_building_ids", []))
		for building_id in building_ids:
			if ContentService.get_building_art(String(building_id)).is_empty() and String(building_id) not in remaining_fallback_ids:
				remaining_fallback_ids.append(String(building_id))
	result["brasshollow_town_ids"] = brasshollow_town_ids
	result["brasshollow_town_count"] = brasshollow_town_ids.size()
	result["remaining_brasshollow_fallback_ids"] = remaining_fallback_ids
	result["brasshollow_all_specific"] = brasshollow_town_ids.size() == 2 and remaining_fallback_ids.is_empty()
	result["ok"] = bool(result.get("ok", false)) and bool(result.get("brasshollow_all_specific", false))
	return result
