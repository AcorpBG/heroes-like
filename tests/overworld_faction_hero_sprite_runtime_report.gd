extends Node

const SCENARIO_ID := "river-pass"
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const SILHOUETTE_MODEL := "eight_direction_alpha_silhouette_outline"
const COMMAND_PENNANT_MODEL := "compact_player_command_flag"
const EXPECTED_HERO_ASSETS := {
	"hero_lyra": "hero_signature_lyra",
	"hero_vaska": "hero_signature_vaska",
	"hero_solera": "hero_signature_solera",
	"hero_thornwake_silsa_bramblehound": "hero_signature_thornwake_silsa_bramblehound",
	"hero_brasshollow_marka_ironclause": "hero_signature_brasshollow_marka_ironclause",
	"hero_veilmourn_ivara_blacktide": "hero_signature_veilmourn_ivara_blacktide",
	"hero_caelen": "hero_lead_caelen",
	"hero_mira": "hero_lead_mira",
	"hero_thornwake_tova_rootwright": "hero_lead_thornwake_tova_rootwright",
	"hero_veilmourn_ruln_vanehook": "hero_lead_veilmourn_ruln_vanehook",
	"hero_brasshollow_oren_bellfounder": "hero_lead_brasshollow_oren_bellfounder",
	"hero_mireclaw_kessa_chainboom": "hero_lead_mireclaw_kessa_chainboom",
	"hero_neral": "hero_lead_neral",
	"hero_seren": "hero_lead_seren",
	"hero_embercourt_belis_rainledger": "hero_tavern_embercourt_belis_rainledger",
	"hero_sable": "hero_tavern_sable",
	"hero_sunvault_calis_sunvein": "hero_tavern_sunvault_calis_sunvein",
	"hero_thornwake_ardren_briarmarshal": "hero_tavern_thornwake_ardren_briarmarshal",
	"hero_brasshollow_daxis_chaincaptain": "hero_tavern_brasshollow_daxis_chaincaptain",
	"hero_veilmourn_cela_mistcorsair": "hero_tavern_veilmourn_cela_mistcorsair",
	"hero_torren": "hero_specialist_torren",
	"hero_mireclaw_brakka_mudkeel": "hero_specialist_mireclaw_brakka_mudkeel",
	"hero_varis": "hero_specialist_varis",
	"hero_thornwake_veyra_seedseer": "hero_specialist_thornwake_veyra_seedseer",
	"hero_brasshollow_selka_pitmarshal": "hero_specialist_brasshollow_selka_pitmarshal",
	"hero_veilmourn_morwen_wakeoracle": "hero_specialist_veilmourn_morwen_wakeoracle",
	"hero_embercourt_helva_tollbrand": "hero_field_embercourt_helva_tollbrand",
	"hero_tarn": "hero_field_tarn",
	"hero_sunvault_ilyr_glassmarshal": "hero_field_sunvault_ilyr_glassmarshal",
	"hero_thornwake_halen_thorncart": "hero_field_thornwake_halen_thorncart",
	"hero_brasshollow_kuld_varn": "hero_field_brasshollow_kuld_varn",
	"hero_veilmourn_jessa_keelwarden": "hero_field_veilmourn_jessa_keelwarden",
	"hero_embercourt_saren_lockmaster": "hero_strategic_embercourt_saren_lockmaster",
	"hero_orrik": "hero_strategic_orrik",
	"hero_thalen": "hero_strategic_thalen",
	"hero_thornwake_nara_graftsibyl": "hero_strategic_thornwake_nara_graftsibyl",
	"hero_brasshollow_harro_debtrune": "hero_strategic_brasshollow_harro_debtrune",
	"hero_veilmourn_orso_nightchart": "hero_strategic_veilmourn_orso_nightchart",
	"hero_embercourt_orra_cinderquill": "hero_ritual_embercourt_orra_cinderquill",
	"hero_mireclaw_nix_votivejaw": "hero_ritual_mireclaw_nix_votivejaw",
	"hero_sunvault_essa_daynote": "hero_ritual_sunvault_essa_daynote",
	"hero_thornwake_osmund_pollenglass": "hero_ritual_thornwake_osmund_pollenglass",
	"hero_brasshollow_odrik_heatpriest": "hero_ritual_brasshollow_odrik_heatpriest",
	"hero_veilmourn_thir_obituaryink": "hero_ritual_veilmourn_thir_obituaryink",
	"hero_embercourt_jorun_beaconscribe": "hero_arcane_embercourt_jorun_beaconscribe",
	"hero_mireclaw_edda_rotlamp": "hero_arcane_mireclaw_edda_rotlamp",
	"hero_sunvault_mirro_halometer": "hero_arcane_sunvault_mirro_halometer",
	"hero_thornwake_elian_loamchant": "hero_arcane_thornwake_elian_loamchant",
	"hero_brasshollow_lina_gaugesavant": "hero_arcane_brasshollow_lina_gaugesavant",
	"hero_veilmourn_sael_mirrorbell": "hero_arcane_veilmourn_sael_mirrorbell",
	"hero_mireclaw_pell_reedscript": "hero_roster_mireclaw_pell_reedscript",
	"hero_mireclaw_zhorra_fenwake": "hero_roster_mireclaw_zhorra_fenwake",
	"hero_sunvault_dovan_lenscaptain": "hero_roster_sunvault_dovan_lenscaptain",
	"hero_sunvault_renn_facetlane": "hero_roster_sunvault_renn_facetlane",
	"hero_thornwake_merek_greenbarrow": "hero_roster_thornwake_merek_greenbarrow",
	"hero_thornwake_ralka_mossvein": "hero_roster_thornwake_ralka_mossvein",
	"hero_brasshollow_pava_ashmeter": "hero_roster_brasshollow_pava_ashmeter",
	"hero_brasshollow_vellum_quench": "hero_roster_brasshollow_vellum_quench",
	"hero_veilmourn_damar_oriflag": "hero_roster_veilmourn_damar_oriflag",
	"hero_veilmourn_nacre_vowless": "hero_roster_veilmourn_nacre_vowless",
}
const PRESENTATION_HERO_IDS := [
	"hero_lyra", "hero_vaska", "hero_solera", "hero_thornwake_silsa_bramblehound", "hero_brasshollow_marka_ironclause", "hero_veilmourn_ivara_blacktide",
	"hero_neral", "hero_seren",
	"hero_torren", "hero_varis",
	"hero_embercourt_helva_tollbrand", "hero_tarn", "hero_sunvault_ilyr_glassmarshal", "hero_thornwake_halen_thorncart", "hero_brasshollow_kuld_varn", "hero_veilmourn_jessa_keelwarden",
	"hero_embercourt_saren_lockmaster", "hero_orrik", "hero_thalen", "hero_thornwake_nara_graftsibyl", "hero_brasshollow_harro_debtrune", "hero_veilmourn_orso_nightchart",
	"hero_mireclaw_pell_reedscript", "hero_mireclaw_zhorra_fenwake", "hero_sunvault_dovan_lenscaptain", "hero_sunvault_renn_facetlane", "hero_thornwake_merek_greenbarrow",
	"hero_thornwake_ralka_mossvein", "hero_brasshollow_pava_ashmeter", "hero_brasshollow_vellum_quench", "hero_veilmourn_damar_oriflag", "hero_veilmourn_nacre_vowless",
]
const TAVERN_VANGUARD_CASES := [
	{"scenario_id": "river-pass", "hero_id": "hero_embercourt_belis_rainledger"},
	{"scenario_id": "bogbound-oath", "hero_id": "hero_sable"},
	{"scenario_id": "prismhearth-watch", "hero_id": "hero_sunvault_calis_sunvein"},
	{"scenario_id": "mireford-skirmish", "hero_id": "hero_thornwake_ardren_briarmarshal"},
	{"scenario_id": "orevein-contract", "hero_id": "hero_brasshollow_daxis_chaincaptain"},
	{"scenario_id": "bellwake-wreck-claim", "hero_id": "hero_veilmourn_cela_mistcorsair"},
]
const TAVERN_SPECIALIST_CASES := [
	{"scenario_id": "river-pass", "hero_id": "hero_torren"},
	{"scenario_id": "bogbound-oath", "hero_id": "hero_mireclaw_brakka_mudkeel"},
	{"scenario_id": "prismhearth-watch", "hero_id": "hero_varis"},
	{"scenario_id": "mireford-skirmish", "hero_id": "hero_thornwake_veyra_seedseer"},
	{"scenario_id": "orevein-contract", "hero_id": "hero_brasshollow_selka_pitmarshal"},
	{"scenario_id": "bellwake-wreck-claim", "hero_id": "hero_veilmourn_morwen_wakeoracle"},
]
const TAVERN_FIELD_COMMANDER_CASES := [
	{"scenario_id": "river-pass", "hero_id": "hero_embercourt_helva_tollbrand"},
	{"scenario_id": "bogbound-oath", "hero_id": "hero_tarn"},
	{"scenario_id": "prismhearth-watch", "hero_id": "hero_sunvault_ilyr_glassmarshal"},
	{"scenario_id": "mireford-skirmish", "hero_id": "hero_thornwake_halen_thorncart"},
	{"scenario_id": "orevein-contract", "hero_id": "hero_brasshollow_kuld_varn"},
	{"scenario_id": "bellwake-wreck-claim", "hero_id": "hero_veilmourn_jessa_keelwarden"},
]
const TAVERN_STRATEGIC_OFFICER_CASES := [
	{"scenario_id": "river-pass", "hero_id": "hero_embercourt_saren_lockmaster"},
	{"scenario_id": "bogbound-oath", "hero_id": "hero_orrik"},
	{"scenario_id": "prismhearth-watch", "hero_id": "hero_thalen"},
	{"scenario_id": "mireford-skirmish", "hero_id": "hero_thornwake_nara_graftsibyl"},
	{"scenario_id": "orevein-contract", "hero_id": "hero_brasshollow_harro_debtrune"},
	{"scenario_id": "bellwake-wreck-claim", "hero_id": "hero_veilmourn_orso_nightchart"},
]
const TAVERN_RITUAL_SCHOLAR_CASES := [
	{"scenario_id": "river-pass", "hero_id": "hero_embercourt_orra_cinderquill"},
	{"scenario_id": "bogbound-oath", "hero_id": "hero_mireclaw_nix_votivejaw"},
	{"scenario_id": "prismhearth-watch", "hero_id": "hero_sunvault_essa_daynote"},
	{"scenario_id": "mireford-skirmish", "hero_id": "hero_thornwake_osmund_pollenglass"},
	{"scenario_id": "orevein-contract", "hero_id": "hero_brasshollow_odrik_heatpriest"},
	{"scenario_id": "bellwake-wreck-claim", "hero_id": "hero_veilmourn_thir_obituaryink"},
]
const TAVERN_ARCANE_CONTROLLER_CASES := [
	{"scenario_id": "river-pass", "hero_id": "hero_embercourt_jorun_beaconscribe"},
	{"scenario_id": "bogbound-oath", "hero_id": "hero_mireclaw_edda_rotlamp"},
	{"scenario_id": "prismhearth-watch", "hero_id": "hero_sunvault_mirro_halometer"},
	{"scenario_id": "mireford-skirmish", "hero_id": "hero_thornwake_elian_loamchant"},
	{"scenario_id": "orevein-contract", "hero_id": "hero_brasshollow_lina_gaugesavant"},
	{"scenario_id": "bellwake-wreck-claim", "hero_id": "hero_veilmourn_sael_mirrorbell"},
]
const TAVERN_FINAL_ROSTER_CASES := [
	{"scenario_id": "bogbound-oath", "hero_id": "hero_mireclaw_pell_reedscript"},
	{"scenario_id": "bogbound-oath", "hero_id": "hero_mireclaw_zhorra_fenwake"},
	{"scenario_id": "prismhearth-watch", "hero_id": "hero_sunvault_dovan_lenscaptain"},
	{"scenario_id": "prismhearth-watch", "hero_id": "hero_sunvault_renn_facetlane"},
	{"scenario_id": "mireford-skirmish", "hero_id": "hero_thornwake_merek_greenbarrow"},
	{"scenario_id": "mireford-skirmish", "hero_id": "hero_thornwake_ralka_mossvein"},
	{"scenario_id": "orevein-contract", "hero_id": "hero_brasshollow_pava_ashmeter"},
	{"scenario_id": "orevein-contract", "hero_id": "hero_brasshollow_vellum_quench"},
	{"scenario_id": "bellwake-wreck-claim", "hero_id": "hero_veilmourn_damar_oriflag"},
	{"scenario_id": "bellwake-wreck-claim", "hero_id": "hero_veilmourn_nacre_vowless"},
]
const ALL_SCENARIO_STARTS := {
	"river-pass": "hero_lyra",
	"causeway-stand": "hero_lyra",
	"fen-crown": "hero_lyra",
	"stonewake-watch": "hero_caelen",
	"reedbarrow-ferry": "hero_caelen",
	"nightglass-redoubt": "hero_caelen",
	"bogbound-oath": "hero_vaska",
	"charter-pyre": "hero_vaska",
	"lockmarsh-surge": "hero_vaska",
	"ironbridge-stand": "hero_mira",
	"prismhearth-watch": "hero_solera",
	"glassroad-sundering": "hero_solera",
	"daybreak-spire": "hero_solera",
	"glassfen-breakers": "hero_caelen",
	"mireford-skirmish": "hero_thornwake_silsa_bramblehound",
	"orevein-contract": "hero_brasshollow_marka_ironclause",
	"bellwake-wreck-claim": "hero_veilmourn_ivara_blacktide",
	"ninefold-confluence": "hero_mira",
	"rootgate-toll": "hero_thornwake_tova_rootwright",
	"fogchart-mooring": "hero_veilmourn_ruln_vanehook",
	"clauseworks-counterclaim": "hero_brasshollow_oren_bellfounder",
	"nightglass-ledger-reversal": "hero_mireclaw_kessa_chainboom",
	"halo-reserve-refraction-claim": "hero_neral",
	"charter-bastion-counterseal": "hero_seren",
}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var scenario_starts := _validate_signature_scenario_starts()
	if not bool(scenario_starts.get("ok", false)):
		_fail("Signature hero scenario-start validation failed: %s" % scenario_starts)
		return
	var tavern_vanguard := _validate_tavern_vanguard_recruitment()
	if not bool(tavern_vanguard.get("ok", false)):
		_fail("Tavern-vanguard recruitment validation failed: %s" % tavern_vanguard)
		return
	var tavern_specialists := _validate_tavern_specialist_recruitment()
	if not bool(tavern_specialists.get("ok", false)):
		_fail("Tavern-specialist recruitment validation failed: %s" % tavern_specialists)
		return
	var tavern_field_commanders := _validate_tavern_field_commander_recruitment()
	if not bool(tavern_field_commanders.get("ok", false)):
		_fail("Tavern field-commander recruitment validation failed: %s" % tavern_field_commanders)
		return
	var tavern_strategic_officers := _validate_tavern_strategic_officer_recruitment()
	if not bool(tavern_strategic_officers.get("ok", false)):
		_fail("Tavern strategic-officer recruitment validation failed: %s" % tavern_strategic_officers)
		return
	var tavern_ritual_scholars := _validate_tavern_ritual_scholar_recruitment()
	if not bool(tavern_ritual_scholars.get("ok", false)):
		_fail("Tavern ritual-scholar recruitment validation failed: %s" % tavern_ritual_scholars)
		return
	var tavern_arcane_controllers := _validate_tavern_arcane_controller_recruitment()
	if not bool(tavern_arcane_controllers.get("ok", false)):
		_fail("Tavern arcane-controller recruitment validation failed: %s" % tavern_arcane_controllers)
		return
	var tavern_final_roster := _validate_tavern_final_roster_recruitment()
	if not bool(tavern_final_roster.get("ok", false)):
		_fail("Tavern final-roster recruitment validation failed: %s" % tavern_final_roster)
		return
	var original_window_size := get_window().size
	var rows: Array = []
	for viewport_size in VIEWPORT_SIZES:
		var row: Dictionary = await _run_viewport(viewport_size)
		rows.append(row)
		if not bool(row.get("ok", false)):
			_fail("Overworld faction hero sprite row failed: %s" % row)
			return
	get_window().size = original_window_size
	await get_tree().process_frame
	print("OVERWORLD_FACTION_HERO_SPRITE_RUNTIME_REPORT %s" % JSON.stringify({
		"ok": true,
		"production_hero_count": 60,
		"signature_hero_count": 6,
		"mapped_hero_identity_count": EXPECTED_HERO_ASSETS.size(),
		"tavern_vanguard_count": TAVERN_VANGUARD_CASES.size(),
		"tavern_specialist_count": TAVERN_SPECIALIST_CASES.size(),
		"tavern_field_commander_count": TAVERN_FIELD_COMMANDER_CASES.size(),
		"tavern_strategic_officer_count": TAVERN_STRATEGIC_OFFICER_CASES.size(),
		"tavern_ritual_scholar_count": TAVERN_RITUAL_SCHOLAR_CASES.size(),
		"tavern_arcane_controller_count": TAVERN_ARCANE_CONTROLLER_CASES.size(),
		"tavern_final_roster_count": TAVERN_FINAL_ROSTER_CASES.size(),
		"presentation_hero_count": PRESENTATION_HERO_IDS.size(),
		"faction_count": 6,
		"scenario_starts": scenario_starts,
		"tavern_vanguard": tavern_vanguard,
		"tavern_specialists": tavern_specialists,
		"tavern_field_commanders": tavern_field_commanders,
		"tavern_strategic_officers": tavern_strategic_officers,
		"tavern_ritual_scholars": tavern_ritual_scholars,
		"tavern_arcane_controllers": tavern_arcane_controllers,
		"tavern_final_roster": tavern_final_roster,
		"viewports": [[1280, 720], [1920, 1080]],
		"fallback": "procedural_hero_marker",
		"rows": rows,
		"save_version": SessionStateStore.SAVE_VERSION,
	}))
	get_tree().quit(0)

