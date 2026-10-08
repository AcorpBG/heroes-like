#!/usr/bin/env python3
"""Author ten large commander dominion sieges and their landmark art."""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image

import author_eight_commanders_proving_roads as base


ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / "content"
SOURCE_ROOT = ROOT / "art/overworld/source/generated/resource_sites/commander_dominion_sieges_wave1"
ATLAS_PATH = ROOT / "art/overworld/runtime/objects/resource_sites/commander_dominion_sieges_atlas.png"
ATLAS_RES = "res://art/overworld/runtime/objects/resource_sites/commander_dominion_sieges_atlas.png"
SOURCE_RES = "res://art/overworld/source/generated/resource_sites/commander_dominion_sieges_wave1"
ART_MANIFEST = ROOT / "art/overworld/manifest.json"
SLICE_ID = "content-ten-commander-dominion-sieges-10184"
GENERATOR_ROOT = Path("/root/.codex/generated_images/019fe72a-30b1-76f3-b911-385c4444bd16")


COMMANDERS = {
    "vellum": {
        "faction_id": "faction_brasshollow", "rare_site_id": "site_brass_scrip_mint", "rare_resource": "brass_scrip", "terrain": ("rough", "lava"),
        "stacks": [("unit_brasshollow_tallyspring_throwers", 100), ("unit_brasshollow_quenchspool_slingers", 70), ("unit_brasshollow_gaugefire_arbalists", 45), ("unit_brasshollow_quenchbell_mortars", 28), ("unit_brasshollow_crucible_crawlers", 18)],
        "claim_units": ["unit_brasshollow_quenchbell_mortars", "unit_brasshollow_crucible_crawlers"],
        "encounters": ["encounter_sluice_raiders", "encounter_vellum_gorefen_audit", "encounter_selka_peat_chain_levy", "encounter_debtrune_default_collectors", "encounter_horizon_blackbell_verdict_gantry"],
    },
    "orrik": {
        "faction_id": "faction_mireclaw", "rare_site_id": "site_peatwax_reed_yard", "rare_resource": "peatwax", "terrain": ("mire", "swamp"),
        "stacks": [("unit_mireclaw_moonbite_votive_drummers", 80), ("unit_mireclaw_fenbell_chainstalkers", 50), ("unit_mireclaw_gorefen_rippers", 30), ("unit_mireclaw_moonbite_mirehorn_breakers", 20), ("unit_mireclaw_drowned_antler_sovereign", 10)],
        "claim_units": ["unit_mireclaw_fenbell_chainstalkers", "unit_mireclaw_moonbite_mirehorn_breakers"],
        "encounters": ["encounter_votivejaw_nightglass_bite", "encounter_tollmoon_named_rival_company", "encounter_three_banner_fenbell_chainstalkers", "encounter_muckscript_prism_inquest", "encounter_mireglass_bellbasin_watch"],
    },
    "thir": {
        "faction_id": "faction_veilmourn", "rare_site_id": "site_memory_salt_pan", "rare_resource": "memory_salt", "terrain": ("snow", "mire"),
        "stacks": [("unit_veilmourn_saltbell_casters", 100), ("unit_veilmourn_gloamkeel_bulwarks", 55), ("unit_veilmourn_saltwake_eulogists", 32), ("unit_veilmourn_dreamwake_foganchor_colossi", 18), ("unit_veilmourn_fogbound_leviathan", 8)],
        "claim_units": ["unit_veilmourn_saltwake_eulogists", "unit_veilmourn_dreamwake_foganchor_colossi"],
        "encounters": ["encounter_rotlamp_spoor_court", "encounter_nightchart_false_meridian", "encounter_pale_saltwake_recital", "encounter_gloamkeel_sounding_barricade", "encounter_rimebell_whitewake_watch"],
    },
    "zhorra": {
        "faction_id": "faction_mireclaw", "rare_site_id": "site_peatwax_reed_yard", "rare_resource": "peatwax", "terrain": ("mire", "forest"),
        "stacks": [("unit_mireclaw_moonbite_votive_drummers", 80), ("unit_mireclaw_fenbell_chainstalkers", 50), ("unit_mireclaw_gorefen_rippers", 30), ("unit_mireclaw_moonbite_mirehorn_breakers", 20), ("unit_mireclaw_drowned_antler_sovereign", 10)],
        "claim_units": ["unit_mireclaw_fenbell_chainstalkers", "unit_mireclaw_moonbite_mirehorn_breakers"],
        "encounters": ["encounter_horizon_hollowreed_moonfang_palisade", "encounter_fenwake_crown_drum_verdict", "encounter_chainboom_daybreak_snare", "encounter_willow_mill_pack", "encounter_gate_marshals"],
    },
    "mirro": {
        "faction_id": "faction_sunvault", "rare_site_id": "site_aetherglass_lens_house", "rare_resource": "aetherglass", "terrain": ("sand", "grass"),
        "stacks": [("unit_aurora_ballista", 70), ("unit_sunvault_splitprism_parallax_fencers", 45), ("unit_sunvault_zenith_lensbearers", 30), ("unit_sunvault_splitprism_heliograph_ballistae", 18), ("unit_sunvault_aurora_ballistae", 12)],
        "claim_units": ["unit_sunvault_splitprism_parallax_fencers", "unit_sunvault_splitprism_heliograph_ballistae"],
        "encounters": ["encounter_seedseer_kite_root_omen", "encounter_horizon_meridian_choir_array", "encounter_three_banner_zenith_lensbearers", "encounter_galehorn_breakline_watch", "encounter_daybreak_array"],
    },
}


