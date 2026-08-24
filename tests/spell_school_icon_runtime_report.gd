extends Node

const SessionDataScript = preload("res://scripts/core/SessionStateStore.gd")
const REPORT_ID := "SPELL_SCHOOL_ICON_RUNTIME_REPORT"
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const SURFACES := ["overworld", "town", "battle"]
const GENERATED_MAP_MODEL_PATH := "res://content/random_map_generator_data_model.json"
const TARGET_BEACON_REWARD_SPELL_IDS := [
	"spell_beacon_column_charge_11",
	"spell_beacon_lantern_oath_17",
	"spell_beacon_roadward_charge_23",
	"spell_beacon_bell_ward_09",
	"spell_beacon_bell_lance_25",
]
const TARGET_MIRE_REWARD_SPELL_IDS := [
	"spell_mire_bog_drum_18",
	"spell_mire_brine_fenlight_24",
	"spell_mire_leech_snare_10",
]
const TARGET_MIRE_BATTLE_REWARD_SPELL_IDS := [
	"spell_mire_bog_drum_18",
	"spell_mire_leech_snare_10",
]
const TARGET_FURNACE_REWARD_SPELL_IDS := [
	"spell_furnace_foundry_bellows_11",
	"spell_furnace_brass_bellows_23",
	"spell_furnace_ash_mantle_09",
	"spell_furnace_ash_rail_25",
]
const TARGET_FURNACE_BATTLE_REWARD_SPELL_IDS := [
	"spell_furnace_foundry_bellows_11",
	"spell_furnace_brass_bellows_23",
	"spell_furnace_ash_mantle_09",
]
const TARGET_ROOT_REWARD_SPELL_IDS := [
	"spell_root_canopy_thorn_22",
	"spell_root_bark_bark_08",
	"spell_root_bark_rootway_24",
	"spell_root_bloom_bark_20",
]
const TARGET_ROOT_BATTLE_REWARD_SPELL_IDS := [
	"spell_root_canopy_thorn_22",
	"spell_root_bark_bark_08",
	"spell_root_bloom_bark_20",
]
const TARGET_VEIL_REWARD_SPELL_IDS := [
	"spell_veil_mourning_mark_04",
	"spell_veil_mist_shroud_10",
	"spell_veil_moon_drift_12",
	"spell_veil_moon_mark_28",
]
const TARGET_VEIL_BATTLE_REWARD_SPELL_IDS := [
	"spell_veil_mourning_mark_04",
	"spell_veil_mist_shroud_10",
	"spell_veil_moon_mark_28",
]
const TARGET_OLD_MEASURE_REWARD_SPELL_IDS := [
	"spell_old_measure_marker_tally_08",
	"spell_old_measure_count_survey_14",
	"spell_old_measure_compass_correction_22",
	"spell_old_measure_count_boundary_30",
]
const TARGET_OLD_MEASURE_BATTLE_REWARD_SPELL_IDS := [
	"spell_old_measure_marker_tally_08",
	"spell_old_measure_compass_correction_22",
	"spell_old_measure_count_boundary_30",
]
const TARGET_LENS_REWARD_SPELL_IDS := [
	"spell_lens_array_ray_06",
	"spell_lens_array_chorus_22",
	"spell_lens_glass_facet_08",
	"spell_lens_focus_array_14",
	"spell_lens_aurora_chorus_10",
]
const TARGET_LENS_BATTLE_REWARD_SPELL_IDS := [
	"spell_lens_array_ray_06",
	"spell_lens_array_chorus_22",
	"spell_lens_glass_facet_08",
	"spell_lens_focus_array_14",
	"spell_lens_aurora_chorus_10",
]
const TARGET_LENS_TOWN_STUDY_SPELL_IDS := [
	"spell_lens_mirror_prism_04",
	"spell_lens_starlens_survey_12",
	"spell_lens_crown_prism_16",
	"spell_lens_halo_ray_18",
	"spell_lens_mirror_facet_20",
	"spell_lens_glass_survey_24",
	"spell_lens_aurora_array_26",
	"spell_lens_starlens_prism_28",
]
const TARGET_LENS_TOWN_SCENARIOS := {
	"prismhearth-watch": "town_prismhearth",
	"halo-reserve-refraction-claim": "town_halo_spire",
}
const TARGET_LENS_TOWN_STUDY_BUILDING_IDS := [
	"building_lantern_archive",
	"building_starseer_annex",
	"building_sunvault_zenith_observatory",
	"building_sunvault_prism_oratory",
	"building_sunvault_daybreak_matrix",
]
const TARGET_BEACON_TOWN_STUDY_SPELL_IDS := [
	"spell_beacon_roadward_signal_07",
	"spell_beacon_writ_lance_13",
	"spell_beacon_waymark_road_15",
	"spell_beacon_crown_signal_19",
	"spell_beacon_dawn_ward_21",
]
const TARGET_BEACON_TOWN_SCENARIOS := {
	"river-pass": "town_riverwatch",
	"stonewake-watch": "town_highwater_keep",
}
const TARGET_BEACON_TOWN_STUDY_BUILDING_IDS := [
	"building_lantern_archive",
	"building_starseer_annex",
	"building_embercourt_beacon_court",
	"building_embercourt_lantern_court",
	"building_embercourt_relief_quay",
]
const TARGET_FURNACE_TOWN_STUDY_SPELL_IDS := [
	"spell_furnace_rivet_clause_05",
	"spell_furnace_brass_rite_07",
	"spell_furnace_hammer_rail_13",
	"spell_furnace_slag_clamp_15",
	"spell_furnace_coal_clause_17",
	"spell_furnace_kiln_rite_19",
	"spell_furnace_rivet_mantle_21",
	"spell_furnace_foundry_clamp_27",
]
const TARGET_FURNACE_TOWN_SCENARIOS := {
	"orevein-contract": "town_brasshollow_orevein_gantry",
	"clauseworks-counterclaim": "town_brasshollow_clauseworks_depot",
}
const TARGET_FURNACE_TOWN_STUDY_BUILDING_IDS := [
	"building_brasshollow_boiler_cathedral",
	"building_brasshollow_heatwright_vestry",
	"building_brasshollow_caliper_sanctum",
]
const TARGET_MIRE_TOWN_STUDY_SPELL_IDS := [
	"spell_mire_silt_rot_04",
	"spell_mire_dusk_drum_06",
	"spell_mire_brine_frenzy_08",
	"spell_mire_flood_fenlight_12",
	"spell_mire_sluice_poultice_14",
	"spell_mire_lowtide_rot_16",
	"spell_mire_silt_frenzy_20",
	"spell_mire_dusk_snare_22",
	"spell_mire_leech_poultice_26",
	"spell_mire_flood_rot_28",
]
const TARGET_MIRE_TOWN_SCENARIOS := {
	"causeway-stand": "town_duskfen",
	"bogbound-oath": "town_duskfen",
	"nightglass-ledger-reversal": "town_nightglass_redoubt",
}
const TARGET_MIRE_TOWN_STUDY_BUILDING_IDS := [
	"building_lantern_archive",
	"building_starseer_annex",
	"building_mireclaw_sporewake_shrine",
	"building_mireclaw_bog_oracle_nest",
	"building_mireclaw_boneboom_palisade",
]
const TARGET_OLD_MEASURE_TOWN_STUDY_SPELL_IDS := [
	"spell_old_measure_survey_survey_02",
	"spell_old_measure_tally_axiom_04",
	"spell_old_measure_index_correction_10",
	"spell_old_measure_proof_pace_12",
	"spell_old_measure_measure_axiom_16",
	"spell_old_measure_survey_boundary_18",
	"spell_old_measure_tally_tally_20",
	"spell_old_measure_marker_pace_24",
	"spell_old_measure_index_survey_26",
	"spell_old_measure_proof_axiom_28",
]
const TARGET_OLD_MEASURE_TOWN_SCENARIOS := {
	"orevein-contract": "town_brasshollow_orevein_gantry",
	"clauseworks-counterclaim": "town_brasshollow_clauseworks_depot",
	"bellwake-wreck-claim": "town_veilmourn_bellwake_harbor",
	"fogchart-mooring": "town_veilmourn_fogchart_mooring",
}
const TARGET_OLD_MEASURE_TOWN_STUDY_BUILDING_IDS := {
	"orevein-contract": ["building_brasshollow_boiler_cathedral", "building_brasshollow_heatwright_vestry", "building_brasshollow_caliper_sanctum"],
	"clauseworks-counterclaim": ["building_brasshollow_boiler_cathedral", "building_brasshollow_heatwright_vestry", "building_brasshollow_caliper_sanctum"],
	"bellwake-wreck-claim": ["building_veilmourn_obituary_vault", "building_veilmourn_wake_oratory", "building_veilmourn_tideglass_chapel"],
	"fogchart-mooring": ["building_veilmourn_obituary_vault", "building_veilmourn_wake_oratory", "building_veilmourn_tideglass_chapel"],
}
const TARGET_VEIL_TOWN_STUDY_SPELL_IDS := [
	"spell_veil_salt_step_06",
	"spell_veil_tide_fogbind_08",
	"spell_veil_wraith_duel_14",
	"spell_veil_lantern_mark_16",
	"spell_veil_obituary_step_18",
	"spell_veil_mourning_fogbind_20",
	"spell_veil_salt_shroud_22",
	"spell_veil_tide_drift_24",
	"spell_veil_mist_duel_26",
]
const TARGET_VEIL_TOWN_SCENARIOS := {
	"bellwake-wreck-claim": "town_veilmourn_bellwake_harbor",
	"fogchart-mooring": "town_veilmourn_fogchart_mooring",
}
const TARGET_VEIL_TOWN_STUDY_BUILDING_IDS := [
	"building_veilmourn_obituary_vault",
	"building_veilmourn_wake_oratory",
	"building_veilmourn_tideglass_chapel",
]
const TARGET_ROOT_TOWN_STUDY_SPELL_IDS := [
	"spell_root_bloom_briar_04", "spell_root_canopy_graft_06", "spell_root_loam_thorn_10", "spell_root_green_rootway_12", "spell_root_branch_bloom_14",
	"spell_root_wild_briar_16", "spell_root_graft_graft_18", "spell_root_loam_bloom_26", "spell_root_green_briar_28",
]
const TARGET_ROOT_TOWN_SCENARIOS := {
	"mireford-skirmish": "town_thornwake_graftroot_caravan",
	"rootgate-toll": "town_thornwake_rootgate_nursery",
}
const TARGET_ROOT_TOWN_STUDY_BUILDING_IDS := [
	"building_thornwake_sporeglass_hothouse", "building_thornwake_pollen_litany", "building_thornwake_spore_oath_chantry",
]
const SURFACE_SPELL_IDS := {
	"overworld": "spell_waystride",
	"battle": "spell_bulwark_litany",
}
const EXPECTED_SIGNATURE_ICONS := {
	"spell_bulwark_litany": "res://art/magic/runtime/spells/spell_bulwark_litany.png",
	"spell_coal_rain": "res://art/magic/runtime/spells/spell_coal_rain.png",
	"spell_sunlance_arc": "res://art/magic/runtime/spells/spell_sunlance_arc.png",
	"spell_briar_bind": "res://art/magic/runtime/spells/spell_briar_bind.png",
	"spell_cinder_burst": "res://art/magic/runtime/spells/spell_cinder_burst.png",
	"spell_fogwake_step": "res://art/magic/runtime/spells/spell_fogwake_step.png",
	"spell_old_measure_compass_boundary_06": "res://art/magic/runtime/spells/spell_old_measure_compass_boundary_06.png",
	"spell_stone_veil": "res://art/magic/runtime/spells/spell_stone_veil.png",
	"spell_quickmarch_hymn": "res://art/magic/runtime/spells/spell_quickmarch_hymn.png",
	"spell_relay_drum": "res://art/magic/runtime/spells/spell_relay_drum.png",
	"spell_resonant_chorus": "res://art/magic/runtime/spells/spell_resonant_chorus.png",
	"spell_bloodwake_drum": "res://art/magic/runtime/spells/spell_bloodwake_drum.png",
	"spell_trailglyph": "res://art/magic/runtime/spells/spell_trailglyph.png",
	"spell_prism_bastion": "res://art/magic/runtime/spells/spell_prism_bastion.png",
	"spell_lantern_phalanx": "res://art/magic/runtime/spells/spell_lantern_phalanx.png",
	"spell_survey_chain": "res://art/magic/runtime/spells/spell_survey_chain.png",
	"spell_graft_mend": "res://art/magic/runtime/spells/spell_graft_mend.png",
	"spell_heat_rite": "res://art/magic/runtime/spells/spell_heat_rite.png",
	"spell_obituary_mark": "res://art/magic/runtime/spells/spell_obituary_mark.png",
	"spell_pressure_clause": "res://art/magic/runtime/spells/spell_pressure_clause.png",
	"spell_beacon_path": "res://art/magic/runtime/spells/spell_beacon_path.png",
	"spell_waystride": "res://art/magic/runtime/spells/spell_waystride.png",
	"spell_fogline_drift": "res://art/magic/runtime/spells/spell_fogline_drift.png",
	"spell_rootway_tangle": "res://art/magic/runtime/spells/spell_rootway_tangle.png",
	"spell_beacon_column_charge_11": "res://art/magic/runtime/spells/spell_beacon_column_charge_11.png",
	"spell_beacon_lantern_oath_17": "res://art/magic/runtime/spells/spell_beacon_lantern_oath_17.png",
	"spell_beacon_roadward_charge_23": "res://art/magic/runtime/spells/spell_beacon_roadward_charge_23.png",
	"spell_beacon_bell_ward_09": "res://art/magic/runtime/spells/spell_beacon_bell_ward_09.png",
	"spell_beacon_bell_lance_25": "res://art/magic/runtime/spells/spell_beacon_bell_lance_25.png",
	"spell_mire_bog_drum_18": "res://art/magic/runtime/spells/spell_mire_bog_drum_18.png",
	"spell_mire_brine_fenlight_24": "res://art/magic/runtime/spells/spell_mire_brine_fenlight_24.png",
	"spell_mire_leech_snare_10": "res://art/magic/runtime/spells/spell_mire_leech_snare_10.png",
	"spell_furnace_foundry_bellows_11": "res://art/magic/runtime/spells/spell_furnace_foundry_bellows_11.png",
	"spell_furnace_brass_bellows_23": "res://art/magic/runtime/spells/spell_furnace_brass_bellows_23.png",
	"spell_furnace_ash_mantle_09": "res://art/magic/runtime/spells/spell_furnace_ash_mantle_09.png",
	"spell_furnace_ash_rail_25": "res://art/magic/runtime/spells/spell_furnace_ash_rail_25.png",
	"spell_root_canopy_thorn_22": "res://art/magic/runtime/spells/spell_root_canopy_thorn_22.png",
	"spell_root_bark_bark_08": "res://art/magic/runtime/spells/spell_root_bark_bark_08.png",
	"spell_root_bark_rootway_24": "res://art/magic/runtime/spells/spell_root_bark_rootway_24.png",
	"spell_root_bloom_bark_20": "res://art/magic/runtime/spells/spell_root_bloom_bark_20.png",
	"spell_veil_mourning_mark_04": "res://art/magic/runtime/spells/spell_veil_mourning_mark_04.png",
	"spell_veil_mist_shroud_10": "res://art/magic/runtime/spells/spell_veil_mist_shroud_10.png",
	"spell_veil_moon_drift_12": "res://art/magic/runtime/spells/spell_veil_moon_drift_12.png",
	"spell_veil_moon_mark_28": "res://art/magic/runtime/spells/spell_veil_moon_mark_28.png",
	"spell_old_measure_marker_tally_08": "res://art/magic/runtime/spells/spell_old_measure_marker_tally_08.png",
	"spell_old_measure_count_survey_14": "res://art/magic/runtime/spells/spell_old_measure_count_survey_14.png",
	"spell_old_measure_compass_correction_22": "res://art/magic/runtime/spells/spell_old_measure_compass_correction_22.png",
	"spell_old_measure_count_boundary_30": "res://art/magic/runtime/spells/spell_old_measure_count_boundary_30.png",
	"spell_lens_array_ray_06": "res://art/magic/runtime/spells/spell_lens_array_ray_06.png",
	"spell_lens_array_chorus_22": "res://art/magic/runtime/spells/spell_lens_array_chorus_22.png",
	"spell_lens_glass_facet_08": "res://art/magic/runtime/spells/spell_lens_glass_facet_08.png",
	"spell_lens_focus_array_14": "res://art/magic/runtime/spells/spell_lens_focus_array_14.png",
	"spell_lens_aurora_chorus_10": "res://art/magic/runtime/spells/spell_lens_aurora_chorus_10.png",
	"spell_lens_mirror_prism_04": "res://art/magic/runtime/spells/spell_lens_mirror_prism_04.png",
	"spell_lens_starlens_survey_12": "res://art/magic/runtime/spells/spell_lens_starlens_survey_12.png",
	"spell_lens_crown_prism_16": "res://art/magic/runtime/spells/spell_lens_crown_prism_16.png",
	"spell_lens_halo_ray_18": "res://art/magic/runtime/spells/spell_lens_halo_ray_18.png",
	"spell_lens_mirror_facet_20": "res://art/magic/runtime/spells/spell_lens_mirror_facet_20.png",
	"spell_lens_glass_survey_24": "res://art/magic/runtime/spells/spell_lens_glass_survey_24.png",
	"spell_lens_aurora_array_26": "res://art/magic/runtime/spells/spell_lens_aurora_array_26.png",
	"spell_lens_starlens_prism_28": "res://art/magic/runtime/spells/spell_lens_starlens_prism_28.png",
	"spell_beacon_roadward_signal_07": "res://art/magic/runtime/spells/spell_beacon_roadward_signal_07.png",
	"spell_beacon_writ_lance_13": "res://art/magic/runtime/spells/spell_beacon_writ_lance_13.png",
	"spell_beacon_waymark_road_15": "res://art/magic/runtime/spells/spell_beacon_waymark_road_15.png",
	"spell_beacon_crown_signal_19": "res://art/magic/runtime/spells/spell_beacon_crown_signal_19.png",
	"spell_beacon_dawn_ward_21": "res://art/magic/runtime/spells/spell_beacon_dawn_ward_21.png",
	"spell_furnace_rivet_clause_05": "res://art/magic/runtime/spells/spell_furnace_rivet_clause_05.png",
	"spell_furnace_brass_rite_07": "res://art/magic/runtime/spells/spell_furnace_brass_rite_07.png",
	"spell_furnace_hammer_rail_13": "res://art/magic/runtime/spells/spell_furnace_hammer_rail_13.png",
	"spell_furnace_slag_clamp_15": "res://art/magic/runtime/spells/spell_furnace_slag_clamp_15.png",
	"spell_furnace_coal_clause_17": "res://art/magic/runtime/spells/spell_furnace_coal_clause_17.png",
	"spell_furnace_kiln_rite_19": "res://art/magic/runtime/spells/spell_furnace_kiln_rite_19.png",
	"spell_furnace_rivet_mantle_21": "res://art/magic/runtime/spells/spell_furnace_rivet_mantle_21.png",
	"spell_furnace_foundry_clamp_27": "res://art/magic/runtime/spells/spell_furnace_foundry_clamp_27.png",
	"spell_mire_silt_rot_04": "res://art/magic/runtime/spells/spell_mire_silt_rot_04.png",
	"spell_mire_dusk_drum_06": "res://art/magic/runtime/spells/spell_mire_dusk_drum_06.png",
	"spell_mire_brine_frenzy_08": "res://art/magic/runtime/spells/spell_mire_brine_frenzy_08.png",
	"spell_mire_flood_fenlight_12": "res://art/magic/runtime/spells/spell_mire_flood_fenlight_12.png",
	"spell_mire_sluice_poultice_14": "res://art/magic/runtime/spells/spell_mire_sluice_poultice_14.png",
	"spell_mire_lowtide_rot_16": "res://art/magic/runtime/spells/spell_mire_lowtide_rot_16.png",
	"spell_mire_silt_frenzy_20": "res://art/magic/runtime/spells/spell_mire_silt_frenzy_20.png",
	"spell_mire_dusk_snare_22": "res://art/magic/runtime/spells/spell_mire_dusk_snare_22.png",
	"spell_mire_leech_poultice_26": "res://art/magic/runtime/spells/spell_mire_leech_poultice_26.png",
	"spell_mire_flood_rot_28": "res://art/magic/runtime/spells/spell_mire_flood_rot_28.png",
	"spell_old_measure_survey_survey_02": "res://art/magic/runtime/spells/spell_old_measure_survey_survey_02.png",
	"spell_old_measure_tally_axiom_04": "res://art/magic/runtime/spells/spell_old_measure_tally_axiom_04.png",
	"spell_old_measure_index_correction_10": "res://art/magic/runtime/spells/spell_old_measure_index_correction_10.png",
	"spell_old_measure_proof_pace_12": "res://art/magic/runtime/spells/spell_old_measure_proof_pace_12.png",
	"spell_old_measure_measure_axiom_16": "res://art/magic/runtime/spells/spell_old_measure_measure_axiom_16.png",
	"spell_old_measure_survey_boundary_18": "res://art/magic/runtime/spells/spell_old_measure_survey_boundary_18.png",
	"spell_old_measure_tally_tally_20": "res://art/magic/runtime/spells/spell_old_measure_tally_tally_20.png",
	"spell_old_measure_marker_pace_24": "res://art/magic/runtime/spells/spell_old_measure_marker_pace_24.png",
	"spell_old_measure_index_survey_26": "res://art/magic/runtime/spells/spell_old_measure_index_survey_26.png",
	"spell_old_measure_proof_axiom_28": "res://art/magic/runtime/spells/spell_old_measure_proof_axiom_28.png",
	"spell_veil_salt_step_06": "res://art/magic/runtime/spells/spell_veil_salt_step_06.png",
	"spell_veil_tide_fogbind_08": "res://art/magic/runtime/spells/spell_veil_tide_fogbind_08.png",
	"spell_veil_wraith_duel_14": "res://art/magic/runtime/spells/spell_veil_wraith_duel_14.png",
	"spell_veil_lantern_mark_16": "res://art/magic/runtime/spells/spell_veil_lantern_mark_16.png",
	"spell_veil_obituary_step_18": "res://art/magic/runtime/spells/spell_veil_obituary_step_18.png",
	"spell_veil_mourning_fogbind_20": "res://art/magic/runtime/spells/spell_veil_mourning_fogbind_20.png",
	"spell_veil_salt_shroud_22": "res://art/magic/runtime/spells/spell_veil_salt_shroud_22.png",
	"spell_veil_tide_drift_24": "res://art/magic/runtime/spells/spell_veil_tide_drift_24.png",
	"spell_veil_mist_duel_26": "res://art/magic/runtime/spells/spell_veil_mist_duel_26.png",
	"spell_root_bloom_briar_04": "res://art/magic/runtime/spells/spell_root_bloom_briar_04.png",
	"spell_root_canopy_graft_06": "res://art/magic/runtime/spells/spell_root_canopy_graft_06.png",
	"spell_root_loam_thorn_10": "res://art/magic/runtime/spells/spell_root_loam_thorn_10.png",
	"spell_root_green_rootway_12": "res://art/magic/runtime/spells/spell_root_green_rootway_12.png",
	"spell_root_branch_bloom_14": "res://art/magic/runtime/spells/spell_root_branch_bloom_14.png",
	"spell_root_wild_briar_16": "res://art/magic/runtime/spells/spell_root_wild_briar_16.png",
	"spell_root_graft_graft_18": "res://art/magic/runtime/spells/spell_root_graft_graft_18.png",
	"spell_root_loam_bloom_26": "res://art/magic/runtime/spells/spell_root_loam_bloom_26.png",
	"spell_root_green_briar_28": "res://art/magic/runtime/spells/spell_root_green_briar_28.png",
}
const EXPECTED_ICONS := {
	"beacon": "res://art/magic/runtime/schools/beacon.png",
	"mire": "res://art/magic/runtime/schools/mire.png",
	"lens": "res://art/magic/runtime/schools/lens.png",
	"root": "res://art/magic/runtime/schools/root.png",
	"furnace": "res://art/magic/runtime/schools/furnace.png",
	"veil": "res://art/magic/runtime/schools/veil.png",
	"old_measure": "res://art/magic/runtime/schools/old_measure.png",
}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var original_window_size := get_window().size
	var catalog := _catalog_contract()
	if not bool(catalog.get("ok", false)):
		_fail("Spell school icon catalog failed: %s" % JSON.stringify(catalog), original_window_size)
		return
	var rows := []
	for viewport_size in VIEWPORT_SIZES:
		for surface in SURFACES:
			var row: Dictionary = await _surface_case(viewport_size, surface)
			rows.append(row)
			if not bool(row.get("ok", false)):
				_fail("Spell school icon surface failed: %s" % JSON.stringify(row), original_window_size)
				return
		var battle_reward_spell_ids: Array = TARGET_BEACON_REWARD_SPELL_IDS + TARGET_MIRE_BATTLE_REWARD_SPELL_IDS + TARGET_FURNACE_BATTLE_REWARD_SPELL_IDS + TARGET_ROOT_BATTLE_REWARD_SPELL_IDS + TARGET_VEIL_BATTLE_REWARD_SPELL_IDS + TARGET_OLD_MEASURE_BATTLE_REWARD_SPELL_IDS + TARGET_LENS_BATTLE_REWARD_SPELL_IDS
		var reward_row: Dictionary = await _surface_case(viewport_size, "battle", String(TARGET_BEACON_REWARD_SPELL_IDS[0]), battle_reward_spell_ids)
		rows.append(reward_row)
		if not bool(reward_row.get("ok", false)):
			_fail("Generated reward spell icon surface failed: %s" % JSON.stringify(reward_row), original_window_size)
			return
		var mire_overworld_row: Dictionary = await _surface_case(viewport_size, "overworld", "spell_mire_brine_fenlight_24", ["spell_mire_brine_fenlight_24"])
		rows.append(mire_overworld_row)
		if not bool(mire_overworld_row.get("ok", false)):
			_fail("Generated Mire overworld reward spell icon surface failed: %s" % JSON.stringify(mire_overworld_row), original_window_size)
			return
		var furnace_overworld_row: Dictionary = await _surface_case(viewport_size, "overworld", "spell_furnace_ash_rail_25", ["spell_furnace_ash_rail_25"])
		rows.append(furnace_overworld_row)
		if not bool(furnace_overworld_row.get("ok", false)):
			_fail("Generated Furnace overworld reward spell icon surface failed: %s" % JSON.stringify(furnace_overworld_row), original_window_size)
			return
		var root_overworld_row: Dictionary = await _surface_case(viewport_size, "overworld", "spell_root_bark_rootway_24", ["spell_root_bark_rootway_24"])
		rows.append(root_overworld_row)
		if not bool(root_overworld_row.get("ok", false)):
			_fail("Generated Root overworld reward spell icon surface failed: %s" % JSON.stringify(root_overworld_row), original_window_size)
			return
		var veil_overworld_row: Dictionary = await _surface_case(viewport_size, "overworld", "spell_veil_moon_drift_12", ["spell_veil_moon_drift_12"])
		rows.append(veil_overworld_row)
		if not bool(veil_overworld_row.get("ok", false)):
			_fail("Generated Veil overworld reward spell icon surface failed: %s" % JSON.stringify(veil_overworld_row), original_window_size)
			return
		var old_measure_overworld_row: Dictionary = await _surface_case(viewport_size, "overworld", "spell_old_measure_count_survey_14", ["spell_old_measure_count_survey_14"])
		rows.append(old_measure_overworld_row)
		if not bool(old_measure_overworld_row.get("ok", false)):
			_fail("Generated Old Measure overworld reward spell icon surface failed: %s" % JSON.stringify(old_measure_overworld_row), original_window_size)
			return
		for town_scenario_id in TARGET_LENS_TOWN_SCENARIOS:
			var lens_town_row: Dictionary = await _surface_case(viewport_size, "town", String(TARGET_LENS_TOWN_STUDY_SPELL_IDS[0]), TARGET_LENS_TOWN_STUDY_SPELL_IDS, String(town_scenario_id))
			rows.append(lens_town_row)
			if not bool(lens_town_row.get("ok", false)):
				_fail("Lens town-study spell icon surface failed: %s" % JSON.stringify(lens_town_row), original_window_size)
				return
		for town_scenario_id in TARGET_BEACON_TOWN_SCENARIOS:
			var beacon_town_row: Dictionary = await _surface_case(viewport_size, "town", String(TARGET_BEACON_TOWN_STUDY_SPELL_IDS[0]), TARGET_BEACON_TOWN_STUDY_SPELL_IDS, String(town_scenario_id))
			rows.append(beacon_town_row)
			if not bool(beacon_town_row.get("ok", false)):
				_fail("Beacon town-study spell icon surface failed: %s" % JSON.stringify(beacon_town_row), original_window_size)
				return
		for town_scenario_id in TARGET_FURNACE_TOWN_SCENARIOS:
			var furnace_town_row: Dictionary = await _surface_case(viewport_size, "town", String(TARGET_FURNACE_TOWN_STUDY_SPELL_IDS[0]), TARGET_FURNACE_TOWN_STUDY_SPELL_IDS, String(town_scenario_id))
			rows.append(furnace_town_row)
			if not bool(furnace_town_row.get("ok", false)):
				_fail("Furnace town-study spell icon surface failed: %s" % JSON.stringify(furnace_town_row), original_window_size)
				return
		for town_scenario_id in TARGET_MIRE_TOWN_SCENARIOS:
			var mire_town_row: Dictionary = await _surface_case(viewport_size, "town", String(TARGET_MIRE_TOWN_STUDY_SPELL_IDS[0]), TARGET_MIRE_TOWN_STUDY_SPELL_IDS, String(town_scenario_id))
			rows.append(mire_town_row)
			if not bool(mire_town_row.get("ok", false)):
				_fail("Mire town-study spell icon surface failed: %s" % JSON.stringify(mire_town_row), original_window_size)
				return
		for town_scenario_id in TARGET_OLD_MEASURE_TOWN_SCENARIOS:
			var old_measure_town_row: Dictionary = await _surface_case(viewport_size, "town", String(TARGET_OLD_MEASURE_TOWN_STUDY_SPELL_IDS[0]), TARGET_OLD_MEASURE_TOWN_STUDY_SPELL_IDS, String(town_scenario_id))
			rows.append(old_measure_town_row)
			if not bool(old_measure_town_row.get("ok", false)):
				_fail("Old Measure town-study spell icon surface failed: %s" % JSON.stringify(old_measure_town_row), original_window_size)
				return
		for town_scenario_id in TARGET_VEIL_TOWN_SCENARIOS:
			var veil_town_row: Dictionary = await _surface_case(viewport_size, "town", String(TARGET_VEIL_TOWN_STUDY_SPELL_IDS[0]), TARGET_VEIL_TOWN_STUDY_SPELL_IDS, String(town_scenario_id))
			rows.append(veil_town_row)
			if not bool(veil_town_row.get("ok", false)):
				_fail("Veil town-study spell icon surface failed: %s" % JSON.stringify(veil_town_row), original_window_size)
				return
		for town_scenario_id in TARGET_ROOT_TOWN_SCENARIOS:
			var root_town_row: Dictionary = await _surface_case(viewport_size, "town", String(TARGET_ROOT_TOWN_STUDY_SPELL_IDS[0]), TARGET_ROOT_TOWN_STUDY_SPELL_IDS, String(town_scenario_id))
			rows.append(root_town_row)
			if not bool(root_town_row.get("ok", false)):
				_fail("Root town-study spell icon surface failed: %s" % JSON.stringify(root_town_row), original_window_size)
				return
	SessionState.reset_session()
	get_window().size = original_window_size
	await get_tree().process_frame
	await get_tree().process_frame
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": true, "catalog": catalog, "rows": rows})])
	get_tree().quit(0)