func _run_viewport(viewport_size: Vector2i) -> Dictionary:
	get_window().size = viewport_size
	await get_tree().process_frame
	await get_tree().process_frame
	if get_window().size != viewport_size:
		return {"ok": false, "failure": "window_size", "actual": get_window().size}

	var session = ScenarioFactory.create_session(SCENARIO_ID, "hard", SessionState.LAUNCH_MODE_SKIRMISH)
	_configure_hero_fixture(session)
	session = SessionState.set_active_session(session)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var map_view = shell.get_node_or_null("%Map")
	if map_view == null or not map_view.has_method("validation_hero_presentation_profiles") or not map_view.has_method("validation_hero_draw_layout") or not map_view.has_method("validation_tile_focus_layout"):
		shell.queue_free()
		return {"ok": false, "failure": "validation_surface_missing"}
	var authority_before: Dictionary = session.to_dict()
	var identity_mapping := _validate_identity_mapping(map_view)
	if not bool(identity_mapping.get("ok", false)):
		shell.queue_free()
		return {"ok": false, "failure": "identity_mapping", "detail": identity_mapping}
	var profiles: Array = map_view.call("validation_hero_presentation_profiles")
	var exact := _validate_profiles(profiles, map_view)
	if not bool(exact.get("ok", false)):
		shell.queue_free()
		return {"ok": false, "failure": "hero_profiles", "detail": exact}
	if not await _capture_hero_identities(viewport_size):
		shell.queue_free()
		return {"ok": false, "failure": "capture"}

	var active_tile_value: Dictionary = exact.get("active_tile", {})
	var active_tile := Vector2i(int(active_tile_value.get("x", -1)), int(active_tile_value.get("y", -1)))
	var moving_layout: Dictionary = map_view.call("validation_hero_draw_layout", active_tile, true)
	var moving_pennant: Dictionary = moving_layout.get("command_pennant", {})
	var moving_layout_exact: bool = String(moving_layout.get("mode", "")) == "full_tile_world_hero" \
		and not bool(moving_layout.get("town_footprint_colocated", true)) \
		and is_equal_approx(float(moving_layout.get("hero_rect_extent_fraction", 0.0)), 1.0) \
		and is_equal_approx(float(moving_layout.get("sprite_extent_fraction", 0.0)), 0.64) \
		and String(moving_layout.get("sprite_silhouette_model", "")) == SILHOUETTE_MODEL \
		and bool(moving_layout.get("sprite_silhouette_contained_in_tile", false)) \
		and String(moving_pennant.get("model", "")) == COMMAND_PENNANT_MODEL \
		and bool(moving_pennant.get("active", false)) \
		and bool(moving_pennant.get("cloth_contained", false)) \
		and bool(moving_pennant.get("shadow_contained", false)) \
		and bool(moving_pennant.get("pole_contained", false))
	if not moving_layout_exact:
		shell.queue_free()
		return {"ok": false, "failure": "moving_layout_control", "layout": moving_layout}
	var focus_exact: Dictionary = _validate_focus_layouts(map_view, exact)
	if not bool(focus_exact.get("ok", false)):
		shell.queue_free()
		return {"ok": false, "failure": "focus_layouts", "detail": focus_exact}

	var heroes: Array = session.overworld.get("player_heroes", [])
	var first_hero: Dictionary = heroes[0]
	var faction_fallback_exact := _validate_faction_fallback(map_view)
	first_hero["id"] = "hero_missing_faction_sprite_fixture"
	shell.call("_refresh")
	await get_tree().process_frame
	await get_tree().process_frame
	var first_position: Dictionary = first_hero.get("position", {})
	var fallback_tile := Vector2i(int(first_position.get("x", -1)), int(first_position.get("y", -1)))
	var fallback_presentation: Dictionary = map_view.call("validation_tile_presentation", fallback_tile)
	var fallback: Dictionary = fallback_presentation.get("hero_presentation", {})
	var fallback_exact: bool = String(fallback.get("hero_id", "")) == "hero_missing_faction_sprite_fixture" \
		and String(fallback.get("faction_id", "")) == "" \
		and String(fallback.get("sprite_asset_id", "")) == "" \
		and bool(fallback.get("uses_procedural_fallback", false)) \
		and not bool(fallback.get("uses_faction_sprite", true)) \
		and String(fallback.get("sprite_silhouette_model", "")) == SILHOUETTE_MODEL \
		and String(fallback.get("command_pennant_model", "")) == COMMAND_PENNANT_MODEL \
		and String(fallback.get("layout", {}).get("mode", "")) == "compact_town_footprint_visitor" \
		and bool(fallback.get("layout", {}).get("sprite_contained_in_tile", false))

	session.from_dict(authority_before)
	shell.call("_refresh")
	await get_tree().process_frame
	await get_tree().process_frame
	var restored_profiles: Array = map_view.call("validation_hero_presentation_profiles")
	var restored_focus_exact: bool = map_view.call("validation_tile_focus_layout", active_tile) == focus_exact.get("town_layout", {}) \
		and map_view.call("validation_tile_focus_layout", focus_exact.get("ordinary_tile", Vector2i(-1, -1))) == focus_exact.get("ordinary_layout", {})
	var restored_exact: bool = restored_profiles == profiles and restored_focus_exact and session.to_dict() == authority_before
	var shell_rect: Rect2 = shell.get_global_rect() if shell is Control else Rect2()
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	var containment_exact := viewport_rect.encloses(shell_rect)
	shell.queue_free()
	await get_tree().process_frame
	return {
		"ok": bool(identity_mapping.get("ok", false)) and faction_fallback_exact and fallback_exact and restored_exact and containment_exact and moving_layout_exact and bool(focus_exact.get("ok", false)),
		"viewport": [viewport_size.x, viewport_size.y],
		"profile_count": profiles.size(),
		"asset_ids": exact.get("asset_ids", []),
		"mapped_asset_ids": identity_mapping.get("asset_ids", []),
		"identity_mapping_exact": identity_mapping.get("ok", false),
		"active_identity_exact": exact.get("active_identity_exact", false),
		"grounding_exact": exact.get("grounding_exact", false),
		"readability_exact": exact.get("readability_exact", false),
		"town_footprint_layout_exact": exact.get("town_footprint_layout_exact", false),
		"ordinary_layout_exact": exact.get("ordinary_layout_exact", false),
		"moving_layout_exact": moving_layout_exact,
		"town_focus_layout_exact": focus_exact.get("town_focus_layout_exact", false),
		"ordinary_focus_layout_exact": focus_exact.get("ordinary_focus_layout_exact", false),
		"town_selection_interior_fill": focus_exact.get("town_selection_interior_fill", true),
		"fallback_exact": fallback_exact,
		"fallback": fallback.duplicate(true) if not fallback_exact else {},
		"faction_fallback_exact": faction_fallback_exact,
		"restored_exact": restored_exact,
		"containment_exact": containment_exact,
	}

