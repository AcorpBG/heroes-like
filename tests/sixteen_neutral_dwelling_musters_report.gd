extends "res://tests/eight_neutral_dwelling_musters_report.gd"

const BATCH_REPORT_ID := "SIXTEEN_NEUTRAL_DWELLING_MUSTERS_REPORT"
const BATCH_OUTPUT_DIR := "res://.artifacts/sixteen_neutral_dwelling_musters_report"
const BATCH_ATLAS_PATH := "res://art/overworld/runtime/objects/resource_sites/remaining_neutral_dwelling_claimed_atlas.png"
const BATCH_CASES := [
	{"scenario_id":"loamchant-orchard-binding","site_id":"site_orchard_levy","placement_id":"loamchant_watch_dwelling","guard_id":"loamchant_orchard_levy_watch","encounter_id":"encounter_orchard_levy_watch","unclaimed":"mapobj_orchard_levy","claimed":"resource_site_neutral_orchard_levy_claimed","region":Rect2(0,0,48,48)},
	{"scenario_id":"mossvein-switchback-circuit","site_id":"site_bramble_hedge","placement_id":"mossvein_feature_3","guard_id":"mossvein_bramble_hedge_watch","encounter_id":"encounter_bramble_hedge_watch","unclaimed":"mapobj_bramble_hedge","claimed":"resource_site_neutral_bramble_hedge_claimed","region":Rect2(48,0,48,48)},
	{"scenario_id":"vowless-saltpan-circuit","site_id":"site_tidepool_skiffyard","placement_id":"vowless_feature_3","guard_id":"vowless_tidepool_skiffyard_watch","encounter_id":"encounter_tidepool_skiffyard_watch","unclaimed":"mapobj_tidepool_skiffyard","claimed":"resource_site_neutral_tidepool_skiffyard_claimed","region":Rect2(96,0,48,48)},
	{"scenario_id":"mossvein-switchback-circuit","site_id":"site_switchback_hostel","placement_id":"mossvein_watch_dwelling","guard_id":"mossvein_switchback_hostel_watch","encounter_id":"encounter_switchback_hostel_watch","unclaimed":"mapobj_switchback_hostel","claimed":"resource_site_neutral_switchback_hostel_claimed","region":Rect2(144,0,48,48)},
	{"scenario_id":"vowless-saltpan-circuit","site_id":"site_saltpan_camp","placement_id":"vowless_watch_dwelling","guard_id":"vowless_saltpan_camp_watch","encounter_id":"encounter_saltpan_camp_watch","unclaimed":"mapobj_saltpan_camp","claimed":"resource_site_neutral_saltpan_camp_claimed","region":Rect2(192,0,48,48)},
	{"scenario_id":"sunvein-crystal-sump-circuit","site_id":"site_crystal_sump","placement_id":"sunvein_watch_dwelling","guard_id":"sunvein_crystal_sump_watch","encounter_id":"encounter_crystal_sump_watch","unclaimed":"mapobj_crystal_sump","claimed":"resource_site_neutral_crystal_sump_claimed","region":Rect2(240,0,48,48)},
	{"scenario_id":"halometer-icehook-convergence","site_id":"site_icehook_trapper_lodge","placement_id":"halometer_primary_site","guard_id":"halometer_icehook_trapper_lodge_watch","encounter_id":"encounter_icehook_trapper_lodge_watch","unclaimed":"mapobj_icehook_trapper_lodge","claimed":"resource_site_neutral_icehook_trapper_lodge_claimed","region":Rect2(288,0,48,48)},
	{"scenario_id":"heatpriest-obsidian-scar","site_id":"site_obsidian_scar","placement_id":"heatpriest_watch_dwelling","guard_id":"heatpriest_obsidian_scar_watch","encounter_id":"encounter_obsidian_scar_watch","unclaimed":"mapobj_obsidian_scar","claimed":"resource_site_neutral_obsidian_scar_claimed","region":Rect2(336,0,48,48)},
	{"scenario_id":"mirrorbell-harbor-echo","site_id":"site_harbor_pilot_house","placement_id":"mirrorbell_watch_dwelling","guard_id":"mirrorbell_harbor_pilot_house_watch","encounter_id":"encounter_harbor_pilot_house_watch","unclaimed":"mapobj_harbor_pilot_house","claimed":"resource_site_neutral_harbor_pilot_house_claimed","region":Rect2(384,0,48,48)},
	{"scenario_id":"daynote-kite-signal-accord","site_id":"site_kite_signal_eyrie","placement_id":"daynote_watch_dwelling","guard_id":"daynote_kite_signal_eyrie_watch","encounter_id":"encounter_kite_signal_eyrie_watch","unclaimed":"mapobj_kite_signal_eyrie","claimed":"resource_site_neutral_kite_signal_eyrie_claimed","region":Rect2(432,0,48,48)},
	{"scenario_id":"graftsibyl-lantern-convergence","site_id":"site_lantern_warren","placement_id":"graftsibyl_primary_site","guard_id":"graftsibyl_lantern_warren_watch","encounter_id":"encounter_lantern_warren_watch","unclaimed":"mapobj_lantern_warren","claimed":"resource_site_neutral_lantern_warren_claimed","region":Rect2(480,0,48,48)},
	{"scenario_id":"fenwake-bogbell-convergence","site_id":"site_bogbell_croft","placement_id":"fenwake_primary_site","guard_id":"fenwake_bogbell_croft_watch","encounter_id":"encounter_bogbell_croft_watch","unclaimed":"mapobj_bogbell_croft","claimed":"resource_site_neutral_bogbell_croft_claimed","region":Rect2(528,0,48,48)},
	{"scenario_id":"gaugesavant-milestone-calibration","site_id":"site_milestone_arsenal","placement_id":"gaugesavant_watch_dwelling","guard_id":"gaugesavant_milestone_arsenal_watch","encounter_id":"encounter_milestone_arsenal_watch","unclaimed":"mapobj_milestone_arsenal","claimed":"resource_site_neutral_milestone_arsenal_claimed","region":Rect2(576,0,48,48)},
	{"scenario_id":"obituaryink-frostwharf-house","site_id":"site_frostwharf_house","placement_id":"obituaryink_watch_dwelling","guard_id":"obituaryink_frostwharf_house_watch","encounter_id":"encounter_frostwharf_house_watch","unclaimed":"mapobj_frostwharf_house","claimed":"resource_site_neutral_frostwharf_house_claimed","region":Rect2(624,0,48,48)},
	{"scenario_id":"rainledger-cinder-convergence","site_id":"site_charcoal_burners","placement_id":"rainledger_primary_site","guard_id":"rainledger_charcoal_burners_watch","encounter_id":"encounter_charcoal_burners_watch","unclaimed":"mapobj_charcoal_burners","claimed":"resource_site_neutral_charcoal_burners_claimed","region":Rect2(672,0,48,48)},
	{"scenario_id":"debtrune-default-convergence","site_id":"site_basalt_gatehouse","placement_id":"debtrune_feature_2","guard_id":"debtrune_basalt_gatehouse_watch","encounter_id":"encounter_basalt_gatehouse_watch","unclaimed":"mapobj_basalt_gatehouse","claimed":"resource_site_neutral_basalt_gatehouse_claimed","region":Rect2(720,0,48,48)}
]


func _report_id() -> String:
	return BATCH_REPORT_ID


func _output_dir() -> String:
	return BATCH_OUTPUT_DIR


func _atlas_path() -> String:
	return BATCH_ATLAS_PATH


func _capture_environment_name() -> String:
	return "REMAINING_NEUTRAL_DWELLING_CAPTURE_DIR"


func _cases() -> Array:
	return BATCH_CASES