func _catalog_contract() -> Dictionary:
	var signature_raw := ContentService.load_json(ContentService.SPELL_ICONS_PATH)
	var signature_rows: Array = signature_raw.get("items", []) if signature_raw.get("items", []) is Array else []
	var signature_contract := []
	var signature_ids := []
	for row_value in signature_rows:
		if not (row_value is Dictionary):
			continue
		var row: Dictionary = row_value
		var spell_id := String(row.get("spell_id", ""))
		var icon_path := String(row.get("icon_path", ""))
		var texture := load(icon_path) as Texture2D if ResourceLoader.exists(icon_path, "Texture2D") else null
		signature_ids.append(spell_id)
		signature_contract.append({
			"spell_id": spell_id,
			"school_id": String(row.get("school_id", "")),
			"icon_id": String(row.get("icon_id", "")),
			"icon_path": icon_path,
			"source_kind": String(row.get("source_kind", "")),
			"size": texture.get_size() if texture != null else Vector2.ZERO,
		})
	var raw_manifest := ContentService.load_json(ContentService.SPELL_SCHOOL_ICONS_PATH)
	var manifest_rows: Array = raw_manifest.get("items", []) if raw_manifest.get("items", []) is Array else []
	var manifest_contract := []
	var manifest_ids := []
	var manifest_paths := []
	for row_value in manifest_rows:
		if not (row_value is Dictionary):
			continue
		var row: Dictionary = row_value
		var school_id := String(row.get("id", ""))
		var icon_path := String(row.get("icon_path", ""))
		var texture := load(icon_path) as Texture2D if ResourceLoader.exists(icon_path, "Texture2D") else null
		manifest_contract.append({
			"school_id": school_id,
			"icon_id": String(row.get("icon_id", "")),
			"icon_path": icon_path,
			"material_language": String(row.get("material_language", "")),
			"size": texture.get_size() if texture != null else Vector2.ZERO,
		})
		manifest_ids.append(school_id)
		manifest_paths.append(icon_path)
	var spells_raw := ContentService.load_json(ContentService.SPELLS_PATH)
	var spells: Array = spells_raw.get("items", []) if spells_raw.get("items", []) is Array else []
	var spell_rows := []
	for spell_value in spells:
		if not (spell_value is Dictionary):
			continue
		var spell: Dictionary = spell_value
		var spell_id := String(spell.get("id", ""))
		var school_id := String(spell.get("school_id", ""))
		var expected_path := String(EXPECTED_SIGNATURE_ICONS.get(spell_id, EXPECTED_ICONS.get(school_id, "")))
		spell_rows.append({
			"spell_id": spell_id,
			"school_id": school_id,
			"resolved_path": SpellRules.spell_icon_path(spell_id),
			"expected_path": expected_path,
			"uses_signature": EXPECTED_SIGNATURE_ICONS.has(spell_id),
		})
	var sorted_ids := manifest_ids.duplicate()
	sorted_ids.sort()
	var sorted_expected_ids: Array = EXPECTED_ICONS.keys()
	sorted_expected_ids.sort()
	var sorted_signature_ids := signature_ids.duplicate()
	sorted_signature_ids.sort()
	var sorted_expected_signature_ids: Array = EXPECTED_SIGNATURE_ICONS.keys()
	sorted_expected_signature_ids.sort()
	var fallback_contract := _signature_fallback_contract()
	var generated_reward_contract := _generated_reward_contract()
	return {
		"ok": (
			bool(fallback_contract.get("ok", false))
			and bool(generated_reward_contract.get("ok", false))
			and signature_contract.size() == 112
			and sorted_signature_ids == sorted_expected_signature_ids
			and signature_contract.all(func(row): return String(row.get("icon_id", "")) == "spell_signature_icon_%s" % String(row.get("spell_id", "")).trim_prefix("spell_") and String(row.get("icon_path", "")) == String(EXPECTED_SIGNATURE_ICONS.get(String(row.get("spell_id", "")), "")) and String(row.get("source_kind", "")) == "curated_original_spell" and row.get("size", Vector2.ZERO) == Vector2(128.0, 128.0))
			and manifest_contract.size() == 7
			and sorted_ids == sorted_expected_ids
			and _all_unique(manifest_paths)
			and manifest_contract.all(func(row): return String(row.get("icon_id", "")) == "spell_school_sigil_%s" % String(row.get("school_id", "")) and String(row.get("icon_path", "")) == String(EXPECTED_ICONS.get(String(row.get("school_id", "")), "")) and String(row.get("material_language", "")) != "" and row.get("size", Vector2.ZERO) == Vector2(128.0, 128.0))
			and spell_rows.size() == 112
			and spell_rows.all(func(row): return String(row.get("resolved_path", "")) == String(row.get("expected_path", "")) and String(row.get("resolved_path", "")) != "")
			and spell_rows.filter(func(row): return bool(row.get("uses_signature", false))).size() == 112
			and spell_rows.filter(func(row): return not bool(row.get("uses_signature", false))).size() == 0
			and SpellRules.spell_id_for_action("cast_spell:spell_missing") == ""
			and SpellRules.spell_id_for_action("learn_spell:spell_missing") == ""
			and SpellRules.spell_school_icon_path("spell_missing") == ""
			and SpellRules.spell_icon_path("spell_missing") == ""
		),
		"fallback": fallback_contract,
		"generated_reward": generated_reward_contract,
		"signature_count": signature_contract.size(),
		"school_fallback_count": 0,
		"signatures": signature_contract,
		"school_count": manifest_contract.size(),
		"spell_count": spell_rows.size(),
		"distinct_icon_path_count": manifest_paths.size() if _all_unique(manifest_paths) else 0,
		"manifest": manifest_contract,
		"spells": spell_rows,
	}

