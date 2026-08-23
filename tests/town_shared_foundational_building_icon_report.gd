extends "res://tests/town_embercourt_production_dwelling_icon_report.gd"

const SHARED_FOUNDATIONAL_BUILDING_IDS := [
	"building_town_hall",
	"building_market_square",
	"building_wayfarers_hall",
	"building_stone_store",
	"building_lantern_archive",
	"building_starseer_annex",
]

func _target_building_ids() -> Array:
	return SHARED_FOUNDATIONAL_BUILDING_IDS

func _report_marker() -> String:
	return "TOWN_SHARED_FOUNDATIONAL_BUILDING_ICON_REPORT"
