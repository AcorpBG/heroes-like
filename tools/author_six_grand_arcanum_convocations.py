#!/usr/bin/env python3
"""Author the six-map Grand Arcanum Convocations content and art batch."""

from __future__ import annotations

import hashlib
import json
import re
from copy import deepcopy
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SLICE_ID = "content-six-grand-arcanum-convocations-10184"
ATLAS_RES = "res://art/overworld/runtime/objects/resource_sites/grand_arcanum_convocations_atlas.png"
SOURCE_DIR = ROOT / "art/overworld/source/generated/resource_sites/grand_arcanum_convocations_wave1"
ATLAS_PATH = ROOT / "art/overworld/runtime/objects/resource_sites/grand_arcanum_convocations_atlas.png"
GENERATED = Path("/root/.codex/generated_images/019fe72a-30b1-76f3-b911-385c4444bd16")

CASES = [
    dict(scenario_id="beaconscribe-dawnwrit-convocation", name="Dawn-Writ Grand Convocation", prefix="dawnwrit", hero="hero_embercourt_jorun_beaconscribe", faction="faction_embercourt", enemy="faction_mireclaw", group="army_dawnwrit_grand_convocation_company", home="town_amberweir_granary", enemy_town="town_moonbite_reedshrine", site="site_dawnwrit_grand_convocation", site_name="Dawn-Writ Column", asset="resource_site_grand_arcanum_dawnwrit_column", source="dawnwrit_column_source.png", generated="exec-45d428fc-d7f9-4b5d-81a1-a110203072f6.png", spells=["spell_beacon_dawn_ward_21","spell_beacon_roadward_charge_23","spell_beacon_bell_lance_25"], units=["unit_embercourt_fordhook_cadets","unit_embercourt_lantern_sappers","unit_embercourt_bargebow_crews","unit_embercourt_amberweir_lockpike_wardens","unit_embercourt_amberweir_sluicebrand_mangonels"], encounters=["encounter_votivejaw_nightglass_bite","encounter_tidehook_reedwake_commission","encounter_gloamchain_sluice_ram"], terrain="grass", rare="site_embergrain_warm_granary", bonus="attack", description="An asymmetric ivory and brass road obelisk carries three signal rings, a forked lantern crown, and a white-gold oath flame."),
    dict(scenario_id="rotlamp-leechmoon-convocation", name="Leechmoon Grand Convocation", prefix="leechmoon", hero="hero_mireclaw_edda_rotlamp", faction="faction_mireclaw", enemy="faction_sunvault", group="army_leechmoon_grand_convocation_company", home="town_moonbite_reedshrine", enemy_town="town_splitprism_duelcourt", site="site_leechmoon_grand_convocation", site_name="Leechmoon Poultice Court", asset="resource_site_grand_arcanum_leechmoon_court", source="leechmoon_poultice_court_source.png", generated="exec-c7c42757-5507-4638-9ab5-961d14d6ed36.png", spells=["spell_mire_leech_poultice_26","spell_mire_flood_rot_28","spell_mire_silt_frenzy_20"], units=["unit_mireclaw_reedsnare_kin","unit_mireclaw_mudglass_slingers","unit_mireclaw_bogplate_maulers","unit_mireclaw_moonbite_votive_drummers","unit_mireclaw_moonbite_mirehorn_breakers"], encounters=["encounter_lenscaptain_reedbarge_survey","encounter_blackgauge_noonwire_commission","encounter_noonglass_orrery_reliquary"], terrain="swamp", rare="site_peatwax_reed_yard", bonus="defense", description="A crescent bogstone court joins a hide drum, crooked reed retort, hanging poultice bowl, and three flood stakes."),
    dict(scenario_id="daynote-aurora-halo-convocation", name="Aurora Halo Grand Convocation", prefix="aurorahalo", hero="hero_sunvault_essa_daynote", faction="faction_sunvault", enemy="faction_brasshollow", group="army_aurora_halo_grand_convocation_company", home="town_splitprism_duelcourt", enemy_town="town_whitegauge_calibration_yard", site="site_aurora_halo_grand_convocation", site_name="Aurora Halo Array", asset="resource_site_grand_arcanum_aurora_halo_array", source="aurora_halo_array_source.png", generated="exec-f1a36a70-746e-4235-a5c7-c87b94d045b9.png", spells=["spell_lens_aurora_array_26","spell_lens_halo_ray_18","spell_lens_aurora_chorus_10"], units=["unit_sunvault_shard_wardens","unit_sunvault_prism_adepts","unit_sunvault_mirror_duelists","unit_sunvault_splitprism_parallax_fencers","unit_sunvault_splitprism_heliograph_ballistae"], encounters=["encounter_horizon_court_blackbell_quenchline_assize","encounter_pitmarshal_red_chain_assize","encounter_debtrune_lastbell_audit"], terrain="sand", rare="site_aetherglass_lens_house", bonus="knowledge", description="An offset oval lens turns inside three unequal halo rails beneath a prism vane and glass calibration needles."),
    dict(scenario_id="graftsibyl-loambriar-convocation", name="Loam-Briar Grand Convocation", prefix="loambriar", hero="hero_thornwake_nara_graftsibyl", faction="faction_thornwake", enemy="faction_embercourt", group="army_loambriar_grand_convocation_company", home="town_woundroot_hearthgrove", enemy_town="town_amberweir_granary", site="site_loambriar_grand_convocation", site_name="Loam-Briar Graft Loom", asset="resource_site_grand_arcanum_loambriar_loom", source="loambriar_graft_loom_source.png", generated="exec-9f2bbe86-af9a-4522-8d01-1180f7fafdfa.png", spells=["spell_root_loam_bloom_26","spell_root_green_briar_28","spell_root_bloom_bark_20"], units=["unit_thornwake_seedcutters","unit_thornwake_thornwhip_carriers","unit_thornwake_sporeglass_menders","unit_thornwake_woundroot_hearthseed_slingers","unit_thornwake_woundroot_rootmaul_behemoths"], encounters=["encounter_horizon_court_rainwrit_tidewrit_assize","encounter_tollbrand_sluice_levy","encounter_rainwrit_charter_watch"], terrain="grass", rare="site_verdant_graft_nursery", bonus="defense", description="A living root arch supports a graft spool, thorn stake, bloom lamp, and three unequal bough forks."),
    dict(scenario_id="heatpriest-ashrail-convocation", name="Ash-Rail Grand Convocation", prefix="ashrail", hero="hero_brasshollow_odrik_heatpriest", faction="faction_brasshollow", enemy="faction_veilmourn", group="army_ashrail_grand_convocation_company", home="town_whitegauge_calibration_yard", enemy_town="town_dreamwake_oracle_harbor", site="site_ashrail_grand_convocation", site_name="Ash-Rail Clause Forge", asset="resource_site_grand_arcanum_ashrail_forge", source="ashrail_clause_forge_source.png", generated="exec-fe4cf842-a77f-4025-8018-c77250097d88.png", spells=["spell_furnace_rivet_mantle_21","spell_furnace_brass_bellows_23","spell_furnace_ash_rail_25"], units=["unit_brasshollow_scrip_haulers","unit_brasshollow_rivet_hounds","unit_brasshollow_furnace_pavis_teams","unit_brasshollow_whitegauge_datum_lancers","unit_brasshollow_whitegauge_datum_breach_cannons"], encounters=["encounter_vowless_drowned_requiem","encounter_powderwrit_fogchain_commission","encounter_vanehook_named_rival_company"], terrain="dirt", rare="site_brass_scrip_mint", bonus="power", description="A squat basalt and brass forge carries a diagonal hammer rail, riveted mantle, three clamp jaws, and a red pressure gauge."),
    dict(scenario_id="vowless-mistmourning-convocation", name="Mist-Mourning Grand Convocation", prefix="mistmourning", hero="hero_veilmourn_nacre_vowless", faction="faction_veilmourn", enemy="faction_thornwake", group="army_mistmourning_grand_convocation_company", home="town_dreamwake_oracle_harbor", enemy_town="town_woundroot_hearthgrove", site="site_mistmourning_grand_convocation", site_name="Mist-Mourning Drift Archive", asset="resource_site_grand_arcanum_mistmourning_archive", source="mistmourning_drift_archive_source.png", generated="exec-60bbeb21-25a5-4155-a179-0d6cea520e77.png", spells=["spell_veil_mist_duel_26","spell_veil_moon_mark_28","spell_veil_mourning_fogbind_20"], units=["unit_veilmourn_bellwake_oars","unit_veilmourn_mourning_lanterns","unit_veilmourn_maskglass_corsairs","unit_veilmourn_dreamwake_tideglass_oracles","unit_veilmourn_dreamwake_foganchor_colossi"], encounters=["encounter_crownroot_seedglass_trial","encounter_pollenhook_whistle_line","encounter_thorncart_pilgrim_cordon"], terrain="snow", rare="site_memory_salt_pan", bonus="knowledge", description="A tilted whalebone crescent bears shroud sails, a drowned lantern mask, tide marker, and three memory chimes."),
]


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def save(path: Path, payload) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.name == "scenarios.json":
        text = json.dumps(payload, ensure_ascii=False, separators=(",", ":"))
    else:
        text = json.dumps(payload, indent=2, ensure_ascii=False)
        if path.name == "army_groups.json":
            text = re.sub(r'        \{\n          "unit_id": ("[^"]+"),\n          "count": (\d+)\n        \}', r'        {"unit_id": \1, "count": \2}', text)
    path.write_text(text + "\n", encoding="utf-8")


