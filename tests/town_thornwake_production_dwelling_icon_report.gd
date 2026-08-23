extends "res://tests/town_embercourt_production_dwelling_icon_report.gd"

const THORNWAKE_TARGET_BUILDING_IDS := [
	"building_thornwake_seed_vault",
	"building_thornwake_bramble_toll",
	"building_thornwake_sporeglass_hothouse",
	"building_thornwake_barkmantle_run",
	"building_thornwake_pilgrim_orchard",
	"building_thornwake_graftworks",
	"building_thornwake_worldroot_gate",
]

func _target_building_ids() -> Array:
	return THORNWAKE_TARGET_BUILDING_IDS

func _report_marker() -> String:
	return "TOWN_THORNWAKE_PRODUCTION_DWELLING_ICON_REPORT"