CASES = [
    {"key":"vellum","prefix":"quenchline","scenario_id":"vellum-quenchline-dominion-siege","scenario_name":"Vellum Quenchline Dominion Siege","hero_id":"hero_brasshollow_vellum_quench","home_town_id":"town_whitegauge_calibration_yard","forward_town_id":"town_brasshollow_clauseworks_depot","enemy_town_id":"town_woundroot_hearthgrove","enemy_faction_id":"faction_thornwake","enemy_label":"Woundroot Counterweight Host","site_id":"site_quench_cantilever_breach_gauge","site_name":"Quench-Cantilever Breach Gauge","asset_id":"resource_site_dominion_quench_cantilever_gauge","source_name":"quench_cantilever_breach_gauge_source.png","generation_original":"exec-74fc1caf-f7bc-4411-96a6-034dc204e4f2.png","action_label":"Set the Breach Gauge","seed":55500,"width":22,"height":14,"description":"A squat black-iron cantilever spans a molten quench basin beneath nested gauges, a cracked bell, hooked counterweight, and four riveted feet."},
    {"key":"vellum","prefix":"counterweight","scenario_id":"vellum-counterweight-verdict","scenario_name":"Vellum Counterweight Verdict","hero_id":"hero_brasshollow_vellum_quench","home_town_id":"town_whitegauge_calibration_yard","forward_town_id":"town_brasshollow_clauseworks_depot","enemy_town_id":"town_woundroot_hearthgrove","enemy_faction_id":"faction_thornwake","enemy_label":"Woundroot Seizure Court","site_id":"site_counterweight_verdict_press","site_name":"Counterweight Verdict Press","asset_id":"resource_site_dominion_counterweight_verdict_press","source_name":"counterweight_verdict_press_source.png","generation_original":"exec-6821c83a-67c6-49b3-8d95-cae588b1edb2.png","action_label":"Stamp the Counterweight Verdict","seed":55600,"width":22,"height":16,"description":"A tall asymmetric stamp press carries a broad blank brass plate, three unequal counterweights, steam vent, toothed flywheel, and split iron base."},
    {"key":"orrik","prefix":"blackwake","scenario_id":"orrik-blackwake-toll-siege","scenario_name":"Orrik Blackwake Toll Siege","hero_id":"hero_orrik","home_town_id":"town_moonbite_reedshrine","forward_town_id":"town_reedbarrow_ferry","enemy_town_id":"town_amberweir_granary","enemy_faction_id":"faction_embercourt","enemy_label":"Amberweir Tollbreak Levy","site_id":"site_blackwake_toll_tusk_standard","site_name":"Blackwake Toll-Tusk Standard","asset_id":"resource_site_dominion_blackwake_toll_tusk","source_name":"blackwake_toll_tusk_standard_source.png","generation_original":"exec-c6249bba-f2c1-41b8-95ae-d647c6dd54cf.png","action_label":"Ring the Toll-Tusk","seed":55700,"width":22,"height":14,"description":"A curved antler-and-reed toll arch carries a huge ivory tusk bell, heavy chain, blackwater lantern, three tally hooks, and muddy stone feet."},
    {"key":"orrik","prefix":"moonchain","scenario_id":"orrik-moonchain-verdict","scenario_name":"Orrik Moonchain Verdict","hero_id":"hero_orrik","home_town_id":"town_moonbite_reedshrine","forward_town_id":"town_reedbarrow_ferry","enemy_town_id":"town_amberweir_granary","enemy_faction_id":"faction_embercourt","enemy_label":"Amberweir Reclamation Host","site_id":"site_moonchain_raid_ledger","site_name":"Moonchain Raid Ledger","asset_id":"resource_site_dominion_moonchain_raid_ledger","source_name":"moonchain_raid_ledger_source.png","generation_original":"exec-558abab2-5c22-4ef7-a225-321018db3c7d.png","action_label":"Close the Raid Ledger","seed":55800,"width":22,"height":16,"description":"A low hide-drum command desk carries a chain-bead abacus, three blank wax tally leaves, crescent reed pennant, ferry weight, and root tripod."},
    {"key":"thir","prefix":"lastmargin","scenario_id":"thir-last-margin-siege","scenario_name":"Thir Last-Margin Siege","hero_id":"hero_veilmourn_thir_obituaryink","home_town_id":"town_dreamwake_oracle_harbor","forward_town_id":"town_pale_sounding_harbor","enemy_town_id":"town_cinderlock_bastion","enemy_faction_id":"faction_embercourt","enemy_label":"Cinderlock Margin Burners","site_id":"site_last_margin_eulogy_mast","site_name":"Last-Margin Eulogy Mast","asset_id":"resource_site_dominion_last_margin_mast","source_name":"last_margin_eulogy_mast_source.png","generation_original":"exec-d09ffd90-ef94-4fba-8a5f-a2f4a5f4416b.png","action_label":"Raise the Last Margin","seed":55900,"width":22,"height":14,"description":"An ink-black sail mast carries a broad blank hanging scroll, clapperless salt bell, three white quill vanes, anchor hook, and bone feet."},
    {"key":"thir","prefix":"drownedname","scenario_id":"thir-drowned-name-verdict","scenario_name":"Thir Drowned-Name Verdict","hero_id":"hero_veilmourn_thir_obituaryink","home_town_id":"town_dreamwake_oracle_harbor","forward_town_id":"town_pale_sounding_harbor","enemy_town_id":"town_cinderlock_bastion","enemy_faction_id":"faction_embercourt","enemy_label":"Cinderlock Archive Ward","site_id":"site_drowned_name_archive","site_name":"Drowned Name Archive","asset_id":"resource_site_dominion_drowned_name_archive","source_name":"drowned_name_archive_source.png","generation_original":"exec-97afd1a9-fa0b-4e09-8d2c-7f8d5fca3ebe.png","action_label":"Open the Drowned Archive","seed":56000,"width":22,"height":16,"description":"A ribbed ship-cabinet reliquary holds blank tideglass tablets, a half-submerged sounding bell, rope drawers, pale lantern, and keel base."},
    {"key":"zhorra","prefix":"crowndrum","scenario_id":"zhorra-crown-drum-siege","scenario_name":"Zhorra Crown-Drum Siege","hero_id":"hero_mireclaw_zhorra_fenwake","home_town_id":"town_hollowreed_sanctuary","forward_town_id":"town_nightglass_redoubt","enemy_town_id":"town_crownroot_refuge","enemy_faction_id":"faction_thornwake","enemy_label":"Crownroot Root-Jury","site_id":"site_crown_drum_verdict_dais","site_name":"Crown-Drum Verdict Dais","asset_id":"resource_site_dominion_crown_drum_dais","source_name":"crown_drum_verdict_dais_source.png","generation_original":"exec-aadd5cb8-3298-4570-8072-13b5bbfa94fe.png","action_label":"Beat the Crown Verdict","seed":56100,"width":22,"height":14,"description":"A gnarled root-and-antler dais supports a huge hide verdict drum, reed-tooth crown, three bone beaters, hanging moon seals, and clawed feet."},
    {"key":"zhorra","prefix":"undertow","scenario_id":"zhorra-undertow-verdict","scenario_name":"Zhorra Undertow Verdict","hero_id":"hero_mireclaw_zhorra_fenwake","home_town_id":"town_hollowreed_sanctuary","forward_town_id":"town_nightglass_redoubt","enemy_town_id":"town_crownroot_refuge","enemy_faction_id":"faction_thornwake","enemy_label":"Crownroot Undertow Court","site_id":"site_fenwake_undertow_beacon","site_name":"Fenwake Undertow Beacon","asset_id":"resource_site_dominion_fenwake_undertow_beacon","source_name":"fenwake_undertow_beacon_source.png","generation_original":"exec-f6bfdd99-8d35-4bfa-8676-f84c5d8b190d.png","action_label":"Light the Undertow Beacon","seed":56200,"width":22,"height":16,"description":"A crooked reed beacon carries a spiral wake fan, drowned-blue flame cage, hanging bone plumbs, crescent hook, and root-and-mud base."},
    {"key":"mirro","prefix":"nineray","scenario_id":"mirro-nine-ray-siege","scenario_name":"Mirro Nine-Ray Siege","hero_id":"hero_sunvault_mirro_halometer","home_town_id":"town_splitprism_duelcourt","forward_town_id":"town_halo_spire","enemy_town_id":"town_cindercoil_foundry","enemy_faction_id":"faction_brasshollow","enemy_label":"Cindercoil Rangebreakers","site_id":"site_nine_ray_halo_range","site_name":"Nine-Ray Halo Range","asset_id":"resource_site_dominion_nine_ray_halo_range","source_name":"nine_ray_halo_range_source.png","generation_original":"exec-2cb8a7f6-ac06-4682-a8b2-24ddf5b7f966.png","action_label":"Sight the Nine Rays","seed":56300,"width":22,"height":14,"description":"An asymmetric ivory survey instrument carries nine unequal prism rays, a huge oval lens, diagonal sighting rod, crystal plumbs, and forked tripod."},
    {"key":"mirro","prefix":"shadowdial","scenario_id":"mirro-meridian-shadow-verdict","scenario_name":"Mirro Meridian-Shadow Verdict","hero_id":"hero_sunvault_mirro_halometer","home_town_id":"town_splitprism_duelcourt","forward_town_id":"town_halo_spire","enemy_town_id":"town_cindercoil_foundry","enemy_faction_id":"faction_brasshollow","enemy_label":"Cindercoil Shadow Court","site_id":"site_meridian_shadow_dial","site_name":"Meridian Shadow Dial","asset_id":"resource_site_dominion_meridian_shadow_dial","source_name":"meridian_shadow_dial_source.png","generation_original":"exec-57cc5f25-b0d9-46f8-aa67-b2961ec67645.png","action_label":"Set the Meridian Shadow","seed":56400,"width":22,"height":16,"description":"A tall faceted sundial carries two offset floating rings, a black prism shadow blade, diamond lens, calibrated arc, and stepped ivory base."},
]


