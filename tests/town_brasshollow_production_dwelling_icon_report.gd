extends "res://tests/town_embercourt_production_dwelling_icon_report.gd"

const BRASSHOLLOW_TARGET_BUILDING_IDS := [
	"building_brasshollow_ore_tithe_office",
	"building_brasshollow_rivet_kennels",
	"building_brasshollow_pavis_foundry",
	"building_brasshollow_boiler_cathedral",
	"building_brasshollow_pressure_rail",
	"building_brasshollow_crucible_dock",
	"building_brasshollow_titan_charter_hall",
]

func _target_building_ids() -> Array:
	return BRASSHOLLOW_TARGET_BUILDING_IDS

func _report_marker() -> String:
	return "TOWN_BRASSHOLLOW_PRODUCTION_DWELLING_ICON_REPORT"
