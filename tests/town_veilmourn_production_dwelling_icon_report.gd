extends "res://tests/town_embercourt_production_dwelling_icon_report.gd"

const VEILMOURN_TARGET_BUILDING_IDS := [
	"building_veilmourn_bell_harbor",
	"building_veilmourn_ransom_exchange",
	"building_veilmourn_mirror_drydock",
	"building_veilmourn_harpoon_gantry",
	"building_veilmourn_obituary_vault",
	"building_veilmourn_mistgate_slip",
	"building_veilmourn_leviathan_sounding",
]

func _target_building_ids() -> Array:
	return VEILMOURN_TARGET_BUILDING_IDS

func _report_marker() -> String:
	return "TOWN_VEILMOURN_PRODUCTION_DWELLING_ICON_REPORT"