def terrain_map(primary: str, secondary: str, seed: int, width: int, height: int) -> list[list[str]]:
    return [[secondary if (x * 5 + y * 13 + seed) % 23 in (0, 1, 2, 3, 4) else primary for x in range(width)] for y in range(height)]


def prompt_for(case: dict) -> str:
    return f"Use case: stylized-concept; Asset type: production 2D fantasy strategy-game overworld siege-command landmark source; Primary request: Create {case['site_name']} for the original Aurelion Reach setting; Scene/backdrop: genuinely transparent alpha background; Subject and readable identity: {case['description']}; Style/medium: polished hand-painted original fantasy game landmark art; Composition/framing: isolated high three-quarter view, centered with generous padding, strong asymmetric non-color silhouette readable at 48x48; Constraints: one object only; preserved alpha; no ground, scenery, characters, creatures, text, letters, numbers, logos, watermark, border, frame, cast shadow, or copied franchise design."


def render_art() -> tuple[str, list[dict]]:
    ATLAS_PATH.parent.mkdir(parents=True, exist_ok=True)
    atlas = Image.new("RGBA", (480, 48), (0, 0, 0, 0))
    rows = []
    for index, case in enumerate(CASES):
        source = SOURCE_ROOT / case["source_name"]
        atlas.alpha_composite(base.transparent_frame(source), (index * 48, 0))
        rows.append({"site_id":case["site_id"], "hero_id":case["hero_id"], "asset_id":case["asset_id"], "source_path":f"{SOURCE_RES}/{case['source_name']}", "source_sha256":base.sha256(source), "generation_original":str(GENERATOR_ROOT / case["generation_original"]), "atlas_region":[index * 48,0,48,48], "prompt":prompt_for(case), "accessible_description":case["description"]})
    atlas.save(ATLAS_PATH, optimize=True, compress_level=9)
    atlas_sha = base.sha256(ATLAS_PATH)
    base.write_pretty(SOURCE_ROOT / "manifest.json", {"schema_id":"ten_commander_dominion_sieges_art_v1", "content_batch_id":SLICE_ID, "generation_mode":"built_in_imagegen", "source_model":"built_in_imagegen_original_commander_dominion_sieges_atlas", "prompt_set_summary":"Ten transparent original siege-command landmarks paired to the five remaining direct-lead-floor heroes, with deliberately distinct 48px silhouettes.", "runtime_atlas":ATLAS_RES, "runtime_atlas_size":[480,48], "runtime_atlas_sha256":atlas_sha, "source_package_policy":"retained_for_provenance_excluded_from_linux_and_windows_exports", "items":rows})
    return atlas_sha, rows


