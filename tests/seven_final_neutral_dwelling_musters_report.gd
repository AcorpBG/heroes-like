extends "res://tests/eight_neutral_dwelling_musters_report.gd"

const BATCH_REPORT_ID := "SEVEN_FINAL_NEUTRAL_DWELLING_MUSTERS_REPORT"
const BATCH_OUTPUT_DIR := "res://.artifacts/seven_final_neutral_dwelling_musters_report"
const BATCH_ATLAS_PATH := "res://art/overworld/runtime/objects/resource_sites/final_neutral_dwelling_claimed_atlas.png"
const BATCH_CASES := [
	{"scenario_id":"ninefold-confluence","site_id":"site_salt_skirmisher_pier","placement_id":"dwelling_salt_skirmisher_pier","guard_id":"ninefold_salt_skirmisher_pier_watch","encounter_id":"encounter_saltpan_camp_watch","unclaimed":"mapobj_salt_skirmisher_pier","claimed":"resource_site_neutral_salt_skirmisher_pier_claimed","region":Rect2(0,0,48,48)},
	{"scenario_id":"ninefold-confluence","site_id":"site_ember_cart_yard","placement_id":"dwelling_ember_cart_yard","guard_id":"ninefold_ember_cart_yard_watch","encounter_id":"encounter_charcoal_burners_watch","unclaimed":"mapobj_ember_cart_yard","claimed":"resource_site_neutral_ember_cart_yard_claimed","region":Rect2(48,0,48,48)},
	{"scenario_id":"ninefold-confluence","site_id":"site_prism_outrider_post","placement_id":"dwelling_prism_outrider_post","guard_id":"ninefold_prism_outrider_post_watch","encounter_id":"encounter_kite_signal_eyrie_watch","unclaimed":"mapobj_prism_outrider_post","claimed":"resource_site_neutral_prism_outrider_post_claimed","region":Rect2(96,0,48,48)},
	{"scenario_id":"ninefold-confluence","site_id":"site_storm_rook_eyrie","placement_id":"dwelling_storm_rook_eyrie","guard_id":"ninefold_storm_rook_eyrie_watch","encounter_id":"encounter_cliffhawk_roost_watch","unclaimed":"mapobj_storm_rook_eyrie","claimed":"resource_site_neutral_storm_rook_eyrie_claimed","region":Rect2(144,0,48,48)},
	{"scenario_id":"ninefold-confluence","site_id":"site_mirror_bound_barracks","placement_id":"dwelling_mirror_bound_barracks","guard_id":"ninefold_mirror_bound_barracks_watch","encounter_id":"encounter_crystal_sump_watch","unclaimed":"mapobj_mirror_bound_barracks","claimed":"resource_site_neutral_mirror_bound_barracks_claimed","region":Rect2(192,0,48,48)},
	{"scenario_id":"ninefold-confluence","site_id":"site_furnace_oath_yard","placement_id":"dwelling_furnace_oath_yard","guard_id":"ninefold_furnace_oath_yard_watch","encounter_id":"encounter_cinder_kiln_watch","unclaimed":"mapobj_furnace_oath_yard","claimed":"resource_site_neutral_furnace_oath_yard_claimed","region":Rect2(240,0,48,48)},
	{"scenario_id":"ninefold-confluence","site_id":"site_drowned_crown_hall","placement_id":"dwelling_drowned_crown_hall","guard_id":"ninefold_drowned_crown_hall_watch","encounter_id":"encounter_tidepool_skiffyard_watch","unclaimed":"mapobj_drowned_crown_hall","claimed":"resource_site_neutral_drowned_crown_hall_claimed","region":Rect2(288,0,48,48)}
]


func _report_id() -> String:
	return BATCH_REPORT_ID


func _output_dir() -> String:
	return BATCH_OUTPUT_DIR


func _atlas_path() -> String:
	return BATCH_ATLAS_PATH


func _capture_environment_name() -> String:
	return "FINAL_NEUTRAL_DWELLING_CAPTURE_DIR"


func _cases() -> Array:
	return BATCH_CASES