func _generated_reward_contract() -> Dictionary:
	var model := ContentService.load_json(GENERATED_MAP_MODEL_PATH)
	var definitions: Array = model.get("object_definitions", []) if model.get("object_definitions", []) is Array else []
	var reward_ids := []
	for definition_value in definitions:
		if not (definition_value is Dictionary):
			continue
		var definition: Dictionary = definition_value
		if String(definition.get("id", "")) != "rmg_object_reward_reference_v1":
			continue
		for object_id_value in definition.get("supported_runtime_object_ids", []):
			var object_id := String(object_id_value)
			if not ContentService.get_spell(object_id).is_empty():
				reward_ids.append(object_id)
		break
	var rows := []
	for spell_id in reward_ids:
		var icon_path := SpellRules.spell_icon_path(spell_id)
		rows.append({
			"spell_id": spell_id,
			"icon_path": icon_path,
			"specific": icon_path.begins_with("res://art/magic/runtime/spells/"),
		})
	var specific_count := rows.filter(func(row): return bool(row.get("specific", false))).size()
	return {
		"ok": (
			reward_ids.size() == 38
			and _all_unique(reward_ids)
			and TARGET_BEACON_REWARD_SPELL_IDS.all(func(spell_id): return spell_id in reward_ids and SpellRules.spell_icon_path(spell_id) == String(EXPECTED_SIGNATURE_ICONS.get(spell_id, "")))
			and TARGET_MIRE_REWARD_SPELL_IDS.all(func(spell_id): return spell_id in reward_ids and SpellRules.spell_icon_path(spell_id) == String(EXPECTED_SIGNATURE_ICONS.get(spell_id, "")))
			and TARGET_FURNACE_REWARD_SPELL_IDS.all(func(spell_id): return spell_id in reward_ids and SpellRules.spell_icon_path(spell_id) == String(EXPECTED_SIGNATURE_ICONS.get(spell_id, "")))
			and TARGET_ROOT_REWARD_SPELL_IDS.all(func(spell_id): return spell_id in reward_ids and SpellRules.spell_icon_path(spell_id) == String(EXPECTED_SIGNATURE_ICONS.get(spell_id, "")))
			and TARGET_VEIL_REWARD_SPELL_IDS.all(func(spell_id): return spell_id in reward_ids and SpellRules.spell_icon_path(spell_id) == String(EXPECTED_SIGNATURE_ICONS.get(spell_id, "")))
			and TARGET_OLD_MEASURE_REWARD_SPELL_IDS.all(func(spell_id): return spell_id in reward_ids and SpellRules.spell_icon_path(spell_id) == String(EXPECTED_SIGNATURE_ICONS.get(spell_id, "")))
			and TARGET_LENS_REWARD_SPELL_IDS.all(func(spell_id): return spell_id in reward_ids and SpellRules.spell_icon_path(spell_id) == String(EXPECTED_SIGNATURE_ICONS.get(spell_id, "")))
			and specific_count == 38
			and rows.size() - specific_count == 0
		),
		"reward_spell_ids": reward_ids,
		"specific_count": specific_count,
		"school_fallback_count": rows.size() - specific_count,
		"rows": rows,
	}