def scenario_record(case: dict, hero_name: str, army_id: str) -> dict:
    commander = COMMANDERS[case["key"]]
    prefix, width, height = case["prefix"], case["width"], case["height"]
    stacks, encounters = commander["stacks"], commander["encounters"]
    coords = [(5,2), (7,height-3), (10,4), (14,height-4), (18,3)]
    fronts = [{"placement_id":f"{prefix}_front_{i}", "encounter_id":encounter_id, "x":xy[0], "y":xy[1], "difficulty":"medium", "combat_seed":case["seed"]+i, "prefer_identity_landmark":True, "guardian_role":"commander_dominion_siege_front"} for i, (encounter_id, xy) in enumerate(zip(encounters, coords), start=1)]
    victory = [
        {"id":f"{prefix}_hold_company", "label":f"Keep both {hero_name} siege companies in the host", "type":"hero_army_meets_requirements", "hero_id":case["hero_id"], "requirements":[{"unit_id":unit_id,"minimum_count":1} for unit_id in commander["claim_units"]]},
        {"id":f"{prefix}_claim_command", "label":f"Claim {case['site_name']}", "type":"flag_true", "flag":f"{prefix}_dominion_command_claimed"},
    ]
    victory.extend({"id":f"{prefix}_clear_front_{i}", "label":f"Resolve dominion front {i}", "type":"encounter_resolved", "placement_id":f"{prefix}_front_{i}"} for i in range(1,6))
    victory.append({"id":f"{prefix}_capture_enemy", "label":"Capture the hostile dominion seat", "type":"town_owned_by_player", "placement_id":f"{prefix}_enemy_town"})
    middle_y, last_y = height // 2, height - 1
    node_specs = [("wood_nw","site_wood_wagon",1,0), ("ore_nw","site_ore_crates",4,0), ("rare_n",commander["rare_site_id"],8,0), ("exchange_n","site_frontier_rare_exchange",13,0), ("waystone_n","site_waystone_cache",18,0), ("ore_ne","site_ore_crates",21,0), ("wood_sw","site_wood_wagon",2,last_y), ("ore_sw","site_ore_crates",6,last_y), ("rare_s",commander["rare_site_id"],10,last_y), ("exchange_s","site_frontier_rare_exchange",15,last_y), ("mid_cache","site_waystone_cache",11,middle_y), ("landmark",case["site_id"],19,middle_y)]
    if height == 16:
        node_specs.extend([("waystone_s","site_waystone_cache",18,last_y), ("wood_se","site_wood_wagon",21,last_y)])
    nodes = [{"placement_id":f"{prefix}_{name}", "site_id":site_id, "x":x, "y":y, **({"guard_front_id":f"{prefix}_front_5"} if name == "landmark" else {})} for name, site_id, x, y in node_specs]
    deadline = 26 if height == 14 else 30
    return {
        "id":case["scenario_id"], "name":case["scenario_name"],
        "selection":{"summary":f"Lead {hero_name}'s five-stack host through five battle fronts, claim {case['site_name']}, and capture the hostile seat before Day {deadline}.", "recommended_difficulty":"normal", "map_size_label":f"Dominion Siege ({width}x{height})", "player_summary":f"{hero_name} commands a complete siege company through two friendly strongpoints.", "enemy_summary":f"{case['enemy_label']} hold five fronts, a hostile town, and a late reserve.", "availability":{"campaign":False,"skirmish":True}},
        "map_size":{"width":width,"height":height}, "player_faction_id":commander["faction_id"], "player_army_id":army_id, "hero_id":case["hero_id"],
        "starting_resources":{"gold":15000,"wood":20,"ore":20,"embergrain":5,"aetherglass":5,"peatwax":5,"verdant_grafts":5,"brass_scrip":5,"memory_salt":5},
        "map":terrain_map(*commander["terrain"], case["seed"], width, height), "start":{"x":1,"y":middle_y}, "hero_starts":[case["hero_id"]],
        "objectives":{"victory_text":f"{hero_name} has broken the dominion line and taken its hostile seat.", "defeat_text":f"A friendly strongpoint falls, pressure closes the siege, or Day {deadline} arrives.", "victory":victory, "defeat":[{"id":f"{prefix}_lose_home","label":"Keep the home strongpoint","type":"town_not_owned_by_player","placement_id":f"{prefix}_home"},{"id":f"{prefix}_lose_forward","label":"Keep the forward strongpoint","type":"town_not_owned_by_player","placement_id":f"{prefix}_forward"},{"id":f"{prefix}_pressure","label":"Keep dominion pressure below 40","type":"enemy_pressure_at_least","faction_id":case["enemy_faction_id"],"threshold":40},{"id":f"{prefix}_deadline","label":f"Complete the siege before Day {deadline}","type":"day_at_least","day":deadline}]},
        "script_hooks":[
            {"id":f"{prefix}_day_two_stores","priority":140,"conditions":[{"type":"day_at_least","day":2},{"type":"town_owned_by_player","placement_id":f"{prefix}_home"}],"effects":[{"type":"add_resources","resources":{"gold":3400,"wood":3,"ore":3}},{"type":"town_add_recruits","placement_id":f"{prefix}_forward","recruits":{stacks[0][0]:6,stacks[1][0]:4}},{"type":"message","text":"The paired strongpoints open their siege stores."}]},
            {"id":f"{prefix}_first_front_relief","priority":130,"conditions":[{"type":"encounter_resolved","placement_id":f"{prefix}_front_1"}],"effects":[{"type":"add_army_units","units":{stacks[3][0]:2,stacks[0][0]:5}},{"type":"message","text":"Freed siege hands reinforce the command company."}]},
            {"id":f"{prefix}_second_front_stores","priority":120,"conditions":[{"type":"encounter_resolved","placement_id":f"{prefix}_front_2"}],"effects":[{"type":"add_resources","resources":{"gold":1000,"wood":2,"ore":2}},{"type":"message","text":"The second front yields a sealed field magazine."}]},
            {"id":f"{prefix}_third_front_rare","priority":110,"conditions":[{"type":"encounter_resolved","placement_id":f"{prefix}_front_3"}],"effects":[{"type":"add_resources","resources":{commander["rare_resource"]:1}},{"type":"message","text":"The third front releases a strategic reserve."}]},
            {"id":f"{prefix}_command_recorded","priority":100,"conditions":[{"type":"objective_met","objective_id":f"{prefix}_claim_command"}],"effects":[{"type":"add_resources","resources":{"gold":750}},{"type":"message","text":"The landmark records dominion command."}]},
            {"id":f"{prefix}_late_reserve","priority":80,"conditions":[{"type":"day_at_least","day":13},{"type":"objective_not_met","objective_id":f"{prefix}_capture_enemy"}],"effects":[{"type":"add_enemy_pressure","faction_id":case["enemy_faction_id"],"amount":4},{"type":"town_add_recruits","placement_id":f"{prefix}_forward","recruits":{stacks[2][0]:2,stacks[3][0]:1}},{"type":"spawn_encounter","placement":{"placement_id":f"{prefix}_late_reserve_host","encounter_id":encounters[4],"x":20,"y":height-2,"difficulty":"scripted","spawned_by_faction_id":case["enemy_faction_id"],"days_active":0,"arrived":False,"goal_distance":9999}},{"type":"message","text":"The hostile seat commits its reserve before the siege closes."}]},
        ],
        "towns":[{"placement_id":f"{prefix}_home","town_id":case["home_town_id"],"x":0,"y":middle_y,"owner":"player","built_buildings":["building_market_square"]},{"placement_id":f"{prefix}_forward","town_id":case["forward_town_id"],"x":11,"y":height-2,"owner":"player","built_buildings":["building_market_square"]},{"placement_id":f"{prefix}_enemy_town","town_id":case["enemy_town_id"],"x":21,"y":middle_y,"owner":"enemy"}],
        "enemy_factions":[{"faction_id":case["enemy_faction_id"],"label":case["enemy_label"],"pressure_per_day":1,"pressure_per_enemy_town":1,"raid_threshold":12,"max_active_raids":1,"raid_pillage_delay":2,"raid_pillage":{"gold":250},"raid_encounter_ids":encounters,"spawn_points":[{"x":21,"y":1},{"x":21,"y":height-2}],"siege_target_placement_id":f"{prefix}_forward","siege_active_raid_threshold":2,"siege_capture_progress":2,"priority_target_placement_ids":[f"{prefix}_forward",f"{prefix}_home",f"{prefix}_landmark"]}],
        "resource_nodes":nodes, "artifact_nodes":[], "encounters":fronts,
        "content_status":"commander_dominion_siege_live", "content_batch_id":SLICE_ID, "scenario_family":"commander_dominion_siege", "deterministic_seed":case["seed"],
        "commander_dominion_siege":{"hero_id":case["hero_id"],"landmark_site_id":case["site_id"],"home_town_id":case["home_town_id"],"forward_town_id":case["forward_town_id"],"enemy_town_id":case["enemy_town_id"],"front_count":5,"claim_unit_ids":commander["claim_units"],"relief_unit_id":stacks[3][0]},
    }


