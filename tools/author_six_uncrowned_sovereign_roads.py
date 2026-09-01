#!/usr/bin/env python3
"""Author The Uncrowned Circuit campaign, six sovereign roads, and original art."""

from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / "content"
SLICE_ID = "content-six-uncrowned-sovereign-roads-10184"
CAMPAIGN_ID = "campaign_uncrowned_circuit"
GENERATED = Path("/root/.codex/generated_images/019fe72a-30b1-76f3-b911-385c4444bd16")
FIELD_SOURCE = ROOT / "art/overworld/source/generated/resource_sites/uncrowned_sovereign_roads_wave1"
FIELD_ATLAS = ROOT / "art/overworld/runtime/objects/resource_sites/uncrowned_sovereign_roads_atlas.png"
FIELD_ATLAS_RES = "res://art/overworld/runtime/objects/resource_sites/uncrowned_sovereign_roads_atlas.png"
CAMPAIGN_SOURCE = ROOT / "art/campaigns/source/generated"
CAMPAIGN_RUNTIME = ROOT / "art/campaigns/runtime"
CAMPAIGN_MANIFEST = CAMPAIGN_SOURCE / "uncrowned_circuit/manifest.json"

COMMON_CAPS = {
    "gold": 650, "wood": 2, "ore": 2, "aetherglass": 0, "embergrain": 0,
    "peatwax": 0, "verdant_grafts": 0, "brass_scrip": 0, "memory_salt": 0,
}

EMBLEM = {
    "generated": "exec-c713e69a-a9de-411d-81ba-27cd4c15b6d5.png",
    "source": "uncrowned_circuit_source.png", "runtime": "uncrowned_circuit.png",
    "alt": "Six materially distinct clasps form an open bronze circuit around an empty center.",
    "prompt": "Original transparent campaign emblem: an open six-spoked bronze circuit around an empty central crown-shaped negative space; ember writ, antler drum, prism halo, root graft, pressure gauge, and drowned bell clasps; hand-painted strategy heraldry; no text, character, scenery, border, franchise reference, or watermark.",
}