func _signature_fallback_contract() -> Dictionary:
	var spell_id := "spell_bulwark_litany"
	var original_manifest: Dictionary = ContentService.load_json(ContentService.SPELL_ICONS_PATH).duplicate(true)
	var expected_school_path := SpellRules.spell_school_icon_path(spell_id)
	var malformed_manifest: Dictionary = original_manifest.duplicate(true)
	var malformed_rows: Array = malformed_manifest.get("items", []) if malformed_manifest.get("items", []) is Array else []
	for row_value in malformed_rows:
		if row_value is Dictionary and String(row_value.get("spell_id", "")) == spell_id:
			row_value["school_id"] = "mire"
			row_value["icon_path"] = "res://art/magic/runtime/spells/missing.png"
			break
	ContentService._cache[ContentService.SPELL_ICONS_PATH] = malformed_manifest
	var malformed_fallback := SpellRules.spell_icon_path(spell_id)
	ContentService._cache[ContentService.SPELL_ICONS_PATH] = {"items": []}
	var missing_fallback := SpellRules.spell_icon_path(spell_id)
	ContentService._cache[ContentService.SPELL_ICONS_PATH] = original_manifest
	var restored_path := SpellRules.spell_icon_path(spell_id)
	return {
		"ok": (
			expected_school_path != ""
			and malformed_fallback == expected_school_path
			and missing_fallback == expected_school_path
			and restored_path == String(EXPECTED_SIGNATURE_ICONS.get(spell_id, ""))
			and ContentService.load_json(ContentService.SPELL_ICONS_PATH) == original_manifest
		),
		"spell_id": spell_id,
		"malformed_fallback": malformed_fallback,
		"missing_fallback": missing_fallback,
		"restored_path": restored_path,
	}