func _validate_profiles(profiles: Array, map_view: Node) -> Dictionary:
	if profiles.size() != PRESENTATION_HERO_IDS.size():
		return {"ok": false, "reason": "profile_count", "actual": profiles.size()}
	var seen_factions: Dictionary = {}
	var seen_assets: Dictionary = {}
	var layout_rows: Array = []
	var active_count := 0
	var grounding_exact := true
	var town_footprint_layout_count := 0
	var ordinary_layout_count := 0
	var active_tile := Vector2i(-1, -1)
	var ordinary_tile := Vector2i(-1, -1)
	var geometry_exact := true
	var readability_exact := true
	var view_metrics: Dictionary = map_view.call("validation_view_metrics")
	var board_rect := _rect_from_payload(view_metrics.get("board_rect", {}))
	var map_size_value: Dictionary = view_metrics.get("map_size", {})
	var map_size := Vector2i(int(map_size_value.get("x", 0)), int(map_size_value.get("y", 0)))
	for profile_value in profiles:
		if not (profile_value is Dictionary):
			return {"ok": false, "reason": "profile_type"}
		var profile: Dictionary = profile_value
		var hero_id := String(profile.get("hero_id", ""))
		var faction_id := String(profile.get("faction_id", ""))
		var expected_asset_id := String(EXPECTED_HERO_ASSETS.get(hero_id, ""))
		var runtime_group := _hero_runtime_group(expected_asset_id)
		var expected_path := "res://art/overworld/runtime/heroes/%s/%s.png" % [runtime_group, hero_id]
		if expected_asset_id == "" or String(profile.get("sprite_asset_id", "")) != expected_asset_id:
			return {"ok": false, "reason": "identity", "profile": profile}
		if String(profile.get("sprite_path", "")) != expected_path or not (load(expected_path) is Texture2D):
			return {"ok": false, "reason": "texture", "profile": profile}
		if not bool(profile.get("uses_identity_sprite", false)) or bool(profile.get("uses_faction_sprite", true)) or bool(profile.get("uses_procedural_fallback", true)):
			return {"ok": false, "reason": "fallback_state", "profile": profile}
		if bool(profile.get("is_active", false)):
			active_count += 1
			var active_tile_value: Dictionary = profile.get("tile", {})
			active_tile = Vector2i(int(active_tile_value.get("x", -1)), int(active_tile_value.get("y", -1)))
		grounding_exact = grounding_exact \
			and String(profile.get("grounding_model", "")) == "hero_foot_contact_without_base_ellipse" \
			and String(profile.get("depth_cue_model", "")) == "hero_foot_contact_shadow_with_boot_occlusion"
		seen_factions[faction_id] = true
		seen_assets[expected_asset_id] = true
		var layout: Dictionary = profile.get("layout", {})
		var command_pennant: Dictionary = layout.get("command_pennant", {})
		readability_exact = readability_exact \
			and String(profile.get("sprite_silhouette_model", "")) == SILHOUETTE_MODEL \
			and String(profile.get("command_pennant_model", "")) == COMMAND_PENNANT_MODEL \
			and String(layout.get("sprite_silhouette_model", "")) == SILHOUETTE_MODEL \
			and float(layout.get("sprite_silhouette_width_px", 0.0)) >= 1.35 \
			and bool(layout.get("sprite_silhouette_contained_in_tile", false)) \
			and String(command_pennant.get("model", "")) == COMMAND_PENNANT_MODEL \
			and bool(command_pennant.get("active", false)) == bool(profile.get("is_active", false)) \
			and String(command_pennant.get("shape_id", "")) == ("active_square_fold" if bool(profile.get("is_active", false)) else "reserve_swallowtail") \
			and bool(command_pennant.get("cloth_contained", false)) \
			and bool(command_pennant.get("shadow_contained", false)) \
			and bool(command_pennant.get("pole_contained", false))
		var tile_value: Dictionary = profile.get("tile", {})
		var tile := Vector2i(int(tile_value.get("x", -1)), int(tile_value.get("y", -1)))
		layout_rows.append({
			"hero_id": hero_id,
			"tile": {"x": tile.x, "y": tile.y},
			"mode": String(layout.get("mode", "")),
			"town_footprint_colocated": bool(layout.get("town_footprint_colocated", false)),
		})
		if bool(layout.get("town_footprint_colocated", false)):
			town_footprint_layout_count += 1
			var tile_presentation: Dictionary = map_view.call("validation_tile_presentation", tile)
			var town_presentation: Dictionary = tile_presentation.get("town_presentation", {})
			var tile_rect := _tile_rect_from_metrics(board_rect, map_size, tile)
			var hero_rect := _rect_from_payload(layout.get("hero_rect", {}))
			var sprite_rect := _rect_from_payload(layout.get("sprite_rect", {}))
			geometry_exact = geometry_exact \
				and bool(profile.get("is_active", false)) \
				and String(layout.get("mode", "")) == "compact_town_footprint_visitor" \
				and is_equal_approx(float(layout.get("hero_rect_extent_fraction", 0.0)), 0.76) \
				and is_equal_approx(float(layout.get("sprite_extent_fraction", 0.0)), 0.4484) \
				and bool(layout.get("sprite_contained_in_tile", false)) \
				and tile_rect.encloses(hero_rect) and tile_rect.encloses(sprite_rect) \
				and float(layout.get("ground_anchor_y_fraction", 0.0)) > 0.75 \
				and bool(tile_presentation.get("has_visible_hero", false)) \
				and bool(tile_presentation.get("has_town_non_entry", false)) \
				and String(town_presentation.get("presentation_model", "")) == "town_3x4_visual_landmark_3x2_logical_bottom_middle_entry" \
				and String(town_presentation.get("tile_role", "")) == "blocked_non_entry_footprint"
		else:
			ordinary_layout_count += 1
			if ordinary_tile.x < 0:
				ordinary_tile = tile
			geometry_exact = geometry_exact \
				and String(layout.get("mode", "")) == "full_tile_world_hero" \
				and is_equal_approx(float(layout.get("hero_rect_extent_fraction", 0.0)), 1.0) \
				and is_equal_approx(float(layout.get("sprite_extent_fraction", 0.0)), 0.64)
	return {
		"ok": seen_factions.size() == 6 and seen_assets.size() == PRESENTATION_HERO_IDS.size() and active_count == 1 and grounding_exact and readability_exact and town_footprint_layout_count == 1 and ordinary_layout_count == PRESENTATION_HERO_IDS.size() - 1 and geometry_exact,
		"asset_ids": seen_assets.keys(),
		"active_identity_exact": active_count == 1,
		"grounding_exact": grounding_exact,
		"readability_exact": readability_exact,
		"town_footprint_layout_exact": town_footprint_layout_count == 1 and geometry_exact,
		"ordinary_layout_exact": ordinary_layout_count == PRESENTATION_HERO_IDS.size() - 1 and geometry_exact,
		"active_tile": {"x": active_tile.x, "y": active_tile.y},
		"ordinary_tile": {"x": ordinary_tile.x, "y": ordinary_tile.y},
		"layout_rows": layout_rows,
	}

