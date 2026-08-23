extends "res://tests/town_embercourt_production_dwelling_icon_report.gd"

const MIRECLAW_UNIQUE_LANDMARK_BUILDING_IDS := [
	"building_mireclaw_silt_watch",
	"building_mireclaw_bog_oracle_nest",
	"building_mireclaw_boneboom_palisade",
	"building_mireclaw_oathmire_court",
]

func _target_building_ids() -> Array:
	return MIRECLAW_UNIQUE_LANDMARK_BUILDING_IDS

func _report_marker() -> String:
	return "TOWN_MIRECLAW_UNIQUE_LANDMARK_BUILDING_ICON_REPORT"