func _surface_case(viewport_size: Vector2i, surface: String, spell_id_override: String = "", spell_ids_override: Array = [], town_scenario_id: String = "") -> Dictionary:
	get_window().size = viewport_size
	await get_tree().process_frame
	await get_tree().process_frame
	if get_window().size != viewport_size:
		return {"ok": false, "failure": "window_size", "surface": surface, "actual": get_window().size}
	var fixture := _surface_fixture(surface, spell_id_override, spell_ids_override, town_scenario_id)
	var session = fixture.get("session")
	var spell_id := String(fixture.get("spell_id", ""))
	if session == null or spell_id == "":
		return {"ok": false, "failure": "fixture", "surface": surface, "fixture": fixture}
	SessionState.set_active_session(session)
	var scene_path := _surface_scene_path(surface)
	var shell = load(scene_path).instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	if surface == "overworld":
		shell.validation_open_command_drawer()
	elif surface == "town":
		var management_tabs := shell.get_node_or_null("%ManagementTabs") as TabContainer
		if management_tabs == null:
			return await _finish_case(shell, {"ok": false, "failure": "management_tabs", "surface": surface})
		management_tabs.current_tab = 2
	await get_tree().process_frame
	await get_tree().process_frame
	var live_session = shell.get("_session")
	if live_session == null:
		live_session = SessionState.ensure_active_session()
	var container := shell.get_node_or_null(_surface_container_path(surface)) as Container
	if container == null:
		return await _finish_case(shell, {"ok": false, "failure": "container", "surface": surface})
	var actions := _surface_actions(surface, live_session)
	var buttons := _button_contract(shell, container, actions, surface, not (surface == "town" and not spell_ids_override.is_empty()))
	var action_id := _surface_action_id(surface, spell_id)
	var action := _action_for_id(actions, action_id)
	var button := _button_for_action(shell, container, actions, surface, action_id)
	if action.is_empty() or button == null or button.disabled:
		return await _finish_case(shell, {"ok": false, "failure": "action_button", "surface": surface, "action_id": action_id, "actions": actions, "buttons": buttons})
	var expected_icon_path := SpellRules.spell_icon_path(spell_id)
	var selected_icon_exact := _icon_exact(button, expected_icon_path)
	var selected_specific := expected_icon_path.begins_with("res://art/magic/runtime/spells/")
	var targeted_buttons_exact := true
	for targeted_spell_id in spell_ids_override:
		var targeted_action_id := _surface_action_id(surface, String(targeted_spell_id))
		var targeted_button := _button_for_action(shell, container, actions, surface, targeted_action_id)
		if surface == "town" and targeted_button != null:
			targeted_button.grab_focus()
			await get_tree().process_frame
		targeted_buttons_exact = (
			targeted_buttons_exact
			and targeted_button != null
			and _icon_exact(targeted_button, SpellRules.spell_icon_path(String(targeted_spell_id)))
			and (surface != "town" or (get_viewport().gui_get_focus_owner() == targeted_button and get_viewport().get_visible_rect().encloses(targeted_button.get_global_rect())))
		)
	button.grab_focus()
	await get_tree().process_frame
	var focus_exact := get_viewport().gui_get_focus_owner() == button and get_viewport().get_visible_rect().encloses(button.get_global_rect())
	var invalid_button := Button.new()
	invalid_button.text = "Invalid spell control"
	shell.call("_apply_spell_action_icon", invalid_button, {"id": _surface_action_id(surface, "spell_missing")})
	var invalid_fail_closed := invalid_button.icon == null and invalid_button.text == "Invalid spell control"
	invalid_button.free()
	var live_before: Dictionary = live_session.to_dict()
	var control = SessionDataScript.SessionData.new()
	control.from_dict(live_before.duplicate(true))
	var control_result := _apply_control_action(control, surface, action, spell_id)
	var save_before := SaveService.latest_loadable_summary()
	button.emit_signal("pressed")
	await get_tree().process_frame
	await get_tree().process_frame
	var save_after := SaveService.latest_loadable_summary()
	var live_after: Dictionary = live_session.to_dict()
	var row := {
		"ok": (
			bool(buttons.get("ok", false))
			and focus_exact
			and selected_icon_exact
			and selected_specific
			and targeted_buttons_exact
			and bool(fixture.get("town_study_contract_exact", true))
			and invalid_fail_closed
			and bool(control_result.get("ok", false))
			and live_after == control.to_dict()
			and save_after == save_before
		),
		"viewport_size": viewport_size,
		"surface": surface,
		"spell_id": spell_id,
		"school_id": String(ContentService.get_spell(spell_id).get("school_id", "")),
		"action_id": action_id,
		"buttons": buttons,
		"focus_exact": focus_exact,
		"selected_icon_exact": selected_icon_exact,
		"selected_specific": selected_specific,
		"targeted_spell_ids": spell_ids_override.duplicate(),
		"targeted_buttons_exact": targeted_buttons_exact,
		"town_scenario_id": String(fixture.get("town_scenario_id", "")),
		"town_id": String(fixture.get("town_id", "")),
		"town_spell_tier": int(fixture.get("town_spell_tier", 0)),
		"town_study_contract_exact": bool(fixture.get("town_study_contract_exact", true)),
		"invalid_fail_closed": invalid_fail_closed,
		"control_ok": bool(control_result.get("ok", false)),
		"session_exact": live_after == control.to_dict(),
		"save_authority_exact": save_after == save_before,
	}
	if not bool(row.get("ok", false)):
		row["control_result"] = control_result
		row["session_differences"] = _recursive_exact_differences(control.to_dict(), live_after)
	return await _finish_case(shell, row)