func _validate_identity_mapping(map_view: Node) -> Dictionary:
	var asset_ids: Array = []
	for hero_id_value in EXPECTED_HERO_ASSETS:
		var hero_id := String(hero_id_value)
		var expected_asset_id := String(EXPECTED_HERO_ASSETS.get(hero_id, ""))
		var actual_asset_id := String(map_view.call("_hero_sprite_asset_id", ContentService.get_hero(hero_id)))
		var expected_path := "res://art/overworld/runtime/heroes/%s/%s.png" % [_hero_runtime_group(expected_asset_id), hero_id]
		if actual_asset_id != expected_asset_id or not (load(expected_path) is Texture2D):
			return {"ok": false, "hero_id": hero_id, "expected_asset_id": expected_asset_id, "actual_asset_id": actual_asset_id, "expected_path": expected_path}
		asset_ids.append(actual_asset_id)
	return {"ok": asset_ids.size() == EXPECTED_HERO_ASSETS.size(), "asset_ids": asset_ids}

func _hero_runtime_group(asset_id: String) -> String:
	if asset_id.begins_with("hero_signature_"):
		return "signature"
	if asset_id.begins_with("hero_lead_"):
		return "live_leads"
	if asset_id.begins_with("hero_specialist_"):
		return "tavern_specialists"
	if asset_id.begins_with("hero_field_"):
		return "tavern_field_commanders"
	if asset_id.begins_with("hero_strategic_"):
		return "tavern_strategic_officers"
	if asset_id.begins_with("hero_ritual_"):
		return "tavern_ritual_scholars"
	if asset_id.begins_with("hero_arcane_"):
		return "tavern_arcane_controllers"
	if asset_id.begins_with("hero_roster_"):
		return "tavern_final_roster"
	return "tavern_vanguard"