def replace_batch(items: list, additions: list) -> None:
    ids = {row["id"] for row in additions}
    items[:] = [row for row in items if row.get("id") not in ids]
    items.extend(additions)


def make_art() -> tuple[list[dict], str]:
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    tiles = []
    rows = []
    for index, case in enumerate(CASES):
        original = Image.open(GENERATED / case["generated"]).convert("RGBA")
        alpha = original.getchannel("A")
        bbox = alpha.getbbox()
        if bbox:
            original = original.crop(bbox)
        original.thumbnail((470, 470), Image.Resampling.LANCZOS)
        master = Image.new("RGBA", (512, 512))
        master.alpha_composite(original, ((512-original.width)//2, (512-original.height)//2))
        source_path = SOURCE_DIR / case["source"]
        master.save(source_path, optimize=True)
        tile = master.resize((48, 48), Image.Resampling.LANCZOS)
        tiles.append(tile)
        rows.append({"site_id":case["site"], "asset_id":case["asset"], "source_file":case["source"], "source_sha256":hashlib.sha256(source_path.read_bytes()).hexdigest(), "atlas_region":[index*48,0,48,48], "prompt":case["description"]})
    atlas = Image.new("RGBA", (288, 48))
    for index, tile in enumerate(tiles):
        atlas.alpha_composite(tile, (index*48, 0))
    ATLAS_PATH.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(ATLAS_PATH, optimize=True)
    atlas_sha = hashlib.sha256(ATLAS_PATH.read_bytes()).hexdigest()
    save(SOURCE_DIR / "manifest.json", {"content_batch_id":SLICE_ID,"source_model":"built_in_image_gen_original_grand_arcanum_convocations_atlas","generation_mode":"built_in_image_gen","runtime_atlas":ATLAS_RES,"runtime_atlas_size":[288,48],"runtime_atlas_sha256":atlas_sha,"items":rows})
    return rows, atlas_sha


def make_group(case: dict) -> dict:
    return {"id":case["group"],"name":case["name"]+" Company","faction_id":case["faction"],"stacks":[{"unit_id":unit,"count":count} for unit,count in zip(case["units"],[54,32,20,10,4])],"content_batch_id":SLICE_ID}


def make_scenario(case: dict, index: int) -> dict:
    p = case["prefix"]
    terrain = [[case["terrain"] for _ in range(18)] for _ in range(12)]
    # A continuous central road gives each large map an immediately readable eastward campaign line.
    for x in range(18):
        terrain[6][x] = "dirt"
    resources = [
        ("wood_one","site_wood_wagon",2,2),("ore_one","site_ore_crates",4,9),("gold_one","site_payroll_casket",7,2),
        ("rare_one",case["rare"],9,9),("wood_two","site_wood_wagon",11,2),("ore_two","site_ore_crates",13,9),
        ("exchange","site_frontier_rare_exchange",15,2),("gold_two","site_payroll_casket",16,9),("academy",case["site"],14,8),
    ]
    victory = ([{"id":f"{p}_clear_front_{i+1}","label":f"Clear convocation front {i+1}","type":"encounter_resolved","placement_id":f"{p}_front_{i+1}"} for i in range(3)] +
        [{"id":f"{p}_learn_{i+1}","label":f"Learn {spell.replace('spell_','').replace('_',' ').title()}","type":"spell_known_by_player","spell_id":spell} for i,spell in enumerate(case["spells"])] +
        [{"id":f"{p}_claim_academy","label":f"Claim {case['site_name']}","type":"flag_true","flag":f"{p}_grand_convocation_claimed"},
         {"id":f"{p}_take_rival_town","label":"Take the rival convocation town","type":"town_owned_by_player","placement_id":f"{p}_enemy"}])
    return {
      "id":case["scenario_id"],"name":case["name"],
      "selection":{"summary":f"Lead {case['site_name']} across a large three-front spellwright road, master three new disciplines, and capture the rival town.","recommended_difficulty":"hard","map_size_label":"Grand Arcanum Convocation (18x12)","player_summary":"A five-stack signature company begins at one home town with three fronts and a guarded academy ahead.","enemy_summary":"A rival town feeds sustained pressure across the full eastward road.","availability":{"campaign":False,"skirmish":True}},
      "map_size":{"width":18,"height":12},"player_faction_id":case["faction"],"player_army_id":case["group"],"hero_id":case["hero"],
      "starting_resources":{"gold":11500,"wood":16,"ore":16,"embergrain":4,"moonwax":4,"sunglass":4,"heartseed":4,"brass_scrip":4,"tideglass":4},
      "map":terrain,"start":{"x":1,"y":6},"hero_starts":[case["hero"]],
      "objectives":{"victory_text":"Master all three Grand Arcanum lessons, clear the three field fronts, claim the academy, and take the rival town.","defeat_text":"The home town, commander, road pressure, or Day 23 deadline ends the convocation.","victory":victory,"defeat":[{"id":f"{p}_lose_home","label":"The home town must stand","type":"town_not_owned_by_player","placement_id":f"{p}_home"},{"id":f"{p}_lose_hero","label":"The spellwright must survive","type":"session_flag_equals","flag":"campaign","value":"defeat"},{"id":f"{p}_pressure","label":"Keep rival pressure below 34","type":"enemy_pressure_at_least","faction_id":case["enemy"],"threshold":34},{"id":f"{p}_deadline","label":"Finish before Day 23","type":"day_at_least","day":23}]},
      "script_hooks":[
        {"id":f"{p}_opening_stores","priority":130,"conditions":[{"type":"objective_met","objective_id":f"{p}_clear_front_1"}],"effects":[{"type":"add_resources","resources":{"gold":650,"wood":2,"ore":2}},{"type":"message","text":"The opening front yields its convocation stores."}]},
        {"id":f"{p}_second_front_recruits","priority":120,"conditions":[{"type":"objective_met","objective_id":f"{p}_clear_front_2"}],"effects":[{"type":"town_add_recruits","placement_id":f"{p}_home","recruits":{case["units"][3]:2,case["units"][1]:5}},{"type":"message","text":"The home town answers the second victory with signature reserves."}]},
        {"id":f"{p}_day_two_muster","priority":110,"conditions":[{"type":"day_at_least","day":2},{"type":"town_owned_by_player","placement_id":f"{p}_home"}],"effects":[{"type":"town_add_recruits","placement_id":f"{p}_home","recruits":{case["units"][0]:8}},{"type":"message","text":"Fresh lower-rank recruits gather behind the spellwright."}]},
        {"id":f"{p}_day_ten_reserve","priority":80,"conditions":[{"type":"day_at_least","day":10},{"type":"objective_not_met","objective_id":f"{p}_clear_front_3"}],"effects":[{"type":"spawn_encounter","placement":{"placement_id":f"{p}_late_reserve","encounter_id":case["encounters"][1],"x":16,"y":10,"difficulty":"high","spawned_by_faction_id":case["enemy"],"days_active":0,"arrived":False,"goal_distance":9999}},{"type":"message","text":"A rival reserve enters the far road."}]},
        {"id":f"{p}_late_pressure","priority":70,"conditions":[{"type":"day_at_least","day":14},{"type":"objective_not_met","objective_id":f"{p}_take_rival_town"}],"effects":[{"type":"add_enemy_pressure","faction_id":case["enemy"],"amount":3},{"type":"message","text":"The rival town intensifies pressure on the unfinished convocation."}]},
      ],
      "towns":[{"placement_id":f"{p}_home","town_id":case["home"],"x":0,"y":6,"owner":"player","recovery":{"pressure":2,"source":"grand convocation home"}},{"placement_id":f"{p}_enemy","town_id":case["enemy_town"],"x":17,"y":6,"owner":"enemy"}],
      "enemy_factions":[{"faction_id":case["enemy"],"label":"Rival Grand Convocation","pressure_per_day":1,"pressure_per_enemy_town":1,"raid_threshold":12,"max_active_raids":1,"raid_pillage_delay":3,"raid_pillage":{"gold":300},"raid_encounter_ids":[case["encounters"][0]],"spawn_points":[{"x":17,"y":1}],"siege_target_placement_id":f"{p}_home","siege_active_raid_threshold":2,"siege_capture_progress":2,"priority_target_placement_ids":[f"{p}_home"]}],
      "resource_nodes":[{"placement_id":f"{p}_{label}","site_id":site,"x":x,"y":y} for label,site,x,y in resources],"artifact_nodes":[],
      "encounters":[{"placement_id":f"{p}_front_{i+1}","encounter_id":encounter,"x":x,"y":y,"difficulty":["medium","high","high"][i],"combat_seed":47100+index*10+i,"prefer_identity_landmark":True,"guardian_role":["grand_convocation_vanguard","grand_convocation_field_examiner","grand_convocation_academy_guard"][i]} for i,(encounter,x,y) in enumerate(zip(case["encounters"],[5,10,13],[3,6,8]))],
      "content_batch_id":SLICE_ID,
    }


def main() -> None:
    rows, atlas_sha = make_art()
    scenarios_path = ROOT / "content/scenarios.json"
    scenarios = load(scenarios_path)
    replace_batch(scenarios["items"], [make_scenario(case, i) for i, case in enumerate(CASES)])
    scenarios["player_facing_active_scenario_count"] = len(scenarios["items"])
    save(scenarios_path, scenarios)

    groups_path = ROOT / "content/army_groups.json"
    groups = load(groups_path)
    replace_batch(groups["items"], [make_group(case) for case in CASES])
    save(groups_path, groups)

    sites_path = ROOT / "content/resource_sites.json"
    sites = load(sites_path)
    additions = []
    for case in CASES:
        additions.append({"id":case["site"],"name":case["site_name"],"family":"shrine","action_label":"Convene the Three Grand Lessons","summary":case["description"],"claim_rewards":{"experience":240},"hero_command_bonus":{case["bonus"]:1},"learn_spell_id":case["spells"][0],"learn_spell_ids":case["spells"],"claim_flags":{f"{case['prefix']}_grand_convocation_claimed":True},"runtime_boundary":{"status":"triune_arcanum_live","live_reward_grants":True,"save_payload_required":True,"renderer_sprite_required":True,"pathing_runtime_adopted":True,"route_effect_runtime_adopted":False,"rare_resource_activation":False,"scenario_placement_migration":True},"content_batch_id":SLICE_ID,"public_text":{"public_summary":case["description"],"no_internal_debug_score_fields":True,"large_text_panel_required":False}})
    replace_batch(sites["items"], additions)
    save(sites_path, sites)

    manifest_path = ROOT / "art/overworld/manifest.json"
    manifest = load(manifest_path)
    assets = manifest["object_assets"]
    sprites = manifest["resource_site_sprites"]
    for index, case in enumerate(CASES):
        assets[case["asset"]] = {"path":ATLAS_RES,"atlas_region":[index*48,0,48,48],"atlas_size":[288,48],"source_trimmed":f"res://art/overworld/source/generated/resource_sites/grand_arcanum_convocations_wave1/{case['source']}","source_generated":f"res://art/overworld/source/generated/resource_sites/grand_arcanum_convocations_wave1/{case['source']}","source_model":"built_in_image_gen_original_grand_arcanum_convocations_atlas","assigned_resource_site_id":case["site"],"presentation_role":"grand_arcanum_field_academy","accessible_description":case["description"],"background":"transparent"}
        sprites[case["site"]] = {"asset_id":case["asset"],"unclaimed_asset_id":case["asset"],"fit":f"Exact original {case['site_name']} remains visible before and after its three-spell lesson."}
    save(manifest_path, manifest)
    print(json.dumps({"slice":SLICE_ID,"scenarios":len(scenarios["items"]),"groups":len(groups["items"]),"sites":len(sites["items"]),"atlas_sha256":atlas_sha}, indent=2))


if __name__ == "__main__":
    main()
