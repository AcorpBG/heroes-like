extends "res://tests/town_embercourt_production_dwelling_icon_report.gd"

const FACTION_FOUNDATIONAL_ECONOMY_BUILDING_IDS := [
	"building_embercourt_lockhouse_tally",
	"building_mireclaw_reed_toll",
	"building_sunvault_lens_tithe",
	"building_thornwake_loam_ledger",
	"building_brasshollow_scalehouse",
	"building_veilmourn_salvage_ledger",
]

func _target_building_ids() -> Array:
	return FACTION_FOUNDATIONAL_ECONOMY_BUILDING_IDS

func _report_marker() -> String:
	return "TOWN_FACTION_FOUNDATIONAL_ECONOMY_BUILDING_ICON_REPORT"