func _validate_faction_fallback(map_view: Node) -> bool:
	var hero_id := "hero_mireclaw_pell_reedscript"
	var identity_map: Dictionary = map_view.get("_hero_identity_asset_ids")
	var exact_asset_id := String(identity_map.get(hero_id, ""))
	if exact_asset_id != "hero_roster_mireclaw_pell_reedscript":
		return false
	identity_map.erase(hero_id)
	var fallback_exact: bool = String(map_view.call("_hero_sprite_asset_id", ContentService.get_hero(hero_id))) == "hero_faction_mireclaw"
	identity_map[hero_id] = exact_asset_id
	return fallback_exact and String(map_view.call("_hero_sprite_asset_id", ContentService.get_hero(hero_id))) == exact_asset_id

func _validate_focus_layouts(map_view: Node, profiles_exact: Dictionary) -> Dictionary:
	var active_tile_value: Dictionary = profiles_exact.get("active_tile", {})
	var active_tile := Vector2i(int(active_tile_value.get("x", -1)), int(active_tile_value.get("y", -1)))
	var ordinary_tile_value: Dictionary = profiles_exact.get("ordinary_tile", {})
	var ordinary_tile := Vector2i(int(ordinary_tile_value.get("x", -1)), int(ordinary_tile_value.get("y", -1)))
	if active_tile.x < 0 or ordinary_tile.x < 0:
		return {"ok": false, "reason": "missing_control_tiles"}
	var metrics: Dictionary = map_view.call("validation_view_metrics")
	var board_rect := _rect_from_payload(metrics.get("board_rect", {}))
	var map_size_value: Dictionary = metrics.get("map_size", {})
	var map_size := Vector2i(int(map_size_value.get("x", 0)), int(map_size_value.get("y", 0)))
	var active_tile_rect := _tile_rect_from_metrics(board_rect, map_size, active_tile)
	var ordinary_tile_rect := _tile_rect_from_metrics(board_rect, map_size, ordinary_tile)
	var hero_layout: Dictionary = map_view.call("validation_hero_draw_layout", active_tile, false)
	var town_tile_presentation: Dictionary = map_view.call("validation_tile_presentation", active_tile)
	var town_presentation: Dictionary = town_tile_presentation.get("town_presentation", {})
	var expected_town_rect := _footprint_rect_from_presentation(town_presentation, board_rect, map_size)
	var town_layout: Dictionary = map_view.call("validation_tile_focus_layout", active_tile)
	var ordinary_layout: Dictionary = map_view.call("validation_tile_focus_layout", ordinary_tile)
	var town_selection_visual_profile: Dictionary = town_layout.get("town_selection_visual_profile", {})
	var town_tile_selection_visual_profile: Dictionary = town_layout.get("tile_selection_visual_profile", {})
	var ordinary_town_selection_visual_profile: Dictionary = ordinary_layout.get("town_selection_visual_profile", {})
	var ordinary_tile_selection_visual_profile: Dictionary = ordinary_layout.get("tile_selection_visual_profile", {})
	var town_command_marker_profile: Dictionary = town_layout.get("hero_command_marker_profile", {})
	var ordinary_command_marker_profile: Dictionary = ordinary_layout.get("hero_command_marker_profile", {})
	var town_hero_focus_rect := _rect_from_payload(town_layout.get("hero_focus_rect", {}))
	var town_selection_rect := _rect_from_payload(town_layout.get("selection_rect", {}))
	var town_hover_rect := _rect_from_payload(town_layout.get("hover_rect", {}))
	var ordinary_hero_focus_rect := _rect_from_payload(ordinary_layout.get("hero_focus_rect", {}))
	var ordinary_selection_rect := _rect_from_payload(ordinary_layout.get("selection_rect", {}))
	var ordinary_hover_rect := _rect_from_payload(ordinary_layout.get("hover_rect", {}))
	var town_hero_sprite_rect := _rect_from_payload(hero_layout.get("sprite_rect", {}))
	var town_command_marker_exact := _hero_command_marker_profile_exact(town_command_marker_profile, town_hero_focus_rect, town_hero_sprite_rect)
	var ordinary_command_marker_exact := _hero_command_marker_profile_exact(ordinary_command_marker_profile, ordinary_hero_focus_rect)
	var expected_town_selection_extent := minf(expected_town_rect.size.x, expected_town_rect.size.y)
	var expected_town_selection_inset := maxf(4.0, expected_town_selection_extent * 0.045)
	var expected_town_selection_perimeter := expected_town_rect.grow(-expected_town_selection_inset)
	var expected_tile_selection_extent := minf(ordinary_tile_rect.size.x, ordinary_tile_rect.size.y)
	var expected_tile_selection_inset := maxf(4.0, expected_tile_selection_extent * 0.085)
	var expected_tile_selection_perimeter := ordinary_tile_rect.grow(-expected_tile_selection_inset)
	var town_focus_layout_exact: bool = bool(town_layout.get("hero_uses_compact_town_footprint_rect", false)) \
		and town_command_marker_exact \
		and town_hero_focus_rect == _rect_from_payload(hero_layout.get("hero_rect", {})) \
		and active_tile_rect.encloses(town_hero_focus_rect) \
		and bool(town_layout.get("selection_uses_town_footprint_rect", false)) \
		and not bool(town_layout.get("selection_uses_interior_fill", true)) \
		and bool(town_layout.get("selection_uses_cartographic_town_perimeter", false)) \
		and not bool(town_layout.get("selection_uses_cartographic_tile_reticle", true)) \
		and String(town_layout.get("selection_visual_model", "")) == "open_cartographic_footprint_corner_and_midpoint_ticks" \
		and town_selection_rect == expected_town_rect \
		and _rect_from_payload(town_selection_visual_profile.get("perimeter_rect", {})) == expected_town_selection_perimeter \
		and is_equal_approx(float(town_selection_visual_profile.get("perimeter_inset_px", 0.0)), expected_town_selection_inset) \
		and is_equal_approx(float(town_selection_visual_profile.get("corner_alpha", 0.0)), 0.78) \
		and is_equal_approx(float(town_selection_visual_profile.get("corner_length_px", 0.0)), maxf(10.0, expected_town_selection_extent * 0.10)) \
		and is_equal_approx(float(town_selection_visual_profile.get("corner_width_px", 0.0)), maxf(1.5, expected_town_selection_extent * 0.010)) \
		and is_equal_approx(float(town_selection_visual_profile.get("midpoint_alpha", 0.0)), 0.34) \
		and is_equal_approx(float(town_selection_visual_profile.get("midpoint_length_px", 0.0)), maxf(6.0, expected_town_selection_extent * 0.035)) \
		and is_equal_approx(float(town_selection_visual_profile.get("midpoint_width_px", 0.0)), maxf(1.25, expected_town_selection_extent * 0.008)) \
		and not bool(town_selection_visual_profile.get("continuous_outline", true)) \
		and is_zero_approx(float(town_selection_visual_profile.get("interior_fill_alpha", -1.0))) \
		and town_tile_selection_visual_profile.is_empty() \
		and bool(town_layout.get("hover_uses_town_footprint_rect", false)) \
		and town_hover_rect == expected_town_rect \
		and town_layout.get("town_entry_tile", {}) == town_presentation.get("entry_tile", {})
	var ordinary_focus_layout_exact: bool = not bool(ordinary_layout.get("hero_uses_compact_town_footprint_rect", true)) \
		and ordinary_command_marker_exact \
		and ordinary_hero_focus_rect == ordinary_tile_rect \
		and not bool(ordinary_layout.get("selection_uses_town_footprint_rect", true)) \
		and not bool(ordinary_layout.get("selection_uses_interior_fill", true)) \
		and not bool(ordinary_layout.get("selection_uses_cartographic_town_perimeter", true)) \
		and bool(ordinary_layout.get("selection_uses_cartographic_tile_reticle", false)) \
		and String(ordinary_layout.get("selection_visual_model", "")) == "open_cartographic_tile_corner_and_midpoint_ticks" \
		and ordinary_town_selection_visual_profile.is_empty() \
		and _rect_from_payload(ordinary_tile_selection_visual_profile.get("perimeter_rect", {})) == expected_tile_selection_perimeter \
		and is_equal_approx(float(ordinary_tile_selection_visual_profile.get("perimeter_inset_px", 0.0)), expected_tile_selection_inset) \
		and is_equal_approx(float(ordinary_tile_selection_visual_profile.get("corner_alpha", 0.0)), 0.82) \
		and is_equal_approx(float(ordinary_tile_selection_visual_profile.get("corner_length_px", 0.0)), maxf(8.0, expected_tile_selection_extent * 0.18)) \
		and is_equal_approx(float(ordinary_tile_selection_visual_profile.get("corner_width_px", 0.0)), maxf(1.5, expected_tile_selection_extent * 0.022)) \
		and is_equal_approx(float(ordinary_tile_selection_visual_profile.get("midpoint_alpha", 0.0)), 0.42) \
		and is_equal_approx(float(ordinary_tile_selection_visual_profile.get("midpoint_length_px", 0.0)), maxf(5.0, expected_tile_selection_extent * 0.08)) \
		and is_equal_approx(float(ordinary_tile_selection_visual_profile.get("midpoint_width_px", 0.0)), maxf(1.25, expected_tile_selection_extent * 0.016)) \
		and not bool(ordinary_tile_selection_visual_profile.get("continuous_outline", true)) \
		and is_zero_approx(float(ordinary_tile_selection_visual_profile.get("interior_fill_alpha", -1.0))) \
		and ordinary_selection_rect == ordinary_tile_rect \
		and not bool(ordinary_layout.get("hover_uses_town_footprint_rect", true)) \
		and ordinary_hover_rect == ordinary_tile_rect \
		and (ordinary_layout.get("town_entry_tile", {}) as Dictionary).is_empty()
	return {
		"ok": town_focus_layout_exact and ordinary_focus_layout_exact,
		"town_focus_layout_exact": town_focus_layout_exact,
		"ordinary_focus_layout_exact": ordinary_focus_layout_exact,
		"town_command_marker_exact": town_command_marker_exact,
		"ordinary_command_marker_exact": ordinary_command_marker_exact,
		"town_selection_interior_fill": bool(town_layout.get("selection_uses_interior_fill", true)),
		"town_selection_visual_model": String(town_layout.get("selection_visual_model", "")),
		"town_selection_visual_profile": town_selection_visual_profile.duplicate(true),
		"ordinary_tile_selection_visual_profile": ordinary_tile_selection_visual_profile.duplicate(true),
		"town_layout": town_layout.duplicate(true),
		"ordinary_layout": ordinary_layout.duplicate(true),
		"ordinary_tile": ordinary_tile,
	}