CASES = [
    dict(
        scenario_id="powderwrit-cinderlock-charter-ascent", name="Cinderlock Charter Ascent", prefix="cinderlock",
        faction="faction_embercourt", enemy="faction_mireclaw", hero="hero_embercourt_maela_powderwrit",
        home="town_cinderlock_bastion", enemy_town="town_murkward_ford",
        building="building_embercourt_charter_bastion", prerequisite="building_embercourt_drake_sluice",
        unit="unit_embercourt_charter_colossus", unit_name="Charter Colossus",
        group="army_uncrowned_cinderlock_charter_company",
        units=["unit_embercourt_fordhook_cadets","unit_embercourt_lantern_sappers","unit_embercourt_beaconline_writguard","unit_embercourt_cinderseal_bombardiers","unit_embercourt_sluicefire_lindworms"],
        encounters=["encounter_blackbranch_reavers","encounter_reedward_camp","encounter_ford_reavers"],
        terrain="grass", rare_site="site_embergrain_warm_granary", rare="embergrain",
        site="site_cinderlock_open_charter_throne", site_name="Cinderlock Open Charter Throne",
        asset="resource_site_uncrowned_cinderlock_throne", source="cinderlock_open_charter_throne_source.png",
        generated="exec-576fc902-3945-414c-9960-a5030461ec92.png", bonus="defense",
        alt="A black sluice-stone seat stands beneath an open broken brass ring beside a white ember bowl.",
        prompt="Original transparent Cinderlock Open Charter Throne: blackened sluice-stone empty seat, forked brass writ arms, open broken crown ring, white ember bowl, red wax counterweight; hand-painted strategy sprite; no character, text, scenery, franchise reference, or watermark.",
        label="Chapter I: Open the Charter Seat", chapter_title="Make Authority Answer to Muster",
        description="Maela Powderwrit opens Cinderlock's charter seat by building its apex bastion and fielding a living Charter Colossus.",
        briefing="Cinderlock's claimants have polished an empty seat while leaving its charter road undefended. Maela must turn ceremony into authority by building the bastion, mustering its Colossus, and breaking every rival writ on the road.",
        victory="Cinderlock's open ring holds no crown; the Colossus answers a charter proven by work.",
    ),
    dict(
        scenario_id="reedscript-murkward-antler-ascent", name="Murkward Antler Ascent", prefix="murkward",
        faction="faction_mireclaw", enemy="faction_sunvault", hero="hero_mireclaw_pell_reedscript",
        home="town_murkward_ford", enemy_town="town_dawnmirror_observatory",
        building="building_mireclaw_antler_pit", prerequisite="building_mireclaw_nightglass_dominion",
        unit="unit_mireclaw_drowned_antler_sovereign", unit_name="Drowned Antler Sovereign",
        group="army_uncrowned_murkward_antler_company",
        units=["unit_mireclaw_reedsnare_kin","unit_mireclaw_bogplate_maulers","unit_mireclaw_fenbell_chainstalkers","unit_mireclaw_gorefen_rippers","unit_mireclaw_mireglass_reedcasters"],
        encounters=["encounter_road_chaplains","encounter_glasswing_sortie","encounter_daxis_meridian_impound"],
        terrain="swamp", rare_site="site_peatwax_reed_yard", rare="peatwax",
        site="site_murkward_antler_tribunal", site_name="Murkward Antler Tribunal",
        asset="resource_site_uncrowned_murkward_tribunal", source="murkward_antler_tribunal_source.png",
        generated="exec-0d4d3213-41a1-4bd3-ae4b-fa44035db9bc.png", bonus="attack",
        alt="Unequal drowned antlers frame a bogstone seat, hide drum, reed scales, and peat lantern.",
        prompt="Original transparent Murkward Antler Tribunal: squat bogstone empty seat, unequal drowned antler arch, hide-drum back, reed-chain scales, peat lantern; hand-painted strategy sprite; no character, text, scenery, franchise reference, or watermark.",
        label="Chapter II: Sound the Antler Verdict", chapter_title="Let the Ford Judge Its Claim",
        description="Pell Reedscript opens Murkward's tribunal by raising the Antler Pit and mustering its Drowned Sovereign.",
        briefing="A dry-road court has declared Murkward unfit to judge its own crossing. Pell must build the antler pit, field the ford's apex witness, and make the tribunal answer to those who can actually hold the drowned road.",
        victory="The drum answers beneath unequal antlers, and Murkward's verdict belongs to no distant crown.",
    ),
    dict(
        scenario_id="sevenfold-dawnmirror-daybreak-ascent", name="Dawnmirror Daybreak Ascent", prefix="dawnmirror",
        faction="faction_sunvault", enemy="faction_thornwake", hero="hero_sunvault_aven_sevenfold",
        home="town_dawnmirror_observatory", enemy_town="town_thornwake_graftroot_caravan",
        building="building_sunvault_daybreak_matrix", prerequisite="building_sunvault_aurora_spire",
        unit="unit_sunvault_daybreak_colossus", unit_name="Daybreak Colossus",
        group="army_uncrowned_dawnmirror_daybreak_company",
        units=["unit_sunvault_shard_wardens","unit_mirror_duelist","unit_aurora_ballista","unit_sunvault_aurora_ballistae","unit_sunvault_zenith_lensbearers"],
        encounters=["encounter_jessa_lockfire_boom","encounter_ilyr_ossuary_battery","encounter_helva_blackwake_levy"],
        terrain="sand", rare_site="site_aetherglass_lens_house", rare="aetherglass",
        site="site_dawnmirror_uncrowned_matrix", site_name="Dawnmirror Uncrowned Matrix",
        asset="resource_site_uncrowned_dawnmirror_matrix", source="dawnmirror_uncrowned_matrix_source.png",
        generated="exec-a6886d56-d85e-45f3-a414-a8a8293a7270.png", bonus="knowledge",
        alt="An ivory-gold seat hangs in an offset prism halo crossed by three calibration needles.",
        prompt="Original transparent Dawnmirror Uncrowned Matrix: ivory-gold empty seat, offset open prism halo, split sunrise lens, three calibration needles; hand-painted strategy sprite; no character, text, scenery, franchise reference, or watermark.",
        label="Chapter III: Align the Empty Matrix", chapter_title="Calibrate a Seat Without a Crown",
        description="Aven Sevenfold completes Dawnmirror's matrix and fields its Daybreak Colossus as proof of calibrated authority.",
        briefing="Dawnmirror's old claim is only reflected light. Aven must build the true matrix, muster the Daybreak Colossus, and align an authority that can be measured instead of inherited.",
        victory="Three needles agree around an open halo, and Dawnmirror's authority survives its own measurement.",
    ),
    dict(
        scenario_id="seedseer-graftroot-worldroot-ascent", name="Graftroot Worldroot Ascent", prefix="graftroot",
        faction="faction_thornwake", enemy="faction_brasshollow", hero="hero_thornwake_veyra_seedseer",
        home="town_thornwake_graftroot_caravan", enemy_town="town_brasshollow_orevein_gantry",
        building="building_thornwake_worldroot_gate", prerequisite="building_thornwake_graftworks",
        unit="unit_thornwake_worldroot_bastion", unit_name="Worldroot Bastion",
        group="army_uncrowned_graftroot_worldroot_company",
        units=["unit_thornwake_seedcutters","unit_thornwake_canopy_rammers","unit_thornwake_dawnseed_bolters","unit_thornwake_graft_matriarchs","unit_thornwake_stagknot_runners"],
        encounters=["encounter_damar_worldroot_wake","encounter_reedcaller_redgauge_commission","encounter_sevenfold_rootmirror_commission"],
        terrain="grass", rare_site="site_verdant_graft_nursery", rare="verdant_grafts",
        site="site_graftroot_living_dais", site_name="Graftroot Living Dais",
        asset="resource_site_uncrowned_graftroot_dais", source="graftroot_living_dais_source.png",
        generated="exec-b9a1d639-15b5-4b86-a32a-ff68077037c7.png", bonus="defense",
        alt="A living root seat grows beneath unequal flowering boughs, two seed lamps, and a graft spool.",
        prompt="Original transparent Graftroot Living Dais: empty root-woven seat, unequal flowering boughs, seed lamps, graft spool; hand-painted strategy sprite; no character, text, scenery, franchise reference, or watermark.",
        label="Chapter IV: Grow the Living Dais", chapter_title="Prove a Claim That Can Change",
        description="Veyra Seedseer grows the Worldroot Gate and fields its Bastion before the caravan's living dais.",
        briefing="A fixed throne cannot govern a town that migrates with the seasons. Veyra must grow the Worldroot Gate, muster its Bastion, and prove that Graftroot can change without surrendering its road.",
        victory="The living dais flowers without a crown, rooted by a Bastion that moves when the caravan moves.",
    ),
    dict(
        scenario_id="blackgauge-orevein-foundry-ascent", name="Orevein Foundry Ascent", prefix="orevein",
        faction="faction_brasshollow", enemy="faction_veilmourn", hero="hero_brasshollow_kestra_blackgauge",
        home="town_brasshollow_orevein_gantry", enemy_town="town_veilmourn_bellwake_harbor",
        building="building_brasshollow_titan_charter_hall", prerequisite="building_brasshollow_crucible_dock",
        unit="unit_brasshollow_foundry_saint", unit_name="Foundry Saint",
        group="army_uncrowned_orevein_foundry_company",
        units=["unit_brasshollow_tallyspring_throwers","unit_brasshollow_rivet_hounds","unit_brasshollow_whitegauge_datum_breach_cannons","unit_brasshollow_crucible_crawlers","unit_brasshollow_pressure_lancers"],
        encounters=["encounter_boltroot_lockfire_commission","encounter_red_ledger_pile_driver","encounter_deepforge_seventh_seal_watch"],
        terrain="dirt", rare_site="site_brass_scrip_mint", rare="brass_scrip",
        site="site_orevein_saintless_assay_seat", site_name="Orevein Saintless Assay Seat",
        asset="resource_site_uncrowned_orevein_assay_seat", source="orevein_saintless_assay_seat_source.png",
        generated="exec-7a9bf88e-2b3f-4ae7-bd0c-5a17987b19f4.png", bonus="power",
        alt="A basalt and brass assay seat carries three gauges, an open clamp, and a red relief valve.",
        prompt="Original transparent Orevein Saintless Assay Seat: empty basalt-brass industrial throne, three pressure gauges, riveted rails, open crown clamp, red relief valve; hand-painted strategy sprite; no character, text, scenery, franchise reference, or watermark.",
        label="Chapter V: Assay the Saintless Seat", chapter_title="Make Every Claim Bear Its Cost",
        description="Kestra Blackgauge charters Orevein's apex hall and fields a Foundry Saint before the open assay seat.",
        briefing="Orevein's ledgers name a saint before anyone has paid the work's true cost. Kestra must build the charter hall, muster the Foundry Saint, and put the entire claim under pressure.",
        victory="Three gauges settle below redline; Orevein recognizes the work and leaves the crown clamp open.",
    ),
    dict(
        scenario_id="keelwarden-bellwake-leviathan-ascent", name="Bellwake Leviathan Ascent", prefix="bellwake",
        faction="faction_veilmourn", enemy="faction_embercourt", hero="hero_veilmourn_jessa_keelwarden",
        home="town_veilmourn_bellwake_harbor", enemy_town="town_cinderlock_bastion",
        building="building_veilmourn_leviathan_sounding", prerequisite="building_veilmourn_mistgate_slip",
        unit="unit_veilmourn_fogbound_leviathan", unit_name="Fogbound Leviathan",
        group="army_uncrowned_bellwake_leviathan_company",
        units=["unit_veilmourn_saltbell_casters","unit_veilmourn_wakechain_boarders","unit_veilmourn_saltwake_eulogists","unit_veilmourn_mirrorkeel_reavers","unit_veilmourn_gloamkeel_bulwarks"],
        encounters=["encounter_sunscale_lantern_drift_watch","encounter_rootvault_heartwood_watch","encounter_saltwake_belldeep_watch"],
        terrain="snow", rare_site="site_memory_salt_pan", rare="memory_salt",
        site="site_bellwake_empty_sounding_chair", site_name="Bellwake Empty Sounding Chair",
        asset="resource_site_uncrowned_bellwake_sounding_chair", source="bellwake_empty_sounding_chair_source.png",
        generated="exec-00221d34-ce49-496f-a7de-8e6f67e84769.png", bonus="knowledge",
        alt="Whalebone and blackwood frame an empty tide chair beneath shroud sails, a drowned bell, and three chimes.",
        prompt="Original transparent Bellwake Empty Sounding Chair: whalebone-blackwood empty tide chair, shroud sails, drowned bell, three memory chimes, crown-shaped negative space; hand-painted strategy sprite; no character, text, scenery, franchise reference, or watermark.",
        label="Chapter VI: Sound the Empty Chair", chapter_title="Close the Circuit Without Closing the Crown",
        description="Jessa Keelwarden completes Bellwake's sounding and fields its Fogbound Leviathan to close the six-road circuit.",
        briefing="Five open seats now answer to witnessed work. Jessa must complete the Leviathan Sounding, call its apex witness from the fog, and close the circuit without placing a crown at its center.",
        victory="The drowned bell sounds through six open claims; the circuit closes while its center remains free.",
        rival="hero_embercourt_orra_cinderquill",
    ),
]


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def save(path: Path, payload) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.name in {"scenarios.json", "campaigns.json"}:
        text = json.dumps(payload, ensure_ascii=False, separators=(",", ":"))
    else:
        text = json.dumps(payload, indent=2, ensure_ascii=False)
        if path.name == "army_groups.json":
            text = re.sub(r'        \{\n          "unit_id": ("[^"]+"),\n          "count": (\d+)\n        \}', r'        {"unit_id": \1, "count": \2}', text)
    path.write_text(text + "\n", encoding="utf-8")


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def replace_batch(items: list, additions: list) -> None:
    ids = {row["id"] for row in additions}
    items[:] = [row for row in items if row.get("id") not in ids]
    items.extend(additions)


