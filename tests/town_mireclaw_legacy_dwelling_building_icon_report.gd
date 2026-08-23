extends "res://tests/town_embercourt_production_dwelling_icon_report.gd"

const MIRECLAW_LEGACY_DWELLING_BUILDING_IDS := [
	"building_blackbranch_den",
	"building_mire_pens",
	"building_reed_warren",
	"building_slingers_post",
	"building_rot_warren",
	"building_fenscale_pens",
	"building_gorefen_ring",
]

func _target_building_ids() -> Array:
	return MIRECLAW_LEGACY_DWELLING_BUILDING_IDS

func _report_marker() -> String:
	return "TOWN_MIRECLAW_LEGACY_DWELLING_BUILDING_ICON_REPORT"