func _surface_fixture(surface: String, spell_id_override: String = "", spell_ids_override: Array = [], town_scenario_id: String = "") -> Dictionary:
	if surface == "town":
		var town_session = _base_session(town_scenario_id if town_scenario_id != "" else "river-pass")
		var town := _first_player_town(town_session)
		if town.is_empty():
			return {}
		var built_buildings: Array = town.get("built_buildings", []) if town.get("built_buildings", []) is Array else []
		var target_study_spell_ids: Array = TARGET_LENS_TOWN_STUDY_SPELL_IDS
		var target_town_scenarios: Dictionary = TARGET_LENS_TOWN_SCENARIOS
		var required_study_buildings: Array = TARGET_LENS_TOWN_STUDY_BUILDING_IDS
		if TARGET_BEACON_TOWN_SCENARIOS.has(town_scenario_id):
			target_study_spell_ids = TARGET_BEACON_TOWN_STUDY_SPELL_IDS
			target_town_scenarios = TARGET_BEACON_TOWN_SCENARIOS
			required_study_buildings = TARGET_BEACON_TOWN_STUDY_BUILDING_IDS
		elif TARGET_FURNACE_TOWN_SCENARIOS.has(town_scenario_id):
			target_study_spell_ids = TARGET_FURNACE_TOWN_STUDY_SPELL_IDS
			target_town_scenarios = TARGET_FURNACE_TOWN_SCENARIOS
			required_study_buildings = TARGET_FURNACE_TOWN_STUDY_BUILDING_IDS
		elif TARGET_MIRE_TOWN_SCENARIOS.has(town_scenario_id):
			target_study_spell_ids = TARGET_MIRE_TOWN_STUDY_SPELL_IDS
			target_town_scenarios = TARGET_MIRE_TOWN_SCENARIOS
			required_study_buildings = TARGET_MIRE_TOWN_STUDY_BUILDING_IDS
		elif TARGET_OLD_MEASURE_TOWN_SCENARIOS.has(town_scenario_id) and spell_id_override in TARGET_OLD_MEASURE_TOWN_STUDY_SPELL_IDS:
			target_study_spell_ids = TARGET_OLD_MEASURE_TOWN_STUDY_SPELL_IDS
			target_town_scenarios = TARGET_OLD_MEASURE_TOWN_SCENARIOS
			required_study_buildings = TARGET_OLD_MEASURE_TOWN_STUDY_BUILDING_IDS.get(town_scenario_id, [])
		elif TARGET_VEIL_TOWN_SCENARIOS.has(town_scenario_id) and spell_id_override in TARGET_VEIL_TOWN_STUDY_SPELL_IDS:
			target_study_spell_ids = TARGET_VEIL_TOWN_STUDY_SPELL_IDS
			target_town_scenarios = TARGET_VEIL_TOWN_SCENARIOS
			required_study_buildings = TARGET_VEIL_TOWN_STUDY_BUILDING_IDS
		elif TARGET_ROOT_TOWN_SCENARIOS.has(town_scenario_id) and spell_id_override in TARGET_ROOT_TOWN_STUDY_SPELL_IDS:
			target_study_spell_ids = TARGET_ROOT_TOWN_STUDY_SPELL_IDS
			target_town_scenarios = TARGET_ROOT_TOWN_SCENARIOS
			required_study_buildings = TARGET_ROOT_TOWN_STUDY_BUILDING_IDS
		if town_scenario_id == "":
			required_study_buildings = ["building_lantern_archive"]
		for building_id in required_study_buildings:
			if building_id not in built_buildings:
				built_buildings.append(building_id)
		town["built_buildings"] = built_buildings
		_move_active_hero_to_town(town_session, town)
		_set_active_hero_spellbook(town_session, [])
		var learning_actions := TownRules.get_spell_learning_actions(town_session)
		var learning_spell_ids := []
		for action_value in learning_actions:
			if action_value is Dictionary:
				var spell_id := SpellRules.spell_id_for_action(String(action_value.get("id", "")))
				if spell_id != "" and spell_id not in learning_spell_ids:
					learning_spell_ids.append(spell_id)
		if town_scenario_id != "":
			var targeted_learning_ids := learning_spell_ids.filter(func(spell_id): return spell_id in spell_ids_override)
			var expected_town_id := String(target_town_scenarios.get(town_scenario_id, ""))
			var town_study_contract_exact := (
				String(town.get("town_id", "")) == expected_town_id
				and TownRules.current_spell_tier(town) == 5
				and targeted_learning_ids == spell_ids_override
				and target_study_spell_ids.all(func(spell_id): return spell_id in TownRules.accessible_spell_ids(town))
			)
			if spell_id_override in learning_spell_ids:
				return {
					"session": town_session,
					"spell_id": spell_id_override,
					"town_scenario_id": town_scenario_id,
					"town_id": String(town.get("town_id", "")),
					"town_spell_tier": TownRules.current_spell_tier(town),
					"town_study_contract_exact": town_study_contract_exact,
				}
			return {}
		if not learning_spell_ids.is_empty():
			return {"session": town_session, "spell_id": String(learning_spell_ids[0])}
		return {}
	if surface == "battle":
		var battle_session = _base_session()
		var battle_spell_id := spell_id_override if spell_id_override != "" else String(SURFACE_SPELL_IDS.get("battle", ""))
		var battle_spell_ids := spell_ids_override.duplicate() if not spell_ids_override.is_empty() else [battle_spell_id]
		_set_active_hero_spellbook(battle_session, battle_spell_ids)
		var enemy_town := _first_enemy_town(battle_session)
		if enemy_town.is_empty():
			return {}
		battle_session.battle = BattleRules.create_town_assault_payload(battle_session, String(enemy_town.get("placement_id", "")))
		_stage_player_turn(battle_session.battle)
		return {"session": battle_session, "spell_id": battle_spell_id}
	var overworld_session = _base_session()
	var overworld_spell_id := spell_id_override if spell_id_override != "" else String(SURFACE_SPELL_IDS.get("overworld", ""))
	var overworld_spell_ids := spell_ids_override.duplicate() if not spell_ids_override.is_empty() else [overworld_spell_id]
	_set_active_hero_spellbook(overworld_session, overworld_spell_ids)
	var overworld_hero: Dictionary = overworld_session.overworld.get("hero", {}) if overworld_session.overworld.get("hero", {}) is Dictionary else {}
	overworld_hero["movement"] = {"current": 2, "max": 12}
	overworld_session.overworld["hero"] = overworld_hero
	overworld_session.overworld["movement"] = {"current": 2, "max": 12}
	var active_hero_id := String(overworld_session.overworld.get("active_hero_id", overworld_hero.get("id", "")))
	var overworld_heroes: Array = overworld_session.overworld.get("player_heroes", []) if overworld_session.overworld.get("player_heroes", []) is Array else []
	for index in range(overworld_heroes.size()):
		if overworld_heroes[index] is Dictionary and String(overworld_heroes[index].get("id", "")) == active_hero_id:
			overworld_heroes[index] = overworld_hero.duplicate(true)
			break
	overworld_session.overworld["player_heroes"] = overworld_heroes
	return {"session": overworld_session, "spell_id": overworld_spell_id}