def curate(original_name: str, source_path: Path, canvas: int = 512) -> Image.Image:
    image = Image.open(GENERATED / original_name).convert("RGBA")
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError(f"Generated source has no visible alpha: {original_name}")
    image = image.crop(bbox)
    image.thumbnail((canvas - 34, canvas - 34), Image.Resampling.LANCZOS)
    master = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    master.alpha_composite(image, ((canvas - image.width) // 2, (canvas - image.height) // 2))
    source_path.parent.mkdir(parents=True, exist_ok=True)
    master.save(source_path, optimize=True)
    return master


def make_art() -> tuple[list[dict], str]:
    tiles = []
    rows = []
    for index, case in enumerate(CASES):
        source_path = FIELD_SOURCE / case["source"]
        master = curate(case["generated"], source_path)
        tiles.append(master.resize((48, 48), Image.Resampling.LANCZOS))
        rows.append({"site_id": case["site"], "asset_id": case["asset"], "source_file": case["source"], "source_sha256": digest(source_path), "atlas_region": [index * 48, 0, 48, 48], "prompt": case["prompt"]})
    atlas = Image.new("RGBA", (288, 48), (0, 0, 0, 0))
    for index, tile in enumerate(tiles):
        atlas.alpha_composite(tile, (index * 48, 0))
    FIELD_ATLAS.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(FIELD_ATLAS, optimize=True)
    atlas_sha = digest(FIELD_ATLAS)
    save(FIELD_SOURCE / "manifest.json", {"content_batch_id": SLICE_ID, "source_model": "built_in_image_gen_original_uncrowned_sovereign_roads", "generation_mode": "built_in_image_gen", "runtime_atlas": FIELD_ATLAS_RES, "runtime_atlas_size": [288, 48], "runtime_atlas_sha256": atlas_sha, "items": rows})

    emblem_source = CAMPAIGN_SOURCE / "emblems" / EMBLEM["source"]
    emblem_runtime = CAMPAIGN_RUNTIME / "emblems" / EMBLEM["runtime"]
    emblem_master = curate(EMBLEM["generated"], emblem_source, 1254)
    emblem_runtime.parent.mkdir(parents=True, exist_ok=True)
    emblem_master.resize((128, 128), Image.Resampling.LANCZOS).save(emblem_runtime, optimize=True)
    for case in CASES:
        throne_master = Image.open(FIELD_SOURCE / case["source"]).convert("RGBA")
        seal_source = CAMPAIGN_SOURCE / "chapter_seals" / f"uncrowned_{case['prefix']}_source.png"
        seal_path = CAMPAIGN_RUNTIME / "chapter_seals" / f"uncrowned_{case['prefix']}.png"
        seal_source.parent.mkdir(parents=True, exist_ok=True)
        seal_path.parent.mkdir(parents=True, exist_ok=True)
        seal_content = throne_master.resize((1080, 1080), Image.Resampling.LANCZOS)
        seal_master = Image.new("RGBA", (1254, 1254), (0, 0, 0, 0))
        seal_master.alpha_composite(seal_content, (87, 87))
        seal_master.save(seal_source, optimize=True)
        seal_master.resize((64, 64), Image.Resampling.LANCZOS).save(seal_path, optimize=True)
    return rows, atlas_sha


def terrain_map(base: str, index: int) -> list[list[str]]:
    terrain = [[base for _ in range(20)] for _ in range(12)]
    accents = ["dirt", "grass", "sand", "swamp", "dirt", "snow"]
    for x in range(20):
        terrain[6][x] = "dirt"
        if x % 3 == index % 3:
            terrain[3][x] = accents[(index + 1) % len(accents)]
        if x % 4 == (index + 1) % 4:
            terrain[9][x] = accents[(index + 2) % len(accents)]
    return terrain


def make_group(case: dict) -> dict:
    return {"id": case["group"], "name": f"{case['name']} Company", "faction_id": case["faction"], "stacks": [{"unit_id": unit_id, "count": count} for unit_id, count in zip(case["units"], [58, 34, 20, 10, 4])], "content_batch_id": SLICE_ID}


def make_scenario(case: dict, index: int) -> dict:
    p = case["prefix"]
    resources = [
        ("wood_one", "site_wood_wagon", 2, 2), ("ore_one", "site_ore_crates", 4, 9),
        ("gold_one", "site_payroll_casket", 7, 2), ("rare_one", case["rare_site"], 9, 9),
        ("wood_two", "site_wood_wagon", 11, 2), ("ore_two", "site_ore_crates", 13, 9),
        ("exchange", "site_frontier_rare_exchange", 15, 2), ("gold_two", "site_payroll_casket", 18, 9),
        ("throne", case["site"], 16, 8),
    ]
    victory = [
        *[{"id": f"{p}_clear_front_{i + 1}", "label": f"Break sovereign front {i + 1}", "type": "encounter_resolved", "placement_id": f"{p}_front_{i + 1}"} for i in range(3)],
        {"id": f"{p}_build_apex", "label": f"Build {case['building'].replace('building_', '').replace('_', ' ').title()}", "type": "building_built_in_player_town", "placement_id": f"{p}_home", "building_id": case["building"]},
        {"id": f"{p}_muster_apex", "label": f"Field one {case['unit_name']}", "type": "hero_army_meets_requirements", "hero_id": case["hero"], "requirements": [{"unit_id": case["unit"], "minimum_count": 1}]},
        {"id": f"{p}_claim_throne", "label": f"Claim {case['site_name']}", "type": "flag_true", "flag": f"uncrowned_{p}_throne_claimed"},
        {"id": f"{p}_take_rival_town", "label": "Take the rival sovereign town", "type": "town_owned_by_player", "placement_id": f"{p}_enemy"},
    ]
    hooks = [
        {"id": f"{p}_first_front_relief", "priority": 140, "conditions": [{"type": "objective_met", "objective_id": f"{p}_clear_front_1"}], "effects": [{"type": "add_resources", "resources": {"gold": 900, "wood": 2, "ore": 2}}, {"type": "message", "text": "The first claimant front yields charter stores."}]},
        {"id": f"{p}_second_front_recruits", "priority": 130, "conditions": [{"type": "objective_met", "objective_id": f"{p}_clear_front_2"}], "effects": [{"type": "town_add_recruits", "placement_id": f"{p}_home", "recruits": {case["units"][1]: 5}}, {"type": "message", "text": "The second road victory releases veteran reserves to the home muster."}]},
        {"id": f"{p}_apex_witness", "priority": 120, "conditions": [{"type": "objective_met", "objective_id": f"{p}_muster_apex"}], "effects": [{"type": "set_flag", "flag": f"uncrowned_{p}_witness_entered", "value": True}, {"type": "message", "text": case["victory"]}]},
        {"id": f"{p}_day_ten_reserve", "priority": 80, "conditions": [{"type": "day_at_least", "day": 10}, {"type": "objective_not_met", "objective_id": f"{p}_clear_front_3"}], "effects": [{"type": "spawn_encounter", "placement": {"placement_id": f"{p}_late_reserve", "encounter_id": case["encounters"][1], "x": 18, "y": 10, "difficulty": "high", "spawned_by_faction_id": case["enemy"], "days_active": 0, "arrived": False, "goal_distance": 9999}}, {"type": "message", "text": "A late claimant reserve enters the outer sovereign road."}]},
        {"id": f"{p}_late_pressure", "priority": 70, "conditions": [{"type": "day_at_least", "day": 15}, {"type": "objective_not_met", "objective_id": f"{p}_take_rival_town"}], "effects": [{"type": "add_enemy_pressure", "faction_id": case["enemy"], "amount": 3}, {"type": "message", "text": "The rival seat presses its unfinished claim."}]},
    ]
    return {
        "id": case["scenario_id"], "name": case["name"],
        "selection": {"summary": f"Build the apex town project, muster a {case['unit_name']}, clear three fronts, claim the open throne, and capture the rival seat.", "recommended_difficulty": "hard", "map_size_label": "Uncrowned Sovereign Road (20x12)", "player_summary": "A five-stack company begins beside a prepared town, but must complete and recruit its live Tier-7 authority.", "enemy_summary": "Three distinct claimant fronts and an opposing town contest a long sovereign road.", "availability": {"campaign": True, "skirmish": True}},
        "map_size": {"width": 20, "height": 12}, "player_faction_id": case["faction"], "player_army_id": case["group"], "hero_id": case["hero"],
        "starting_resources": {"gold": 20000, "wood": 20, "ore": 20, "embergrain": 14, "aetherglass": 14, "peatwax": 14, "verdant_grafts": 14, "brass_scrip": 14, "memory_salt": 14},
        "map": terrain_map(case["terrain"], index), "start": {"x": 1, "y": 6}, "hero_starts": [case["hero"]],
        "objectives": {"victory_text": case["victory"], "defeat_text": "The home seat, commander, sovereign road pressure, or Day 24 deadline ends the ascent.", "victory": victory, "defeat": [{"id": f"{p}_lose_home", "label": "Keep the home sovereign town", "type": "town_not_owned_by_player", "placement_id": f"{p}_home"}, {"id": f"{p}_lose_hero", "label": "The sovereign witness must survive", "type": "session_flag_equals", "flag": "campaign", "value": "defeat"}, {"id": f"{p}_pressure", "label": "Keep claimant pressure below 34", "type": "enemy_pressure_at_least", "faction_id": case["enemy"], "threshold": 34}, {"id": f"{p}_deadline", "label": "Complete the ascent before Day 24", "type": "day_at_least", "day": 24}]},
        "script_hooks": hooks,
        "towns": [{"placement_id": f"{p}_home", "town_id": case["home"], "x": 0, "y": 6, "owner": "player", "built_buildings": ["building_market_square", case["prerequisite"]], "recovery": {"pressure": 2, "source": "uncrowned sovereign home"}}, {"placement_id": f"{p}_enemy", "town_id": case["enemy_town"], "x": 19, "y": 6, "owner": "enemy"}],
        "enemy_factions": [{"faction_id": case["enemy"], "label": "Uncrowned Claimants", "pressure_per_day": 1, "pressure_per_enemy_town": 1, "raid_threshold": 12, "max_active_raids": 1, "raid_pillage_delay": 3, "raid_pillage": {"gold": 300}, "raid_encounter_ids": [case["encounters"][0]], "spawn_points": [{"x": 19, "y": 1}], "siege_target_placement_id": f"{p}_home", "siege_active_raid_threshold": 2, "siege_capture_progress": 2, "priority_target_placement_ids": [f"{p}_throne", f"{p}_home"]}],
        "resource_nodes": [{"placement_id": f"{p}_{label}", "site_id": site_id, "x": x, "y": y, **({"guard_front_id": f"{p}_front_3"} if label == "throne" else {})} for label, site_id, x, y in resources],
        "artifact_nodes": [],
        "encounters": [{"placement_id": f"{p}_front_{i + 1}", "encounter_id": encounter_id, "x": x, "y": y, "difficulty": ["medium", "high", "high"][i], "combat_seed": 49100 + index * 10 + i, "prefer_identity_landmark": True, "guardian_role": ["sovereign_road_vanguard", "sovereign_claim_examiner", "uncrowned_throne_guard"][i], **({"enemy_commander_state": {"roster_hero_id": case["rival"], "faction_id": case["enemy"]}} if i == 2 and case.get("rival") else {})} for i, (encounter_id, x, y) in enumerate(zip(case["encounters"], [5, 11, 15], [3, 6, 8]))],
        "content_status": "uncrowned_sovereign_road_live", "content_batch_id": SLICE_ID, "scenario_family": "uncrowned_sovereign_road", "deterministic_seed": 49100 + index * 10,
        "uncrowned_sovereign_road": {"campaign_id": CAMPAIGN_ID, "chapter_index": index + 1, "town_id": case["home"], "building_id": case["building"], "unit_id": case["unit"], "site_id": case["site"], "witness_flag": f"uncrowned_{p}_witness_entered", "save_version": 9},
    }


def campaign_chapter(index: int, case: dict) -> dict:
    source_path = CAMPAIGN_SOURCE / "chapter_seals" / f"uncrowned_{case['prefix']}_source.png"
    seal_path = CAMPAIGN_RUNTIME / "chapter_seals" / f"uncrowned_{case['prefix']}.png"
    row = {
        "scenario_id": case["scenario_id"], "seal_id": f"campaign_chapter_seal_{case['scenario_id'].replace('-', '_')}",
        "seal_path": f"res://art/campaigns/runtime/chapter_seals/uncrowned_{case['prefix']}.png",
        "seal_source_path": f"res://art/campaigns/source/generated/chapter_seals/uncrowned_{case['prefix']}_source.png",
        "seal_alt_text": case["alt"], "seal_source_sha256": digest(source_path), "seal_runtime_sha256": digest(seal_path),
        "label": case["label"], "description": case["description"], "chapter_index": index + 1,
        "chapter_title": case["chapter_title"], "status_hint": f"Clear three fronts, build the apex project, muster one {case['unit_name']}, claim the open seat, and take the rival town.",
        "carryover_summary": "Only the witnessed claim and capped common stores cross the handoff; commander growth, army stacks, spells, artifacts, and rare resources remain local.",
        "briefing": case["briefing"], "intel": "The third claimant front guards the open seat. The chapter witness is entered only after the exact apex unit joins the commander's live army.",
        "stakes": "An empty seat without built authority is pageantry; authority without a living witness is only a ledger claim.",
        "aftermath_victory": case["victory"], "aftermath_defeat": "The road closes around an empty claim and the circuit loses this spoke.",
        "journal_victory": case["victory"], "journal_defeat": "The open seat remains unproven.",
    }
    if index == 0:
        row["starts_unlocked"] = True
    else:
        previous = CASES[index - 1]
        row["unlock_requirements"] = [{"type": "scenario_status", "scenario_id": previous["scenario_id"], "status": "victory"}, {"type": "scenario_flag_true", "scenario_id": previous["scenario_id"], "flag": f"uncrowned_{previous['prefix']}_witness_entered"}]
        row["carryover_import"] = {"from_scenario_id": previous["scenario_id"], "resources": True, "hero_progression": False, "spells": False, "artifacts": False, "flags_prefix": "carryover_"}
    if index < len(CASES) - 1:
        row["carryover_export"] = {"retain_hero_progression": False, "retain_spells": False, "retain_artifacts": False, "resource_fraction": 0.12, "resource_caps": COMMON_CAPS, "flag_ids": [f"uncrowned_{case['prefix']}_witness_entered"]}
    return row


def main() -> None:
    art_rows, atlas_sha = make_art()

    scenarios = load(CONTENT / "scenarios.json")
    replace_batch(scenarios["items"], [make_scenario(case, index) for index, case in enumerate(CASES)])
    scenarios["player_facing_active_scenario_count"] = len(scenarios["items"])
    save(CONTENT / "scenarios.json", scenarios)

    groups = load(CONTENT / "army_groups.json")
    replace_batch(groups["items"], [make_group(case) for case in CASES])
    save(CONTENT / "army_groups.json", groups)

    sites = load(CONTENT / "resource_sites.json")
    additions = []
    for case in CASES:
        p = case["prefix"]
        additions.append({"id": case["site"], "name": case["site_name"], "family": "scenario_objective", "action_label": "Witness the Open Seat", "summary": case["alt"], "claim_rewards": {"experience": 240, case["rare"]: 2}, "hero_command_bonus": {case["bonus"]: 1}, "claim_flags": {f"uncrowned_{p}_throne_claimed": True}, "runtime_boundary": {"status": "objective_event_live", "live_reward_grants": True, "save_payload_required": True, "renderer_sprite_required": True, "pathing_runtime_adopted": True, "route_effect_runtime_adopted": False, "rare_resource_activation": True, "scenario_placement_migration": True}, "objective_event_contract": {"objective_kind": "uncrowned_sovereign_throne", "event_expectation": "raises the exact chapter throne flag through the live site claim action", "scenario_id": case["scenario_id"], "objective_id": f"{p}_claim_throne", "metadata_only": False, "live_objective_runtime": True}, "content_status": "uncrowned_sovereign_throne_live", "content_batch_id": SLICE_ID, "public_text": {"public_summary": case["alt"], "no_internal_debug_score_fields": True, "large_text_panel_required": False}})
    replace_batch(sites["items"], additions)
    save(CONTENT / "resource_sites.json", sites)

    manifest = load(ROOT / "art/overworld/manifest.json")
    for index, case in enumerate(CASES):
        manifest["object_assets"][case["asset"]] = {"path": FIELD_ATLAS_RES, "atlas_region": [index * 48, 0, 48, 48], "atlas_size": [288, 48], "source_trimmed": f"res://art/overworld/source/generated/resource_sites/uncrowned_sovereign_roads_wave1/{case['source']}", "source_generated": f"res://art/overworld/source/generated/resource_sites/uncrowned_sovereign_roads_wave1/{case['source']}", "source_model": "built_in_image_gen_original_uncrowned_sovereign_roads", "assigned_resource_site_id": case["site"], "presentation_role": "uncrowned_sovereign_field_throne", "accessible_description": case["alt"], "background": "transparent"}
        manifest["resource_site_sprites"][case["site"]] = {"asset_id": case["asset"], "unclaimed_asset_id": case["asset"], "fit": f"Exact original {case['site_name']} remains visible before and after its witnessed claim."}
    save(ROOT / "art/overworld/manifest.json", manifest)

    campaigns = load(CONTENT / "campaigns.json")
    emblem_source = CAMPAIGN_SOURCE / "emblems" / EMBLEM["source"]
    emblem_runtime = CAMPAIGN_RUNTIME / "emblems" / EMBLEM["runtime"]
    campaign = {"id": CAMPAIGN_ID, "name": "The Uncrowned Circuit", "description": "Six commanders prove six open seats through live town construction, apex recruitment, field victories, and witnessed claims, closing a circuit whose center deliberately remains uncrowned.", "summary": "A six-chapter cross-faction campaign joining real Tier-7 town building and muster play to six large sovereign roads.", "region": "The Six Open Seats", "emblem_id": "campaign_emblem_uncrowned_circuit", "emblem_path": "res://art/campaigns/runtime/emblems/uncrowned_circuit.png", "emblem_source_path": "res://art/campaigns/source/generated/emblems/uncrowned_circuit_source.png", "emblem_alt_text": EMBLEM["alt"], "emblem_source_sha256": digest(emblem_source), "emblem_runtime_sha256": digest(emblem_runtime), "arc_goal": "Build each town's apex project, recruit its exact Tier-7 witness, claim its open field seat, and carry only a bounded common-store record to the next independent commander.", "completion_title": "Six Seats, No Crown", "completion_summary": "Every spoke has a built authority and living witness. The circuit closes around an empty center so no victory can become a permanent inherited crown.", "starting_scenario_id": CASES[0]["scenario_id"], "scenarios": [campaign_chapter(index, case) for index, case in enumerate(CASES)], "content_batch_id": SLICE_ID, "content_status": "uncrowned_circuit_campaign_live"}
    replace_batch(campaigns["items"], [campaign])
    campaigns["player_facing_active_campaign_count"] = len(campaigns["items"])
    campaigns["reactivation_reason"] = "uncrowned_circuit_campaign_2026_09_01"
    save(CONTENT / "campaigns.json", campaigns)

    assets = [{"id": "campaign_emblem_uncrowned_circuit", "role": "campaign_emblem", "source_path": "res://art/campaigns/source/generated/emblems/uncrowned_circuit_source.png", "runtime_path": "res://art/campaigns/runtime/emblems/uncrowned_circuit.png", "source_sha256": digest(emblem_source), "runtime_sha256": digest(emblem_runtime), "non_color_identity": EMBLEM["alt"]}]
    for case in CASES:
        source = CAMPAIGN_SOURCE / "chapter_seals" / f"uncrowned_{case['prefix']}_source.png"
        runtime = CAMPAIGN_RUNTIME / "chapter_seals" / f"uncrowned_{case['prefix']}.png"
        assets.append({"id": f"campaign_chapter_seal_{case['scenario_id'].replace('-', '_')}", "role": "chapter_seal", "source_path": f"res://art/campaigns/source/generated/chapter_seals/uncrowned_{case['prefix']}_source.png", "runtime_path": f"res://art/campaigns/runtime/chapter_seals/uncrowned_{case['prefix']}.png", "source_sha256": digest(source), "runtime_sha256": digest(runtime), "non_color_identity": case["alt"]})
    CAMPAIGN_MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    CAMPAIGN_MANIFEST.write_text(json.dumps({"schema_id": "uncrowned_circuit_campaign_art_v1", "content_batch_id": SLICE_ID, "generator_mode": "built_in_image_gen", "generated_at": "2026-09-01", "campaign_id": CAMPAIGN_ID, "runtime_pipeline": "Six transparent throne masters are alpha-trimmed onto 512px source canvases, packed into one 288x48 field atlas, and reused as six 64px chapter seals. A separately generated emblem is alpha-trimmed onto a 1254px source master and downscaled to 128px. Source masters are excluded from release packages.", "generated_originals": [str(GENERATED / EMBLEM["generated"]), *[str(GENERATED / case["generated"]) for case in CASES]], "prompts": [EMBLEM["prompt"], *[case["prompt"] for case in CASES]], "assets": assets}, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"slice": SLICE_ID, "scenarios": len(scenarios["items"]), "groups": len(groups["items"]), "sites": len(sites["items"]), "campaigns": len(campaigns["items"]), "atlas_sha256": atlas_sha}, indent=2))


if __name__ == "__main__":
    main()
