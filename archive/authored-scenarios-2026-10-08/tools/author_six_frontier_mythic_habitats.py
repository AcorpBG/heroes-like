#!/usr/bin/env python3
"""Author six original frontier creatures, habitats, encounters, and skirmishes."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageOps

import author_eight_commanders_proving_roads as base


ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / "content"
UNIT_SOURCE_ROOT = ROOT / "art/units/source/generated/frontier_mythic_habitats_wave1"
CURATED_ROOT = ROOT / "art/units/source/curated"
HABITAT_SOURCE_ROOT = ROOT / "art/overworld/source/generated/resource_sites/frontier_mythic_habitats_wave1"
ATLAS_PATH = ROOT / "art/overworld/runtime/objects/resource_sites/frontier_mythic_habitats_atlas.png"
ATLAS_RES = "res://art/overworld/runtime/objects/resource_sites/frontier_mythic_habitats_atlas.png"
ART_MANIFEST = ROOT / "art/overworld/manifest.json"
MAP_SPRITES = ROOT / "art/overworld/map_object_sprites.json"
SLICE_ID = "content-six-frontier-mythic-habitats-10184"
GENERATOR_ROOT = Path("/root/.codex/generated_images/019fe72a-30b1-76f3-b911-385c4444bd16")

RARE_ECONOMY_SITES = [
    ("embergrain", "site_embergrain_warm_granary", (3, 3)),
    ("peatwax", "site_peatwax_reed_yard", (7, 5)),
    ("aetherglass", "site_aetherglass_lens_house", (12, 5)),
    ("verdant_grafts", "site_verdant_graft_nursery", (3, 9)),
    ("brass_scrip", "site_brass_scrip_mint", (8, 10)),
    ("memory_salt", "site_memory_salt_pan", (12, 12)),
]


CASES = [
    {
        "stem":"cindervane_updraft_roost", "name":"Censerwing Updraft Roost", "unit_id":"unit_neutral_cindervane_censerwings", "unit_name":"Cindervane Censerwings",
        "source_name":"unit_neutral_cindervane_censerwings_source.png", "source_original":"exec-d211351c-ed37-4756-96ef-16be91238386.png",
        "habitat_source":"censerwing_updraft_roost_source.png", "habitat_original":"exec-b8338c6d-80c9-403e-bcdf-b1b0a8ac2120.png",
        "faction_id":"faction_embercourt", "hero_id":"hero_lyra", "player_army_id":"army_belis_grand_convergence_company", "town_id":"town_rainwrit_bastion", "enemy_town_id":"town_hollowreed_sanctuary", "enemy_faction_id":"faction_mireclaw",
        "scenario_id":"emberwell-censerwing-updraft", "scenario_name":"Emberwell Censerwing Updraft", "terrain":("lava","rough"), "biomes":["biome_ash_lava_wastes","biome_highland_ridge"], "rare":"embergrain", "rare_site":"site_embergrain_warm_granary", "companion":"unit_neutral_cinderpot_hurlers", "seed":57100,
        "tier":5, "role":"ranged", "stats":(43,14,10,10,16,9,11,2,820), "shots":7, "ability_pair":"harry_volley", "school":"beacon", "resists":(16,18,24),
        "description":"A split basalt chimney, curved bronze cage ribs, ember vanes, and an empty hanging censer cradle mark the updraft roost.",
        "unit_prompt":"Polished hand-painted transparent production game-unit master of one original four-winged ember ibis and moth hybrid with a bronze censer thorax, soot-dark hooked legs, ember beak, vented upper and lower wings, and charcoal plume tail; isolated full-body high three-quarter battle pose; no scenery, text, logo, watermark, or copied franchise design.",
    },
    {
        "stem":"fenmirror_shell_basin", "name":"Fenmirror Shell Basin", "unit_id":"unit_neutral_fenmirror_gallowshells", "unit_name":"Fenmirror Gallowshells",
        "source_name":"unit_neutral_fenmirror_gallowshells_source.png", "source_original":"exec-1eef3235-a103-4cbf-b416-1aea8332666e.png",
        "habitat_source":"fenmirror_shell_basin_source.png", "habitat_original":"exec-866a7d72-8bab-46a4-ab47-7e9fcea78aa0.png",
        "faction_id":"faction_mireclaw", "hero_id":"hero_tarn", "player_army_id":"army_tarn_ascendant_company", "town_id":"town_moonbite_reedshrine", "enemy_town_id":"town_halo_spire", "enemy_faction_id":"faction_sunvault",
        "scenario_id":"fenhook-fenmirror-muster", "scenario_name":"Fenhook Fenmirror Muster", "terrain":("mire","swamp"), "biomes":["biome_mire_fen","biome_coast_archipelago"], "rare":"peatwax", "rare_site":"site_peatwax_reed_yard", "companion":"unit_neutral_peatflare_jarriers", "seed":57200,
        "tier":6, "role":"melee", "stats":(74,13,17,13,19,4,6,1,1120), "ability_pair":"brace_shielding", "school":"mire", "resists":(18,32,30),
        "description":"Two leaning crescent shell arches enclose a dark mirror basin, dangling reed chains, and a low root landing pier.",
        "unit_prompt":"Polished hand-painted transparent production game-unit master of one original broad six-legged marsh turtle-crab with a huge crescent peatglass shell arch, blunt shovel claws, one lantern eye, and reed-chain tassels; isolated full-body high three-quarter braced pose; no scenery, text, logo, watermark, or copied franchise design.",
    },
    {
        "stem":"prismwake_refraction_shelf", "name":"Prismwake Refraction Shelf", "unit_id":"unit_neutral_prismwake_raylings", "unit_name":"Prismwake Raylings",
        "source_name":"unit_neutral_prismwake_raylings_source.png", "source_original":"exec-f2040325-6644-46a9-be65-d1b9752ac508.png",
        "habitat_source":"prismwake_refraction_shelf_source.png", "habitat_original":"exec-269caf99-710e-4666-af3f-df3140a7ec38.png",
        "faction_id":"faction_sunvault", "hero_id":"hero_neral", "player_army_id":"army_meridian_treasury_company", "town_id":"town_dawnmirror_observatory", "enemy_town_id":"town_blackbell_foundry", "enemy_faction_id":"faction_brasshollow",
        "scenario_id":"glasswind-prismwake-crossing", "scenario_name":"Glasswind Prismwake Crossing", "terrain":("sand","grass"), "biomes":["biome_grasslands","biome_highland_ridge"], "rare":"aetherglass", "rare_site":"site_aetherglass_lens_house", "companion":"unit_neutral_snowglass_markers", "seed":57300,
        "tier":5, "role":"ranged", "stats":(44,15,9,11,17,10,12,2,860), "shots":6, "ability_pair":"harry_volley", "school":"lens", "resists":(22,16,30),
        "description":"An ivory floating shelf carries an offset oval lens arch, two prism sails, glass chimes, and three narrow crystal keels.",
        "unit_prompt":"Polished hand-painted transparent production game-unit master of one original hovering desert manta built from ivory cartilage ribs and translucent prism fins, with one circular lens eye, glass streamers, and a hooked light keel; isolated full-body high three-quarter pose; no scenery, text, logo, watermark, or copied franchise design.",
    },
    {
        "stem":"knotstag_root_court", "name":"Knotstag Root-Court", "unit_id":"unit_neutral_rootcrown_knotstags", "unit_name":"Rootcrown Knotstags",
        "source_name":"unit_neutral_rootcrown_knotstags_source.png", "source_original":"exec-68a2b180-1e88-4a41-9608-bbfa5fa7383b.png",
        "habitat_source":"knotstag_root_court_source.png", "habitat_original":"exec-8c304816-df8f-4a23-8f53-6f4c14c6931a.png",
        "faction_id":"faction_thornwake", "hero_id":"hero_thornwake_bryn_boltroot", "player_army_id":"army_boltroot_command_relic_company", "town_id":"town_thornwake_rootgate_nursery", "enemy_town_id":"town_cinderlock_bastion", "enemy_faction_id":"faction_embercourt",
        "scenario_id":"boltroot-knotstag-circuit", "scenario_name":"Boltroot Knotstag Circuit", "terrain":("forest","grass"), "biomes":["biome_deep_forest","biome_grasslands"], "rare":"verdant_grafts", "rare_site":"site_verdant_graft_nursery", "companion":"unit_neutral_thornbow_scouts", "seed":57400,
        "tier":6, "role":"melee", "stats":(70,15,15,14,21,7,9,1,1150), "ability_pair":"reach_shielding", "school":"root", "resists":(20,28,32),
        "description":"A living-root amphitheater rises into two unequal antler gates around a hollow dais and three seed-lantern pods.",
        "unit_prompt":"Polished hand-painted transparent production game-unit master of one original six-legged forest beast with bark plates, rooting forelegs, an enormous tangled living-root antler crown, and three amber seed lantern pods; isolated full-body high three-quarter pose; no scenery, text, logo, watermark, ordinary deer, or copied franchise design.",
    },
    {
        "stem":"gaugecoil_pressure_burrow", "name":"Gaugecoil Pressure Burrow", "unit_id":"unit_neutral_gaugecoil_orewyrms", "unit_name":"Gaugecoil Orewyrms",
        "source_name":"unit_neutral_gaugecoil_orewyrms_source.png", "source_original":"exec-77b2b83b-02a1-4e1a-9d1b-96d7b6441799.png",
        "habitat_source":"gaugecoil_pressure_burrow_source.png", "habitat_original":"exec-c8564320-b568-4ae4-be8c-7f66dcaa1711.png",
        "faction_id":"faction_brasshollow", "hero_id":"hero_brasshollow_harro_debtrune", "player_army_id":"army_harro_grand_convergence_company", "town_id":"town_brasshollow_orevein_gantry", "enemy_town_id":"town_gloamwake_anchorage", "enemy_faction_id":"faction_veilmourn",
        "scenario_id":"debtrune-gaugecoil-burrow", "scenario_name":"Debtrune Gaugecoil Burrow", "terrain":("rough","lava"), "biomes":["biome_rough_badlands","biome_subterranean_underways"], "rare":"brass_scrip", "rare_site":"site_brass_scrip_mint", "companion":"unit_neutral_tunnelmark_bolters", "seed":57500,
        "tier":6, "role":"melee", "stats":(78,17,16,15,23,5,7,1,1250), "ability_pair":"brace_reach", "school":"furnace", "resists":(24,30,34),
        "description":"Three concentric pressure rings frame a dark drill rail beneath oversized blank gauges, a red relief valve, and six anchor feet.",
        "unit_prompt":"Polished hand-painted transparent production game-unit master of one original living squat segmented brass-and-basalt burrower with wedge feet, drill-petal jaw, natural mineral plates, three pressure bladders, and valve tail; isolated full-body high three-quarter pose; no scenery, text, logo, watermark, robot, dragon, or copied franchise design.",
    },
    {
        "stem":"gloambell_sounding_deep", "name":"Gloambell Sounding Deep", "unit_id":"unit_neutral_gloambell_wake_mantas", "unit_name":"Gloambell Wake-Mantas",
        "source_name":"unit_neutral_gloambell_wake_mantas_source.png", "source_original":"exec-3c5fd1a7-2e64-488b-b3c0-76b1b9265787.png",
        "habitat_source":"gloambell_sounding_deep_source.png", "habitat_original":"exec-1c8e109e-950a-46a9-8864-e9a4acae46ca.png",
        "faction_id":"faction_veilmourn", "hero_id":"hero_veilmourn_cela_mistcorsair", "player_army_id":"army_cela_mistcorsair_raiders", "town_id":"town_veilmourn_fogchart_mooring", "enemy_town_id":"town_crownroot_refuge", "enemy_faction_id":"faction_thornwake",
        "scenario_id":"mistcorsair-gloambell-sounding", "scenario_name":"Mist-Corsair Gloambell Sounding", "terrain":("snow","mire"), "biomes":["biome_snow_frost_marches","biome_coast_archipelago"], "rare":"memory_salt", "rare_site":"site_memory_salt_pan", "companion":"unit_neutral_lanternskate_throwers", "seed":57600,
        "tier":7, "role":"ranged", "stats":(76,16,15,17,26,7,9,1,1550), "shots":5, "ability_pair":"harry_volley", "school":"veil", "resists":(30,26,36),
        "description":"A tilted whalebone arch shelters one drowned bell, two tideglass pools, pale sounding rods, and a narrow keel stair.",
        "unit_prompt":"Polished hand-painted transparent production game-unit master of one original enormous pale aerial deepwater manta-whale with asymmetric sail fins, masklike head, tideglass belly, and four hanging clapper tendrils; isolated full-body high three-quarter banking pose; no scenery, text, logo, watermark, ordinary whale, or copied franchise design.",
    },
]


def h(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def unit_abilities(case: dict) -> list[dict]:
    stem = case["stem"].split("_")[0]
    if case["ability_pair"] == "harry_volley":
        return [
            {"id":"harry","name":f"{case['unit_name'].split()[0]} Mark","description":f"Once per battle, the {case['unit_name'].lower()} fold a veteran formation's bearings into their frontier resonance.","status_id":"status_harried","status_label":f"{stem.title()}-Marked","duration_rounds":2,"modifiers":{"defense":-1,"initiative":-1},"momentum_gain":0,"uses_per_battle":1,"target_min_tier":4,"ai_target_priority_bonus":0.25},
            {"id":"volley","name":f"{case['unit_name'].split()[0]} Broadside","description":f"A coordinated ranged release crosses an open lane and intensifies against a marked formation.","damage_multiplier":1.15,"min_distance":2,"status_ids":["status_harried"],"status_damage_multiplier":1.08,"ally_defending_multiplier":1.04},
        ]
    if case["ability_pair"] == "brace_shielding":
        return [
            {"id":"brace","name":"Gallowshell Mooring","description":"Six low legs lock beneath the shell arch and answer the first assault with a rooted counterstroke.","retaliation_multiplier":1.19,"defending_cohesion_bonus":2,"status_id":"status_rooted","status_label":"Mirror-Moored","duration_rounds":1,"modifiers":{"initiative":-1,"cohesion":-1}},
            {"id":"shielding","name":"Crescent Shell","description":"The rising peatglass arch blunts missiles while the gallowshell holds the basin line.","cohesion_hold_bonus":2,"ranged_damage_multiplier":0.72,"engaged_damage_multiplier":1.04},
        ]
    if case["ability_pair"] == "reach_shielding":
        return [
            {"id":"reach","name":"Rootcrown Sweep","description":"The tangled crown reaches across one unfinished closing step before the six-legged body arrives.","distance_one_multiplier":1.11},
            {"id":"shielding","name":"Knotwood Mantle","description":"Layered bark and the low crown turn missiles while the knotstag remains engaged.","cohesion_hold_bonus":2,"ranged_damage_multiplier":0.75,"engaged_damage_multiplier":1.05},
        ]
    return [
        {"id":"brace","name":"Pressure-Coil Brace","description":"Wedge feet and a coiled mineral spine lock against assault and return the stored pressure.","retaliation_multiplier":1.18,"defending_cohesion_bonus":2,"status_id":"status_rooted","status_label":"Pressure-Braced","duration_rounds":1,"modifiers":{"initiative":-1,"cohesion":-1}},
        {"id":"reach","name":"Drill-Petal Lunge","description":"The opening drill jaw crosses one unfinished closing step before the coil unspools.","distance_one_multiplier":1.1},
    ]


def unit_record(case: dict) -> dict:
    hp, attack, defense, minimum, maximum, speed, initiative, growth, gold = case["stats"]
    row = {"id":case["unit_id"],"name":case["unit_name"],"faction_id":"","affiliation":"neutral","role":case["role"],"tier":case["tier"],"hp":hp,"attack":attack,"defense":defense,"min_damage":minimum,"max_damage":maximum,"speed":speed,"initiative":initiative,"retaliations":1,"ranged":case["role"]=="ranged","growth":growth,"cost":{"gold":gold,case["rare"]:1 if case["tier"] < 7 else 2},"content_status":"frontier_mythic_habitat_live","abilities":unit_abilities(case),"spell_resistance_pct":case["resists"][0],"control_resistance_pct":case["resists"][1],"spell_school_resistance_pct":{case["school"]:case["resists"][2]},"status_immunity_ids":[]}
    if case["role"] == "ranged":
        row["shots"] = case["shots"]
    return row


def curate_units() -> list[dict]:
    CURATED_ROOT.mkdir(parents=True, exist_ok=True)
    rows = []
    for case in CASES:
        source = UNIT_SOURCE_ROOT / case["source_name"]
        with Image.open(source) as opened:
            rgba = opened.convert("RGBA")
        alpha = rgba.getchannel("A")
        bbox = alpha.getbbox()
        if bbox is None:
            raise RuntimeError(f"Generated creature source has no alpha: {source}")
        cropped = rgba.crop(bbox)
        fitted = ImageOps.contain(cropped, (480, 480), Image.Resampling.LANCZOS)
        # Imagegen can top out at alpha 254; promote its near-opaque body pixels.
        fitted.putalpha(fitted.getchannel("A").point(lambda value: 255 if value >= 250 else value))
        canvas = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
        canvas.alpha_composite(fitted, ((512 - fitted.width) // 2, 500 - fitted.height))
        curated = CURATED_ROOT / f"{case['unit_id']}.png"
        canvas.save(curated, optimize=True)
        rows.append({"unit_id":case["unit_id"],"source_path":f"res://{source.relative_to(ROOT).as_posix()}","source_size":list(rgba.size),"source_sha256":h(source),"curated_path":f"res://{curated.relative_to(ROOT).as_posix()}","curated_sha256":h(curated),"original_generated_path":str(GENERATOR_ROOT / case["source_original"]),"prompt":case["unit_prompt"]})
    base.write_pretty(UNIT_SOURCE_ROOT / "manifest.json", {"schema_id":"generated_unit_source_provenance_v1","content_slice_id":SLICE_ID,"generator_mode":"built_in_imagegen","generated_at":"2026-09-01T02:15:00Z","curation":"Six transparent masters visually reviewed together at source scale, then deterministically trimmed into 512x512 curated sources before runtime surface generation.","items":rows})
    return rows


def habitat_frame(source: Path) -> Image.Image:
    with Image.open(source) as opened:
        rgba = opened.convert("RGBA")
    bbox = rgba.getchannel("A").getbbox()
    if bbox is None:
        raise RuntimeError(f"Generated habitat source has no alpha: {source}")
    fitted = ImageOps.contain(rgba.crop(bbox), (43, 43), Image.Resampling.LANCZOS)
    frame = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    frame.alpha_composite(fitted, ((48-fitted.width)//2, 46-fitted.height))
    return frame


def render_habitat_art() -> tuple[str, list[dict]]:
    ATLAS_PATH.parent.mkdir(parents=True, exist_ok=True)
    atlas = Image.new("RGBA", (576, 48), (0,0,0,0))
    rows = []
    for index, case in enumerate(CASES):
        source = HABITAT_SOURCE_ROOT / case["habitat_source"]
        unclaimed = habitat_frame(source)
        controlled = unclaimed.copy()
        draw = ImageDraw.Draw(controlled)
        draw.line((8,5,8,22), fill=(246,222,142,255), width=2)
        draw.polygon([(9,6),(18,9),(9,13)], fill=(240,245,226,255), outline=(79,58,41,255))
        draw.ellipse((4,39,43,46), outline=(246,222,142,230), width=2)
        x = index * 96
        atlas.alpha_composite(unclaimed, (x,0))
        atlas.alpha_composite(controlled, (x+48,0))
        rows.append({"stem":case["stem"],"site_id":f"site_{case['stem']}","source_path":f"res://{source.relative_to(ROOT).as_posix()}","source_size":list(Image.open(source).size),"source_sha256":h(source),"generation_original":str(GENERATOR_ROOT / case["habitat_original"]),"prompt":f"Polished hand-painted transparent production overworld habitat master of {case['name']}: {case['description']} Isolated high three-quarter structure, no ground, scenery, creature, people, text, logo, watermark, or copied franchise design.","accessible_description":case["description"],"unclaimed_region":[x,0,48,48],"controlled_region":[x+48,0,48,48]})
    atlas.save(ATLAS_PATH,optimize=True,compress_level=9)
    atlas_sha = h(ATLAS_PATH)
    base.write_pretty(HABITAT_SOURCE_ROOT / "manifest.json", {"schema_id":"frontier_mythic_habitat_art_v1","content_slice_id":SLICE_ID,"generation_mode":"built_in_imagegen","source_model":"built_in_imagegen_original_frontier_mythic_habitat_atlas","prompt_set_summary":"Six transparent original recruitable habitats with deterministic unclaimed and pennant-marked controlled states.","runtime_atlas":ATLAS_RES,"atlas_size":[576,48],"runtime_sha256":atlas_sha,"source_package_policy":"retained_for_provenance_excluded_from_linux_and_windows_exports","assets":rows})
    return atlas_sha, rows


def dwelling_records(case: dict) -> tuple[dict,dict,dict,dict,dict]:
    stem, unit, companion = case["stem"], case["unit_id"], case["companion"]
    dwelling_id, site_id, object_id = f"neutral_dwelling_{stem}", f"site_{stem}", f"object_{stem}"
    group_id, encounter_id = f"army_neutral_{stem}_watch", f"encounter_{stem}_watch"
    contract = {"contract_id":f"dwelling_contract_{stem}","neutral_dwelling_family_id":dwelling_id,"resource_site_id":site_id,"roster_unit_ids":[unit,companion],"recruit_policy":"weekly_muster","recurring_recruit_access":True,"guarded_variant":True,"metadata_only_guard_contract":False,"requires_visible_guard_cue":True}
    guard = {"tier":"apex" if case["tier"]==7 else "elite","visible_cue":f"the visible {case['unit_name'].lower()} watch blocks {case['name']} before recruitment","guard_army_group_id":group_id,"guard_encounter_id":encounter_id,"clear_required_for_recruitment":True,"blocks_approach":True,"event_expectation":f"the exact {case['unit_name'].lower()} watch must fall before the weekly muster opens"}
    dwelling = {"id":dwelling_id,"name":case["name"],"summary":f"Frontier keepers recruit {case['unit_name'].lower()} after commanders break the visible watch and secure {case['name']}.","biome_ids":case["biomes"],"unit_ids":[unit,companion],"site_ids":[site_id],"map_object_ids":[object_id],"army_group_ids":[group_id],"encounter_ids":[encounter_id],"content_status":"frontier_mythic_neutral_dwelling_live"}
    recruits = {unit:1, companion:3}
    weekly = {unit:1, companion:1}
    site = {"id":site_id,"name":case["name"],"family":"neutral_dwelling","dwelling_scope":"neutral","neutral_dwelling_family_id":dwelling_id,"persistent_control":True,"claim_rewards":{"gold":500,case["rare"]:1},"claim_flags":{f"{stem}_claimed":True},"control_income":{"gold":130,case["rare"]:1},"claim_recruits":recruits,"weekly_recruits":weekly,"neutral_roster":{"claim_recruits":recruits,"weekly_recruits":weekly,"guard_army_group_id":group_id,"guard_encounter_id":encounter_id},"response_profile":{"action_label":f"Secure {case['name']}","summary":case["description"],"movement_cost":7,"resource_cost":{"gold":720,case["rare"]:1},"watch_days":6,"quality_bonus":5,"readiness_bonus":4,"recovery_relief":1},"dwelling_contract":contract,"guard_expectation":guard,"runtime_boundary":{"status":"neutral_dwelling_live","neutral_dwelling_site_runtime_supported":True,"guarded_variant_runtime_migration":True,"recruitment_ui_overhaul":False,"save_payload_required":True,"renderer_sprite_required":True,"pathing_runtime_adopted":True,"rare_resource_activation":False,"scenario_placement_migration":True,"guard_resolution_runtime_adopted":True},"guarded":True,"guard_profile":{"tier":guard["tier"],"guard_army_group_id":group_id,"guard_encounter_id":encounter_id,"visible_cue":guard["visible_cue"],"metadata_only":False,"runtime_guard_resolution_adopted":True},"content_batch_id":SLICE_ID,"batch_role":"guarded_frontier_mythic_dwelling"}
    obj = {"id":object_id,"name":case["name"],"family":"neutral_dwelling","resource_site_id":site_id,"biome_ids":case["biomes"],"footprint":{"width":2,"height":2,"anchor":"bottom_center","tier":"medium"},"passable":False,"visitable":True,"map_roles":["neutral_recruit_source","weekly_muster","counter_capture_target","guarded_reward"],"schema_version":1,"primary_class":"neutral_dwelling","secondary_tags":["frontier_mythic_neutral_recruit_source","weekly_muster","counter_capture_target","guarded_reward"],"body_tiles":[{"x":0,"y":0,"role":"body"},{"x":1,"y":0,"role":"body"},{"x":0,"y":1,"role":"body"},{"x":1,"y":1,"role":"body"}],"approach":{"mode":"adjacent","primary_sides":["south","west"],"visit_offsets":[{"x":1,"y":1},{"x":0,"y":1}],"stop_before_interaction":True,"requires_clear_tile":True,"guard_clearance_required":True},"passability_class":"blocking_visitable","interaction":{"cadence":"persistent_control","remains_after_visit":True,"state_after_visit":"controlled","requires_ownership":False,"requires_guard_clear":True,"supports_revisit":True,"cooldown_days":0,"refresh_rule":"weekly_muster"},"dwelling_contract":contract,"guard_expectation":guard,"editor_placement":{"placement_mode":"resource_site_object","density_band":"ruin_reward_pocket","minimum_lane_clearance":3,"allows_adjacent_visitable":True,"requires_approach_clearance":True,"requires_guard_space":True,"warn_if_hiding_target":True},"ai_hints":{"strategic_value":12,"risk_tier":guard["tier"],"placement_role":f"frontier_mythic_{stem}","guard_target_value_hint":8,"avoid_until_strength":"elite"},"runtime_boundary":site["runtime_boundary"],"content_batch_id":SLICE_ID,"batch_role":"guarded_frontier_mythic_dwelling"}
    group = {"id":group_id,"name":f"{case['name']} Watch","affiliation":"neutral","stacks":[{"unit_id":unit,"count":2 if case["tier"]<7 else 1},{"unit_id":companion,"count":7}]}
    encounter = {"id":encounter_id,"name":f"{case['name']} Watch","enemy_group_id":group_id,"affiliation":"neutral","terrain":case["terrain"][0],"battlefield_tags":["open_lane","wall_pressure"],"max_rounds":15,"enemy_commander":{"name":f"Keeper of {case['name']}","command":{"attack":3,"defense":3,"power":1,"knowledge":1},"starting_spell_ids":[],"battle_traits":["vanguard","linekeeper"]},"field_objectives":[{"id":f"{stem}_anchor","type":"breach_point","label":f"{case['name']} Anchor","summary":f"The habitat watch holds its exact recruitment anchor until the frontier line is broken.","starting_side":"enemy","capture_threshold":2,"urgency_round":2,"pressure_tags":["momentum","initiative","urgency"]}],"rewards":{"gold":760,case["rare"]:2,"experience":580},"victory_flags":[f"frontier_mythic_{stem}_watch_broken"]}
    return dwelling, site, obj, group, encounter


def terrain_map(primary: str, accent: str, seed: int) -> list[list[str]]:
    return [[accent if (x*7+y*11+seed)%29 in (0,1,2,3,4,5) else primary for x in range(18)] for y in range(14)]


def _scenario_record_base(case: dict) -> dict:
    stem, site_id, encounter_id = case["stem"], f"site_{case['stem']}", f"encounter_{case['stem']}_watch"
    fronts = [{"placement_id":f"{stem}_front_{index}","encounter_id":encounter_id,"x":x,"y":y,"difficulty":"medium" if index<3 else "hard","combat_seed":case["seed"]+index,"prefer_identity_landmark":True,"guardian_role":"frontier_mythic_habitat_front"} for index,(x,y) in enumerate(((5,3),(10,7),(14,10)),start=1)]
    victory = [{"id":f"{stem}_clear_{i}","label":f"Break habitat watch {i}","type":"encounter_resolved","placement_id":f"{stem}_front_{i}"} for i in range(1,4)]
    victory += [{"id":f"{stem}_claim","label":f"Secure {case['name']}","type":"flag_true","flag":f"{stem}_claimed"},{"id":f"{stem}_recruit","label":f"Muster {case['unit_name']}","type":"hero_army_meets_requirements","hero_id":case["hero_id"],"requirements":[{"unit_id":case["unit_id"],"minimum_count":1}]},{"id":f"{stem}_capture","label":"Capture the opposing frontier seat","type":"town_owned_by_player","placement_id":f"{stem}_enemy_town"}]
    nodes = [
        {"placement_id":f"{stem}_wood_n","site_id":"site_wood_wagon","x":2,"y":1},{"placement_id":f"{stem}_ore_n","site_id":"site_ore_crates","x":8,"y":1},{"placement_id":f"{stem}_rare_n","site_id":case["rare_site"],"x":12,"y":1},
        {"placement_id":f"{stem}_waystone","site_id":"site_waystone_cache","x":4,"y":12},{"placement_id":f"{stem}_ore_s","site_id":"site_ore_crates","x":9,"y":12},{"placement_id":f"{stem}_rare_s","site_id":case["rare_site"],"x":13,"y":12},
        {"placement_id":f"{stem}_habitat","site_id":site_id,"x":15,"y":10,"guard_front_id":f"{stem}_front_3"},
    ]
    for rare_key, rare_site_id, (x, y) in RARE_ECONOMY_SITES:
        if rare_key != case["rare"]:
            nodes.append({"placement_id":f"{stem}_{rare_key}_route","site_id":rare_site_id,"x":x,"y":y})
    return {"id":case["scenario_id"],"name":case["scenario_name"],"selection":{"summary":f"Break three {case['unit_name'].lower()} watches, secure {case['name']}, recruit its creature, and capture the opposing frontier seat.","recommended_difficulty":"normal","map_size_label":"Frontier Habitat (18x14)","player_summary":"A roster commander leads a proven company into a new recruitable frontier ecology.","enemy_summary":"Three exact habitat watches and an opposing town hold the far side of the route.","availability":{"campaign":False,"skirmish":True}},"map_size":{"width":18,"height":14},"player_faction_id":case["faction_id"],"player_army_id":case["player_army_id"],"hero_id":case["hero_id"],"starting_resources":{"gold":12000,"wood":16,"ore":16,"embergrain":4,"aetherglass":4,"peatwax":4,"verdant_grafts":4,"brass_scrip":4,"memory_salt":4},"map":terrain_map(*case["terrain"],case["seed"]),"start":{"x":1,"y":7},"hero_starts":[case["hero_id"]],"objectives":{"victory_text":f"The expedition has recruited {case['unit_name'].lower()} and secured the frontier habitat.","defeat_text":"The home seat falls, pressure overwhelms the route, or Day 25 arrives.","victory":victory,"defeat":[{"id":f"{stem}_lose_home","label":"Keep the home seat","type":"town_not_owned_by_player","placement_id":f"{stem}_home"},{"id":f"{stem}_pressure","label":"Keep frontier pressure below 36","type":"enemy_pressure_at_least","faction_id":case["enemy_faction_id"],"threshold":36},{"id":f"{stem}_deadline","label":"Complete the route before Day 25","type":"day_at_least","day":25}]},"script_hooks":[{"id":f"{stem}_first_relief","priority":130,"conditions":[{"type":"encounter_resolved","placement_id":f"{stem}_front_1"}],"effects":[{"type":"add_resources","resources":{"gold":1200,"wood":2,"ore":2}},{"type":"message","text":"The first watch yields a sealed habitat survey cache."}]},{"id":f"{stem}_second_relief","priority":120,"conditions":[{"type":"encounter_resolved","placement_id":f"{stem}_front_2"}],"effects":[{"type":"add_army_units","units":{case["companion"]:4}},{"type":"message","text":"Local guides reinforce the expedition before the final watch."}]},{"id":f"{stem}_late_pressure","priority":80,"conditions":[{"type":"day_at_least","day":12},{"type":"objective_not_met","objective_id":f"{stem}_capture"}],"effects":[{"type":"add_enemy_pressure","faction_id":case["enemy_faction_id"],"amount":4},{"type":"message","text":"The opposing frontier seat commits its remaining pressure."}]}],"towns":[{"placement_id":f"{stem}_home","town_id":case["town_id"],"x":0,"y":7,"owner":"player","built_buildings":["building_market_square"]},{"placement_id":f"{stem}_enemy_town","town_id":case["enemy_town_id"],"x":17,"y":7,"owner":"enemy"}],"enemy_factions":[{"faction_id":case["enemy_faction_id"],"label":"Frontier Opposition","pressure_per_day":1,"pressure_per_enemy_town":1,"raid_threshold":14,"max_active_raids":1,"raid_pillage_delay":2,"raid_pillage":{"gold":250},"raid_encounter_ids":[encounter_id],"spawn_points":[{"x":17,"y":2},{"x":17,"y":12}],"siege_target_placement_id":f"{stem}_home","siege_active_raid_threshold":2,"siege_capture_progress":2,"priority_target_placement_ids":[f"{stem}_habitat",f"{stem}_home"]}],"resource_nodes":nodes,"artifact_nodes":[],"encounters":fronts,"content_status":"frontier_mythic_habitat_scenario_live","content_batch_id":SLICE_ID,"scenario_family":"frontier_mythic_habitat","deterministic_seed":case["seed"],"frontier_mythic_habitat":{"unit_id":case["unit_id"],"site_id":site_id,"encounter_id":encounter_id,"authored_front_count":3,"save_version":9}}


def scenario_record(case: dict) -> dict:
    scenario = _scenario_record_base(case)
    stem = case["stem"]
    scenario["script_hooks"].extend([
        {
            "id": f"{stem}_home_muster",
            "priority": 125,
            "conditions": [
                {"type": "day_at_least", "day": 2},
                {"type": "town_owned_by_player", "placement_id": f"{stem}_home"},
            ],
            "effects": [
                {"type": "town_add_recruits", "placement_id": f"{stem}_home", "recruits": {case["companion"]: 3}},
                {"type": "message", "text": "The home seat releases frontier guides into its muster."},
            ],
        },
        {
            "id": f"{stem}_late_counterstroke",
            "priority": 75,
            "conditions": [
                {"type": "day_at_least", "day": 10},
                {"type": "objective_not_met", "objective_id": f"{stem}_capture"},
            ],
            "effects": [
                {
                    "type": "spawn_encounter",
                    "placement": {
                        "placement_id": f"{stem}_late_reserve",
                        "encounter_id": f"encounter_{stem}_watch",
                        "x": 16,
                        "y": 2,
                        "difficulty": "scripted",
                        "spawned_by_faction_id": case["enemy_faction_id"],
                        "days_active": 0,
                        "arrived": False,
                        "goal_distance": 9999,
                    },
                },
                {"type": "message", "text": "A reserve habitat watch crosses the upper frontier road."},
            ],
        },
    ])
    return scenario


def main() -> None:
    payloads = {name:base.load(CONTENT/f"{name}.json") for name in ("units","neutral_dwellings","resource_sites","map_objects","army_groups","encounters","scenarios")}
    art = base.load(ART_MANIFEST)
    map_sprites = base.load(MAP_SPRITES)
    unit_sources = curate_units()
    atlas_sha, habitat_sources = render_habitat_art()
    for index, case in enumerate(CASES):
        base.upsert(payloads["units"]["items"], unit_record(case))
        dwelling, site, obj, group, encounter = dwelling_records(case)
        for key,row in (("neutral_dwellings",dwelling),("resource_sites",site),("map_objects",obj),("army_groups",group),("encounters",encounter)):
            base.upsert(payloads[key]["items"],row)
        base.upsert(payloads["scenarios"]["items"],scenario_record(case))
        unclaimed_id = f"mapobj_{case['stem']}"
        controlled_id = f"resource_site_neutral_{case['stem']}_controlled"
        encounter_asset_id = f"encounter_frontier_mythic_{case['stem']}_watch"
        x = index * 96
        common = {"path":ATLAS_RES,"atlas_size":[576,48],"runtime_sha256":atlas_sha,"source_trimmed":habitat_sources[index]["source_path"],"source_generated":habitat_sources[index]["source_path"],"source_model":"built_in_imagegen_original_frontier_mythic_habitat_atlas","asset_policy":"original_generated_runtime_sprite_no_homm3_art_import","distinct_sprite_assignment":True,"accessible_description":case["description"]}
        art["object_assets"][unclaimed_id] = {**common,"atlas_region":[x,0,48,48],"assigned_map_object_id":f"object_{case['stem']}","presentation_role":f"{case['stem']}_unclaimed"}
        art["object_assets"][controlled_id] = {**common,"atlas_region":[x+48,0,48,48],"assigned_resource_site_id":f"site_{case['stem']}","presentation_role":f"{case['stem']}_controlled"}
        art["object_assets"][encounter_asset_id] = {"path":f"res://art/units/overworld_icons/{case['unit_id']}.png","source_model":"built_in_imagegen_curated_original_character_unit_landmark_reuse","assigned_encounter_id":f"encounter_{case['stem']}_watch","assigned_unit_id":case["unit_id"],"asset_policy":"exact_curated_original_creature_identity","distinct_sprite_assignment":True,"accessible_description":f"The exact silhouette of {case['unit_name']} guarding {case['name']}."}
        art["resource_site_sprites"][f"site_{case['stem']}"] = {"asset_id":controlled_id,"unclaimed_asset_id":unclaimed_id,"fit":f"Exact original {case['name']} changes from unclaimed structure to pennant-marked controlled state."}
        art["encounter_identity_sprites"][f"encounter_{case['stem']}_watch"] = encounter_asset_id
        map_sprites["object_sprite_mappings"][f"object_{case['stem']}"] = {"asset_id":unclaimed_id,"fit":f"Distinct original {case['name']} unclaimed habitat assigned to its authored neutral dwelling.","assignment_source":"frontier_mythic_habitat_completion","family":"neutral_dwelling","source_batch":20}
        if unclaimed_id not in map_sprites["distinct_asset_ids"]:
            map_sprites["distinct_asset_ids"].append(unclaimed_id)
    payloads["scenarios"]["player_facing_active_scenario_count"] = len(payloads["scenarios"]["items"])
    base.write_compact(CONTENT/"units.json",payloads["units"])
    base.write_pretty(CONTENT/"neutral_dwellings.json",payloads["neutral_dwellings"])
    base.write_pretty(CONTENT/"resource_sites.json",payloads["resource_sites"])
    base.write_pretty(CONTENT/"map_objects.json",payloads["map_objects"])
    base.write_groups(CONTENT/"army_groups.json",payloads["army_groups"])
    base.write_compact(CONTENT/"encounters.json",payloads["encounters"])
    base.write_compact(CONTENT/"scenarios.json",payloads["scenarios"])
    base.write_pretty(ART_MANIFEST,art)
    map_sprites["source"]["new_generated_sprite_count"] = 222
    map_sprites["source"]["generated_batch_count"] = 20
    batch = {"batch_index":20,"workspace_source_manifest":"res://art/overworld/source/generated/resource_sites/frontier_mythic_habitats_wave1/manifest.json","object_index_range":[217,222]}
    map_sprites["source"]["generated_batches"] = [value for value in map_sprites["source"].get("generated_batches",[]) if value.get("batch_index") != 20] + [batch]
    map_sprites["coverage"]["authored_map_object_count"] = 422
    map_sprites["coverage"]["new_distinct_non_decorative_asset_count"] = 222
    map_sprites["coverage"]["total_distinct_authored_map_object_count_after_pass"] = 422
    map_sprites["coverage"]["by_family"]["neutral_dwelling"] = 69
    base.write_pretty(MAP_SPRITES,map_sprites)
    print(json.dumps({"slice_id":SLICE_ID,"counts":{key:len(value["items"]) for key,value in payloads.items()},"unit_source_count":len(unit_sources),"atlas_sha256":atlas_sha},sort_keys=True))


if __name__ == "__main__":
    main()