func _base_session(scenario_id: String = "river-pass"):
	var session = ScenarioFactory.create_session(scenario_id, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	return session

func _set_active_hero_spellbook(session, spell_ids: Array) -> void:
	var hero: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	hero = SpellRules.ensure_hero_spellbook(hero)
	var spellbook: Dictionary = hero.get("spellbook", {}) if hero.get("spellbook", {}) is Dictionary else {}
	spellbook["known_spell_ids"] = spell_ids.duplicate()
	spellbook["mana"] = {"current": 40, "max": 40}
	hero["spellbook"] = spellbook
	session.overworld["hero"] = hero
	var active_hero_id := String(session.overworld.get("active_hero_id", hero.get("id", "")))
	var heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == active_hero_id:
			heroes[index] = hero.duplicate(true)
			break
	session.overworld["player_heroes"] = heroes

func _stage_player_turn(battle: Dictionary) -> void:
	var player_id := ""
	var enemy_id := ""
	for stack_value in battle.get("stacks", []):
		if not (stack_value is Dictionary):
			continue
		var stack: Dictionary = stack_value
		if player_id == "" and String(stack.get("side", "")) == "player":
			player_id = String(stack.get("battle_id", ""))
		elif enemy_id == "" and String(stack.get("side", "")) == "enemy":
			enemy_id = String(stack.get("battle_id", ""))
			stack["base_count"] = max(200, int(stack.get("base_count", 0)))
			stack["total_health"] = int(stack.get("base_count", 200)) * max(1, int(stack.get("unit_hp", 1)))
	battle["active_stack_id"] = player_id
	battle["selected_target_id"] = enemy_id
	battle["commander_spell_cast_rounds"] = {}

func _surface_scene_path(surface: String) -> String:
	match surface:
		"town":
			return "res://scenes/town/TownShell.tscn"
		"battle":
			return "res://scenes/battle/BattleShell.tscn"
		_:
			return "res://scenes/overworld/OverworldShell.tscn"

func _surface_container_path(surface: String) -> String:
	return "%StudyActions" if surface == "town" else "%SpellActions"

func _surface_actions(surface: String, session) -> Array:
	match surface:
		"town":
			return TownRules.get_spell_learning_actions(session)
		"battle":
			return BattleRules.get_spell_actions(session)
		_:
			return OverworldRules.get_spell_actions(session)

func _surface_action_id(surface: String, spell_id: String) -> String:
	return "%s:%s" % ["learn_spell" if surface == "town" else "cast_spell", spell_id]

func _action_for_id(actions: Array, action_id: String) -> Dictionary:
	for action_value in actions:
		if action_value is Dictionary and String(action_value.get("id", "")) == action_id:
			return action_value.duplicate(true)
	return {}

func _button_contract(shell: Node, container: Container, actions: Array, surface: String, require_all_contained: bool = true) -> Dictionary:
	var button_rows := []
	var buttons := []
	for child in container.get_children():
		if child is Button:
			buttons.append(child)
	for index in range(actions.size()):
		var action: Dictionary = actions[index] if actions[index] is Dictionary else {}
		var button: Button = buttons[index] if index < buttons.size() else null
		var spell_id := SpellRules.spell_id_for_action(String(action.get("id", "")))
		var expected_path := SpellRules.spell_icon_path(spell_id)
		var expected_text := _expected_button_text(shell, surface, action)
		var expected_tooltip := _expected_button_tooltip(shell, surface, action)
		var rect := button.get_global_rect() if button != null else Rect2()
		button_rows.append({
			"action_id": String(action.get("id", "")),
			"spell_id": spell_id,
			"expected_path": expected_path,
			"present": button != null,
			"copy_exact": button != null and button.text == expected_text and button.tooltip_text == expected_tooltip,
			"disabled_exact": button != null and button.disabled == bool(action.get("disabled", false)),
			"icon_exact": button != null and _icon_exact(button, expected_path),
			"focusable": button != null and button.focus_mode != Control.FOCUS_NONE,
			"visible": button != null and button.is_visible_in_tree(),
			"contained": button != null and get_viewport().get_visible_rect().encloses(rect),
			"rect": rect,
		})
	return {
		"ok": button_rows.size() == actions.size() and buttons.size() == actions.size() and button_rows.all(func(row): return bool(row.get("present", false)) and bool(row.get("copy_exact", false)) and bool(row.get("disabled_exact", false)) and bool(row.get("icon_exact", false)) and bool(row.get("focusable", false)) and bool(row.get("visible", false)) and (not require_all_contained or bool(row.get("contained", false)))),
		"action_count": actions.size(),
		"button_count": buttons.size(),
		"require_all_contained": require_all_contained,
		"rows": button_rows,
	}

func _button_for_action(shell: Node, container: Container, actions: Array, surface: String, action_id: String) -> Button:
	var expected_action_index := -1
	for index in range(actions.size()):
		if actions[index] is Dictionary and String(actions[index].get("id", "")) == action_id:
			expected_action_index = index
			break
	if expected_action_index < 0:
		return null
	var buttons := []
	for child in container.get_children():
		if child is Button:
			buttons.append(child)
	return buttons[expected_action_index] if expected_action_index < buttons.size() else null

func _expected_button_text(shell: Node, surface: String, action: Dictionary) -> String:
	if surface == "battle":
		return String(shell.call("_battle_spell_action_button_text", action))
	return String(action.get("label", action.get("id", "Action")))

func _expected_button_tooltip(shell: Node, surface: String, action: Dictionary) -> String:
	if surface == "battle":
		return String(shell.call("_battle_spell_action_tooltip", action))
	if surface == "town":
		return String(shell.call("_town_action_button_tooltip", action, "study"))
	var spell_check: Dictionary = shell.call("_spell_action_check_surface", action)
	return String(shell.call("_join_tooltip_sections", [String(action.get("summary", "")), String(spell_check.get("tooltip_text", ""))]))

func _apply_control_action(control, surface: String, action: Dictionary, spell_id: String) -> Dictionary:
	var action_id := String(action.get("id", ""))
	if surface == "overworld":
		var result := OverworldRules.cast_overworld_spell(control, spell_id)
		var recap: Dictionary = result.get("post_action_recap", {}) if result.get("post_action_recap", {}) is Dictionary else {}
		if not recap.is_empty():
			control.flags["last_overworld_action_recap"] = recap.duplicate(true)
		return result
	if surface == "town":
		var before := TownRules.town_action_consequence_signature(control)
		var result := TownRules.learn_spell_at_active_town(control, spell_id)
		var recap := TownRules.build_town_action_recap(control, "order", action_id, action, result, before)
		if bool(recap.get("active", false)):
			control.flags["last_town_action_recap"] = recap.duplicate(true)
		return result
	var context := BattleRules.post_action_recap_context(control, action_id)
	var result := BattleRules.cast_player_spell(control, spell_id)
	var recap := BattleRules.post_action_recap_payload(control, result, action_id, context)
	if not recap.is_empty():
		control.flags["last_battle_action_recap"] = recap.duplicate(true)
	return result

func _icon_exact(button: Button, expected_path: String) -> bool:
	return expected_path != "" and button.icon != null and button.icon.resource_path == expected_path and button.expand_icon and button.get_theme_constant("icon_max_width") == 24

func _first_player_town(session) -> Dictionary:
	for town_value in session.overworld.get("towns", []):
		if town_value is Dictionary and String(town_value.get("owner", "")) == "player":
			return town_value
	return {}

func _first_enemy_town(session) -> Dictionary:
	for town_value in session.overworld.get("towns", []):
		if town_value is Dictionary and String(town_value.get("owner", "")) == "enemy":
			return town_value
	return {}

func _move_active_hero_to_town(session, town: Dictionary) -> void:
	var position := {"x": int(town.get("x", 0)), "y": int(town.get("y", 0))}
	session.overworld["hero_position"] = position.duplicate(true)
	var hero: Dictionary = session.overworld.get("hero", {})
	hero["position"] = position.duplicate(true)
	session.overworld["hero"] = hero
	var heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == String(session.overworld.get("active_hero_id", "")):
			heroes[index]["position"] = position.duplicate(true)
	session.overworld["player_heroes"] = heroes

func _all_unique(values: Array) -> bool:
	for index in range(values.size()):
		if values.find(values[index]) != index:
			return false
	return true

func _finish_case(shell: Node, result: Dictionary) -> Dictionary:
	if shell != null and is_instance_valid(shell):
		shell.queue_free()
		await get_tree().process_frame
	return result

func _recursive_exact_differences(expected: Variant, actual: Variant, path: String = "$") -> Array:
	var differences := []
	if typeof(expected) != typeof(actual):
		return [{"path": path, "expected_type": typeof(expected), "actual_type": typeof(actual)}]
	if expected is Dictionary:
		var keys: Array = expected.keys()
		for key in actual.keys():
			if key not in keys:
				keys.append(key)
		keys.sort_custom(func(left, right): return String(left) < String(right))
		for key in keys:
			if not expected.has(key) or not actual.has(key):
				differences.append({"path": "%s[%s]" % [path, JSON.stringify(key)], "expected_present": expected.has(key), "actual_present": actual.has(key)})
			else:
				differences.append_array(_recursive_exact_differences(expected.get(key), actual.get(key), "%s[%s]" % [path, JSON.stringify(key)]))
		return differences
	if expected is Array:
		if expected.size() != actual.size():
			differences.append({"path": path, "expected_size": expected.size(), "actual_size": actual.size()})
		for index in range(min(expected.size(), actual.size())):
			differences.append_array(_recursive_exact_differences(expected[index], actual[index], "%s[%d]" % [path, index]))
		return differences
	if expected != actual:
		differences.append({"path": path, "expected": expected, "actual": actual})
	return differences

func _fail(message: String, original_window_size: Vector2i) -> void:
	get_window().size = original_window_size
	push_error(message)
	get_tree().quit(1)