func _footprint_rect_from_presentation(presentation: Dictionary, board_rect: Rect2, map_size: Vector2i) -> Rect2:
	var cells: Array = presentation.get("footprint_cells", [])
	var result := Rect2()
	var has_cell := false
	for cell_value in cells:
		if not (cell_value is Dictionary) or not bool(cell_value.get("in_bounds", false)):
			continue
		var tile := Vector2i(int(cell_value.get("x", -1)), int(cell_value.get("y", -1)))
		var cell_rect := _tile_rect_from_metrics(board_rect, map_size, tile)
		result = result.merge(cell_rect) if has_cell else cell_rect
		has_cell = true
	return result

func _rect_from_payload(value: Variant) -> Rect2:
	var payload: Dictionary = value if value is Dictionary else {}
	return Rect2(
		float(payload.get("x", 0.0)),
		float(payload.get("y", 0.0)),
		float(payload.get("width", 0.0)),
		float(payload.get("height", 0.0))
	)

func _hero_command_marker_profile_exact(profile: Dictionary, focus_rect: Rect2, sprite_rect: Rect2 = Rect2()) -> bool:
	var extent := minf(focus_rect.size.x, focus_rect.size.y)
	var marker_rect := _rect_from_payload(profile.get("marker_rect", {}))
	var wing_length := float(profile.get("wing_length_px", 0.0))
	var wing_depth := float(profile.get("wing_depth_px", 0.0))
	var center_y := float(profile.get("center_y", 0.0))
	var ground_y := float(profile.get("ground_y", 0.0))
	var tick_length := float(profile.get("ground_tick_length_px", 0.0))
	var notch := float(profile.get("ground_notch_px", 0.0))
	var clears_sprite := true
	if sprite_rect.has_area():
		clears_sprite = marker_rect.position.x + wing_length <= sprite_rect.position.x \
			and marker_rect.end.x - wing_length >= sprite_rect.end.x \
			and ground_y > sprite_rect.end.y
	return String(profile.get("model", "")) == "open_lateral_command_wings_and_ground_tick" \
		and _rect_from_payload(profile.get("focus_rect", {})) == focus_rect \
		and marker_rect == focus_rect.grow(-maxf(1.25, extent * 0.035)) \
		and focus_rect.encloses(marker_rect) \
		and is_equal_approx(center_y, focus_rect.position.y + focus_rect.size.y * 0.48) \
		and is_equal_approx(wing_length, maxf(2.5, extent * 0.075)) \
		and is_equal_approx(wing_depth, maxf(3.0, extent * 0.085)) \
		and center_y - wing_depth >= marker_rect.position.y \
		and center_y + wing_depth <= marker_rect.end.y \
		and is_equal_approx(ground_y, focus_rect.position.y + focus_rect.size.y * 0.82) \
		and is_equal_approx(tick_length, maxf(6.0, extent * 0.18)) \
		and is_equal_approx(notch, maxf(1.5, extent * 0.035)) \
		and marker_rect.position.x <= marker_rect.get_center().x - tick_length * 0.5 \
		and marker_rect.end.x >= marker_rect.get_center().x + tick_length * 0.5 \
		and ground_y - notch >= marker_rect.position.y \
		and ground_y <= marker_rect.end.y \
		and float(profile.get("line_width_px", 0.0)) >= 1.25 \
		and float(profile.get("shadow_width_px", 0.0)) > float(profile.get("line_width_px", 0.0)) \
		and is_equal_approx(float(profile.get("marker_alpha", 0.0)), 0.82) \
		and is_equal_approx(float(profile.get("shadow_alpha", 0.0)), 0.40) \
		and bool(profile.get("antialiased", false)) \
		and not bool(profile.get("continuous_outline", true)) \
		and is_zero_approx(float(profile.get("interior_fill_alpha", -1.0))) \
		and clears_sprite