def main() -> None:
    scenarios = base.load(CONTENT / "scenarios.json")
    groups = base.load(CONTENT / "army_groups.json")
    sites = base.load(CONTENT / "resource_sites.json")
    heroes = {row["id"]:row for row in base.load(CONTENT / "heroes.json")["items"]}
    art = base.load(ART_MANIFEST)
    atlas_sha, source_rows = render_art()
    for index, case in enumerate(CASES):
        commander = COMMANDERS[case["key"]]
        hero = heroes[case["hero_id"]]
        army_id = f"army_{case['prefix']}_dominion_siege_host"
        base.upsert(groups["items"], {"id":army_id,"name":f"{hero['name']} Dominion Siege Host","faction_id":commander["faction_id"],"stacks":[{"unit_id":unit_id,"count":count} for unit_id,count in commander["stacks"]],"content_status":"commander_dominion_siege_host_live","content_batch_id":SLICE_ID})
        base.upsert(sites["items"], {"id":case["site_id"],"name":case["site_name"],"family":"scenario_objective","action_label":case["action_label"],"summary":f"{case['site_name']} establishes {hero['name']}'s command over the dominion siege.","claim_rewards":{"gold":900,commander["rare_resource"]:2,"experience":300},"claim_recruits":{commander["claim_units"][0]:3,commander["claim_units"][1]:1},"claim_flags":{f"{case['prefix']}_dominion_command_claimed":True},"runtime_boundary":{"status":"commander_dominion_siege_live","live_reward_grants":True,"save_payload_required":True,"renderer_sprite_required":True,"pathing_runtime_adopted":True,"route_effect_runtime_adopted":False,"hero_progression_activation":True,"scenario_placement_migration":True},"content_batch_id":SLICE_ID,"public_text":{"public_summary":case["description"],"no_internal_debug_score_fields":True,"large_text_panel_required":False}})
        base.upsert(scenarios["items"], scenario_record(case, hero["name"], army_id))
        art["object_assets"][case["asset_id"]] = {"path":ATLAS_RES,"atlas_region":[index*48,0,48,48],"atlas_size":[480,48],"runtime_sha256":atlas_sha,"source_trimmed":source_rows[index]["source_path"],"source_generated":source_rows[index]["source_path"],"source_model":"built_in_imagegen_original_commander_dominion_sieges_atlas","asset_policy":"original_generated_runtime_sprite_no_homm3_art_import","distinct_sprite_assignment":True,"assigned_resource_site_id":case["site_id"],"assigned_hero_id":case["hero_id"],"presentation_role":case["site_id"].removeprefix("site_"),"accessible_description":case["description"]}
        art["resource_site_sprites"][case["site_id"]] = {"asset_id":case["asset_id"],"unclaimed_asset_id":case["asset_id"],"fit":f"Exact original {case['site_name']} remains visible before and after its one-time dominion-command claim."}
    scenarios["player_facing_active_scenario_count"] = len(scenarios["items"])
    base.write_compact(CONTENT / "scenarios.json", scenarios)
    base.write_groups(CONTENT / "army_groups.json", groups)
    base.write_pretty(CONTENT / "resource_sites.json", sites)
    base.write_pretty(ART_MANIFEST, art)
    print(json.dumps({"slice_id":SLICE_ID,"scenario_count":len(scenarios["items"]),"army_group_count":len(groups["items"]),"resource_site_count":len(sites["items"]),"atlas_sha256":atlas_sha}, sort_keys=True))


if __name__ == "__main__":
    main()
