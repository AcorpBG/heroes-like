extends "res://tests/town_embercourt_production_dwelling_icon_report.gd"

const SUNVAULT_TARGET_BUILDING_IDS := [
	"building_sunvault_shard_yard",
	"building_sunvault_lens_gallery",
	"building_sunvault_mirror_forge",
	"building_sunvault_harmonic_cloister",
	"building_sunvault_zenith_observatory",
	"building_sunvault_aurora_spire",
	"building_sunvault_daybreak_matrix",
]

func _target_building_ids() -> Array:
	return SUNVAULT_TARGET_BUILDING_IDS

func _report_marker() -> String:
	return "TOWN_SUNVAULT_PRODUCTION_DWELLING_ICON_REPORT"