func _tile_rect_from_metrics(board_rect: Rect2, map_size: Vector2i, tile: Vector2i) -> Rect2:
	var cell_size := board_rect.size / Vector2(float(maxi(map_size.x, 1)), float(maxi(map_size.y, 1)))
	return Rect2(board_rect.position + Vector2(tile.x, tile.y) * cell_size, cell_size)

func _configure_hero_fixture(session) -> void:
	var source_heroes: Array = session.overworld.get("player_heroes", [])
	var source: Dictionary = source_heroes[0].duplicate(true)
	var heroes: Array = []
	var hero_ids: Array = PRESENTATION_HERO_IDS
	var town_footprint_tile := _player_town_footprint_hero_tile(session)
	var ordinary_positions := [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0), Vector2i(6, 0), Vector2i(7, 0), Vector2i(8, 0),
		Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4), Vector2i(7, 4), Vector2i(8, 4),
		Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1), Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3),
		Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3), Vector2i(6, 3), Vector2i(3, 2), Vector2i(4, 2),
	]
	for index in range(hero_ids.size()):
		var hero_id := String(hero_ids[index])
		var template := ContentService.get_hero(hero_id)
		var hero := source.duplicate(true)
		hero["id"] = hero_id
		hero["name"] = String(template.get("name", hero_id))
		hero["is_primary"] = index == 0
		var position: Vector2i = town_footprint_tile if index == 0 else ordinary_positions[index - 1]
		hero["position"] = {"x": position.x, "y": position.y}
		heroes.append(hero)
	session.hero_id = String(heroes[0].get("id", ""))
	session.overworld["player_heroes"] = heroes
	session.overworld["active_hero_id"] = String(heroes[0].get("id", ""))
	session.overworld["primary_hero_id"] = String(heroes[0].get("id", ""))
	session.overworld["hero"] = heroes[0].duplicate(true)
	session.overworld["hero_position"] = heroes[0].get("position", {}).duplicate(true)
	session.overworld["army"] = heroes[0].get("army", {}).duplicate(true)
	session.overworld["movement"] = heroes[0].get("movement", {}).duplicate(true)
	var map_size := OverworldRules.derive_map_size(session)
	var visible_tiles: Array = []
	var explored_tiles: Array = []
	for y in range(map_size.y):
		var visible_row: Array = []
		var explored_row: Array = []
		for _x in range(map_size.x):
			visible_row.append(false)
			explored_row.append(false)
		visible_tiles.append(visible_row)
		explored_tiles.append(explored_row)
	for hero in heroes:
		var position: Dictionary = hero.get("position", {})
		var x := int(position.get("x", -1))
		var y := int(position.get("y", -1))
		visible_tiles[y][x] = true
		explored_tiles[y][x] = true
	session.overworld["fog"] = {
		"visible_tiles": visible_tiles,
		"explored_tiles": explored_tiles,
		"visible_count": heroes.size(),
		"explored_count": heroes.size(),
		"total_tiles": map_size.x * map_size.y,
	}

