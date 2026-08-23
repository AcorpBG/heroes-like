extends "res://tests/town_embercourt_production_dwelling_icon_report.gd"

const MIRECLAW_TARGET_BUILDING_IDS := [
	"building_mireclaw_blackbranch_den",
	"building_mireclaw_war_drum_circle",
	"building_mireclaw_floodtide_forge",
	"building_mireclaw_chainboom_ferry",
	"building_mireclaw_sporewake_shrine",
	"building_mireclaw_nightglass_dominion",
	"building_mireclaw_antler_pit",
]

func _target_building_ids() -> Array:
	return MIRECLAW_TARGET_BUILDING_IDS

func _report_marker() -> String:
	return "TOWN_MIRECLAW_PRODUCTION_DWELLING_ICON_REPORT"