func _validate_signature_scenario_starts() -> Dictionary:
	var rows := []
	for scenario_id_value in ALL_SCENARIO_STARTS:
		var scenario_id := String(scenario_id_value)
		var hero_id := String(ALL_SCENARIO_STARTS.get(scenario_id_value, ""))
		var session = ScenarioFactory.create_session(scenario_id, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
		var active_hero_id := String(session.overworld.get("active_hero_id", ""))
		var clone = SessionStateStore.new_session_data()
		clone.from_dict(session.to_dict())
		var exact: bool = session.hero_id == hero_id and active_hero_id == hero_id and clone.hero_id == hero_id and String(clone.overworld.get("active_hero_id", "")) == hero_id
		rows.append({"scenario_id": scenario_id, "hero_id": hero_id, "save_resume_exact": exact})
		if not exact:
			return {"ok": false, "rows": rows}
	return {"ok": rows.size() == ALL_SCENARIO_STARTS.size(), "rows": rows}

func _validate_tavern_vanguard_recruitment() -> Dictionary:
	return _validate_tavern_recruitment_cases(TAVERN_VANGUARD_CASES)

func _validate_tavern_specialist_recruitment() -> Dictionary:
	return _validate_tavern_recruitment_cases(TAVERN_SPECIALIST_CASES)

func _validate_tavern_field_commander_recruitment() -> Dictionary:
	return _validate_tavern_recruitment_cases(TAVERN_FIELD_COMMANDER_CASES)

func _validate_tavern_strategic_officer_recruitment() -> Dictionary:
	return _validate_tavern_recruitment_cases(TAVERN_STRATEGIC_OFFICER_CASES)

func _validate_tavern_ritual_scholar_recruitment() -> Dictionary:
	return _validate_tavern_recruitment_cases(TAVERN_RITUAL_SCHOLAR_CASES)

func _validate_tavern_arcane_controller_recruitment() -> Dictionary:
	return _validate_tavern_recruitment_cases(TAVERN_ARCANE_CONTROLLER_CASES)

func _validate_tavern_final_roster_recruitment() -> Dictionary:
	return _validate_tavern_recruitment_cases(TAVERN_FINAL_ROSTER_CASES)

func _validate_tavern_recruitment_cases(cases: Array) -> Dictionary:
	var rows: Array = []
	for case_value in cases:
		var case: Dictionary = case_value
		var scenario_id := String(case.get("scenario_id", ""))
		var hero_id := String(case.get("hero_id", ""))
		var session = ScenarioFactory.create_session(scenario_id, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
		var town := _first_player_town(session)
		if town.is_empty():
			return {"ok": false, "failure": "player_town_missing", "scenario_id": scenario_id}
		_move_active_hero_to_town(session, town)
		var buildings: Array = town.get("built_buildings", []).duplicate(true)
		if HeroCommandRules.HALL_BUILDING_ID not in buildings:
			buildings.append(HeroCommandRules.HALL_BUILDING_ID)
		town["built_buildings"] = buildings
		var hero_template := ContentService.get_hero(hero_id)
		var cost: Dictionary = HeroCommandRules.hero_recruit_cost(hero_template)
		var resources: Dictionary = session.overworld.get("resources", {}).duplicate(true)
		for resource_id_value in cost:
			var resource_id := String(resource_id_value)
			resources[resource_id] = int(cost.get(resource_id, 0)) + 1000
		session.overworld["resources"] = resources
		var before: Dictionary = session.to_dict()
		var before_count: int = session.overworld.get("player_heroes", []).size()
		var action_id := "hire_hero:%s" % hero_id
		var matching_actions: Array = TownRules.get_tavern_actions(session).filter(func(row): return row is Dictionary and String(row.get("id", "")) == action_id and not bool(row.get("disabled", true)))
		var hire_result: Dictionary = TownRules.hire_hero_at_active_town(session, hero_id)
		var switch_result: Dictionary = TownRules.switch_active_hero_at_town(session, hero_id)
		var clone = SessionStateStore.new_session_data()
		clone.from_dict(session.to_dict())
		var hired_hero := _hero_by_id(clone.overworld.get("player_heroes", []), hero_id)
		var deltas_exact := true
		for resource_id_value in cost:
			var resource_id := String(resource_id_value)
			deltas_exact = deltas_exact and int(before.get("overworld", {}).get("resources", {}).get(resource_id, 0)) - int(clone.overworld.get("resources", {}).get(resource_id, 0)) == int(cost.get(resource_id, 0))
		var exact: bool = matching_actions.size() == 1 \
			and bool(hire_result.get("ok", false)) \
			and bool(switch_result.get("ok", false)) \
			and clone.overworld.get("player_heroes", []).size() == before_count + 1 \
			and String(clone.overworld.get("active_hero_id", "")) == hero_id \
			and not hired_hero.is_empty() \
			and deltas_exact
		rows.append({"scenario_id": scenario_id, "hero_id": hero_id, "action_id": action_id, "cost": cost, "hire_exact": exact, "save_version": SessionStateStore.SAVE_VERSION})
		if not exact:
			return {"ok": false, "rows": rows, "hire_result": hire_result, "switch_result": switch_result}
	return {"ok": rows.size() == cases.size(), "rows": rows}

func _hero_by_id(heroes: Array, hero_id: String) -> Dictionary:
	for hero_value in heroes:
		if hero_value is Dictionary and String(hero_value.get("id", "")) == hero_id:
			return hero_value
	return {}

func _first_player_town(session) -> Dictionary:
	for town_value in session.overworld.get("towns", []):
		if town_value is Dictionary and String(town_value.get("owner", "")) == "player":
			return town_value
	return {}

func _move_active_hero_to_town(session, town: Dictionary) -> void:
	var position := {"x": int(town.get("x", 0)), "y": int(town.get("y", 0))}
	session.overworld["hero_position"] = position.duplicate(true)
	var hero: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	hero["position"] = position.duplicate(true)
	session.overworld["hero"] = hero
	var heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == String(session.overworld.get("active_hero_id", "")):
			heroes[index] = hero.duplicate(true)
	session.overworld["player_heroes"] = heroes

func _capture_hero_identities(viewport_size: Vector2i) -> bool:
	if OS.get_environment("HERO_IDENTITY_CAPTURE") != "1":
		return true
	await get_tree().process_frame
	await get_tree().process_frame
	var output_dir := "res://.artifacts/hero_identity_sprites"
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	if error != OK and error != ERR_ALREADY_EXISTS:
		return false
	var image := get_viewport().get_texture().get_image()
	if image == null:
		return false
	return image.save_png("%s/hero_identities_%dx%d.png" % [output_dir, viewport_size.x, viewport_size.y]) == OK

func _player_town_footprint_hero_tile(session) -> Vector2i:
	var map_size := OverworldRules.derive_map_size(session)
	for town_value in session.overworld.get("towns", []):
		if town_value is Dictionary and String(town_value.get("owner", "")) == "player":
			var entry := Vector2i(int(town_value.get("x", -1)), int(town_value.get("y", -1)))
			var right_footprint_cell := entry + Vector2i(1, 0)
			return right_footprint_cell if right_footprint_cell.x < map_size.x else entry - Vector2i(1, 0)
	return Vector2i(-1, -1)

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
