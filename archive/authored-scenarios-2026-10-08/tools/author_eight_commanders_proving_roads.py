#!/usr/bin/env python3
"""Author the Eight Commanders' Proving Roads production content batch."""

from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path

from PIL import Image, ImageOps


ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / "content"
SOURCE_ROOT = ROOT / "art/overworld/source/generated/resource_sites/eight_commanders_proving_roads_wave1"
ATLAS_PATH = ROOT / "art/overworld/runtime/objects/resource_sites/eight_commanders_proving_roads_atlas.png"
ATLAS_RES = "res://art/overworld/runtime/objects/resource_sites/eight_commanders_proving_roads_atlas.png"
SOURCE_RES = "res://art/overworld/source/generated/resource_sites/eight_commanders_proving_roads_wave1"
ART_MANIFEST = ROOT / "art/overworld/manifest.json"
SLICE_ID = "content-eight-commanders-proving-roads-10184"
GENERATOR_ROOT = Path("/root/.codex/generated_images/019fe72a-30b1-76f3-b911-385c4444bd16")


CASES = [
    {
        "prefix": "orenproof", "scenario_id": "bellfounder-three-hammer-proving-road", "scenario_name": "Bellfounder Three-Hammer Proving Road",
        "hero_id": "hero_brasshollow_oren_bellfounder", "faction_id": "faction_brasshollow", "town_id": "town_cindercoil_foundry",
        "enemy_faction_id": "faction_veilmourn", "enemy_label": "Pale-Sounding Examiners", "encounter_id": "encounter_last_bell_tideglass_reliquary",
        "site_id": "site_bellfounder_three_hammer_rostrum", "site_name": "Bellfounder Three-Hammer Rostrum", "asset_id": "resource_site_proving_road_bellfounder_rostrum",
        "source_name": "bellfounder_three_hammer_rostrum_source.png", "generation_original": "exec-c80927ff-7cdb-43b1-bad2-0413d6ccd333.png",
        "action_label": "Ring the Three-Hammer Measure", "command_key": "attack", "rare_site_id": "site_brass_scrip_mint", "terrain": ("rough", "lava"), "seed": 49100,
        "subject": "a squat asymmetrical black-iron pressure gantry carrying an oversized foundry bell, three visibly different square striking hammers, one broken cog, and a narrow heat vent",
        "description": "A squat pressure gantry carries one oversized bell, three unequal square hammers, a broken base cog, and a narrow vent, readable by its broad stepped silhouette.",
    },
    {
        "prefix": "pavaproof", "scenario_id": "ashmeter-cinder-measure-proving-road", "scenario_name": "Ashmeter Cinder-Measure Proving Road",
        "hero_id": "hero_brasshollow_pava_ashmeter", "faction_id": "faction_brasshollow", "town_id": "town_blackbell_foundry",
        "enemy_faction_id": "faction_veilmourn", "enemy_label": "Ghost-Mooring Examiners", "encounter_id": "encounter_horizon_pale_sounding_ghost_mooring",
        "site_id": "site_ashmeter_cinder_measure_crucible", "site_name": "Ashmeter Cinder-Measure Crucible", "asset_id": "resource_site_proving_road_ashmeter_crucible",
        "source_name": "ashmeter_cinder_measure_crucible_source.png", "generation_original": "exec-efbb80eb-a636-4e33-8e21-6cd99b4b615d.png",
        "action_label": "Take the Cinder Measure", "command_key": "power", "rare_site_id": "site_brass_scrip_mint", "terrain": ("rough", "lava"), "seed": 49200,
        "subject": "a tilted broad ceramic crucible in an asymmetrical brass cradle, a tall spiral ash condenser, three unequal measuring scoops, a crooked slag channel, and one pressure pipe",
        "description": "A tilted broad crucible rises beside one spiral condenser, three unequal measuring scoops, and a crooked slag channel, forming a tall hooked silhouette.",
    },
    {
        "prefix": "vellumproof", "scenario_id": "quench-three-cycle-proving-road", "scenario_name": "Quench Three-Cycle Proving Road",
        "hero_id": "hero_brasshollow_vellum_quench", "faction_id": "faction_brasshollow", "town_id": "town_brasshollow_orevein_gantry",
        "enemy_faction_id": "faction_veilmourn", "enemy_label": "Saltwake Board Examiners", "encounter_id": "encounter_horizon_court_pale_saltwake_board",
        "site_id": "site_quench_three_cycle_calibrator", "site_name": "Quench Three-Cycle Calibrator", "asset_id": "resource_site_proving_road_quench_calibrator",
        "source_name": "quench_three_cycle_calibrator_source.png", "generation_original": "exec-864d1686-4a18-4b00-bdb3-f1e1ebf49d88.png",
        "action_label": "Resolve the Three Cooling Cycles", "command_key": "knowledge", "rare_site_id": "site_brass_scrip_mint", "terrain": ("rough", "dirt"), "seed": 49300,
        "subject": "an upright blank book-shaped brass ledger plate surrounded by three uneven cooling coils, a long drip valve, two offset radiator fins, and a suspended quench bowl",
        "description": "Three nested cooling coils wrap a blank upright ledger plate between offset radiator fins, a long drip valve, and one hanging quench bowl.",
    },
    {
        "prefix": "orrikproof", "scenario_id": "tollreaver-deep-muster-proving-road", "scenario_name": "Tollreaver Deep-Muster Proving Road",
        "hero_id": "hero_orrik", "faction_id": "faction_mireclaw", "town_id": "town_reedbarrow_ferry",
        "enemy_faction_id": "faction_sunvault", "enemy_label": "Zenith-Wire Examiners", "encounter_id": "encounter_zenith_wire_crucible",
        "site_id": "site_tollreaver_deep_muster_toll", "site_name": "Tollreaver Deep-Muster Toll", "asset_id": "resource_site_proving_road_tollreaver_toll",
        "source_name": "tollreaver_deep_muster_toll_source.png", "generation_original": "exec-0fc70441-dca4-473d-bfdb-2fb39fd82beb.png",
        "action_label": "Sound the Deep Muster", "command_key": "defense", "rare_site_id": "site_peatwax_reed_yard", "terrain": ("mire", "swamp"), "seed": 49400,
        "subject": "a low crescent marsh toll arch wrapped with two chained hide drums, three unequal hanging tally cages, a forked reed finial, and a heavy hooked counterweight",
        "description": "A low crescent toll arch bears two side drums, three hanging tally cages, a forked reed crown, and a heavy hooked counterweight.",
    },
    {
        "prefix": "veyraproof", "scenario_id": "seedseer-root-future-proving-road", "scenario_name": "Seedseer Root-Future Proving Road",
        "hero_id": "hero_thornwake_veyra_seedseer", "faction_id": "faction_thornwake", "town_id": "town_thornwake_rootgate_nursery",
        "enemy_faction_id": "faction_brasshollow", "enemy_label": "Seventh-Clause Examiners", "encounter_id": "encounter_seventh_clause_reliquary",
        "site_id": "site_seedseer_root_future_oracle", "site_name": "Seedseer Root-Future Oracle", "asset_id": "resource_site_proving_road_seedseer_oracle",
        "source_name": "seedseer_root_future_oracle_source.png", "generation_original": "exec-a9450797-c935-4cfc-b338-d1076de52b98.png",
        "action_label": "Read the Three Seed Futures", "command_key": "power", "rare_site_id": "site_verdant_graft_nursery", "terrain": ("forest", "grass"), "seed": 49500,
        "subject": "a forked living-root oracle stand cradling three differently shaped seed lenses, a long root pendulum, an open budding crown, and one carved grafting stone",
        "description": "A forked living root lifts three differently shaped seed lenses above one hanging pendulum and a carved grafting stone, with an open budding crown.",
    },
    {
        "prefix": "nacreproof", "scenario_id": "vowless-broken-retort-proving-road", "scenario_name": "Vowless Broken-Retort Proving Road",
        "hero_id": "hero_veilmourn_nacre_vowless", "faction_id": "faction_veilmourn", "town_id": "town_pale_sounding_harbor",
        "enemy_faction_id": "faction_embercourt", "enemy_label": "Ashwrit Examiners", "encounter_id": "encounter_ashwrit_sapfire_tower",
        "site_id": "site_vowless_broken_retort_mirror", "site_name": "Vowless Broken-Retort Mirror", "asset_id": "resource_site_proving_road_vowless_mirror",
        "source_name": "vowless_broken_retort_mirror_source.png", "generation_original": "exec-b15ceab6-2b13-4001-b74f-06a26c22b3a1.png",
        "action_label": "Face the Broken Retort", "command_key": "knowledge", "rare_site_id": "site_memory_salt_pan", "terrain": ("snow", "mire"), "seed": 49600,
        "subject": "a tall cracked oval mourning mirror on an asymmetrical whalebone stand, with a missing glass wedge, three snapped oath cords, a funerary bowl, and one shell counterweight",
        "description": "A tall cracked oval mirror with one missing wedge stands between two unequal bone uprights above a shallow bowl and three visibly snapped cords.",
    },
    {
        "prefix": "rulnproof", "scenario_id": "vanehook-three-line-proving-road", "scenario_name": "Vanehook Three-Line Proving Road",
        "hero_id": "hero_veilmourn_ruln_vanehook", "faction_id": "faction_veilmourn", "town_id": "town_veilmourn_fogchart_mooring",
        "enemy_faction_id": "faction_sunvault", "enemy_label": "Noonwire Examiners", "encounter_id": "encounter_horizon_court_meridian_noonwire_tribunal",
        "site_id": "site_vanehook_three_line_harpoon", "site_name": "Vanehook Three-Line Harpoon Frame", "asset_id": "resource_site_proving_road_vanehook_harpoon",
        "source_name": "vanehook_three_line_harpoon_source.png", "generation_original": "exec-a753b7fc-14bb-4921-8257-23d81129fdc7.png",
        "action_label": "Break the Three Practice Lines", "command_key": "attack", "rare_site_id": "site_memory_salt_pan", "terrain": ("snow", "mire"), "seed": 49700,
        "subject": "a forward-leaning training frame built from a curved ship rib and oversized three-pronged harpoon, with three unequal practice rings, a rope coil, and a tideglass plumb weight",
        "description": "A curved ship rib leans into one three-pronged harpoon above three unequal hanging rings, a heavy rope coil, and a small plumb weight.",
    },
    {
        "prefix": "thirproof", "scenario_id": "obituaryink-last-name-proving-road", "scenario_name": "Obituary-Ink Last-Name Proving Road",
        "hero_id": "hero_veilmourn_thir_obituaryink", "faction_id": "faction_veilmourn", "town_id": "town_veilmourn_bellwake_harbor",
        "enemy_faction_id": "faction_thornwake", "enemy_label": "Worldroot Examiners", "encounter_id": "encounter_worldroot_covenant_reliquary",
        "site_id": "site_obituaryink_last_name_lectern", "site_name": "Obituary-Ink Last-Name Lectern", "asset_id": "resource_site_proving_road_obituaryink_lectern",
        "source_name": "obituaryink_last_name_lectern_source.png", "generation_original": "exec-5e1e0668-e8e2-40f2-8481-693579046d5b.png",
        "action_label": "Enter the Last Name", "command_key": "power", "rare_site_id": "site_memory_salt_pan", "terrain": ("snow", "mire"), "seed": 49800,
        "subject": "a leaning black-shell memorial lectern carrying an enormous hooked ink quill, three blank uneven name tablets, a faceted memory-salt inkwell, and one cracked bell",
        "description": "A leaning shell lectern carries one enormous hooked quill above three blank hanging tablets, a faceted inkwell, and one offset cracked bell.",
    },
]


OPENING_STACKS = {
    "faction_brasshollow": [("unit_brasshollow_scrip_haulers", 36), ("unit_brasshollow_quenchspool_slingers", 24), ("unit_brasshollow_gaugefire_arbalists", 14), ("unit_brasshollow_boiler_rivetcasters", 8), ("unit_brasshollow_rivet_hounds", 4)],
    "faction_mireclaw": [("unit_mireclaw_reedsnare_kin", 36), ("unit_mireclaw_mudglass_slingers", 24), ("unit_mireclaw_bogplate_maulers", 14), ("unit_mireclaw_ferrychain_lashers", 8), ("unit_blackbranch_cutthroat", 4)],
    "faction_thornwake": [("unit_thornwake_seedcutters", 36), ("unit_thornwake_bramblekite_needlers", 24), ("unit_thornwake_sporeglass_menders", 14), ("unit_thornwake_barkmantle_rams", 8), ("unit_thornwake_thornwhip_carriers", 4)],
    "faction_veilmourn": [("unit_veilmourn_bellwake_oars", 36), ("unit_veilmourn_mourning_lanterns", 24), ("unit_veilmourn_maskglass_corsairs", 14), ("unit_veilmourn_undertow_harpooners", 8), ("unit_veilmourn_tidehook_deckhands", 4)],
}


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def upsert(items: list[dict], row: dict) -> None:
    for index, current in enumerate(items):
        if current.get("id") == row["id"]:
            items[index] = row
            return
    items.append(row)


def write_pretty(path: Path, payload: dict) -> None:
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def write_compact(path: Path, payload: dict) -> None:
    path.write_text(json.dumps(payload, separators=(",", ":")) + "\n", encoding="utf-8")


def write_groups(path: Path, payload: dict) -> None:
    text = json.dumps(payload, indent=2)
    text = re.sub(r'\{\n\s+"unit_id": ("[^"]+"),\n\s+"count": ([0-9]+)\n\s+\}', r'{"unit_id": \1, "count": \2}', text)
    path.write_text(text + "\n", encoding="utf-8")


def terrain_map(primary: str, accent: str) -> list[list[str]]:
    return [[accent if (x * 3 + y * 5) % 13 in (0, 1) else primary for x in range(15)] for y in range(10)]


def transparent_frame(source: Path) -> Image.Image:
    with Image.open(source) as opened:
        image = opened.convert("RGBA")
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        raise RuntimeError(f"Source has no alpha: {source}")
    cropped = image.crop(bbox)
    fitted = ImageOps.contain(cropped, (42, 42), Image.Resampling.LANCZOS)
    frame = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    frame.alpha_composite(fitted, ((48 - fitted.width) // 2, (48 - fitted.height) // 2))
    return frame


def render_art() -> tuple[str, list[dict]]:
    ATLAS_PATH.parent.mkdir(parents=True, exist_ok=True)
    atlas = Image.new("RGBA", (384, 48), (0, 0, 0, 0))
    rows = []
    for index, case in enumerate(CASES):
        source = SOURCE_ROOT / case["source_name"]
        atlas.alpha_composite(transparent_frame(source), (index * 48, 0))
        prompt = (
            "Use case: stylized-concept; Asset type: production 2D fantasy strategy-game overworld landmark source; "
            f"Primary request: Create {case['site_name']} for the original Aurelion Reach setting; Subject: {case['subject']}; "
            "Style: polished hand-painted 2D original fantasy game object art; Composition: isolated high three-quarter view, centered with generous padding and a silhouette readable at 48x48; "
            "Constraints: genuinely transparent background with preserved alpha, one object only, no ground, scenery, characters, text, letters, numbers, logos, watermark, border, frame, cast shadow, or copied franchise design."
        )
        rows.append({
            "site_id": case["site_id"], "asset_id": case["asset_id"],
            "source_path": f"{SOURCE_RES}/{case['source_name']}", "source_sha256": sha256(source),
            "generation_original": str(GENERATOR_ROOT / case["generation_original"]),
            "atlas_region": [index * 48, 0, 48, 48], "prompt": prompt,
            "accessible_description": case["description"],
        })
    atlas.save(ATLAS_PATH, optimize=True, compress_level=9)
    atlas_sha = sha256(ATLAS_PATH)
    manifest = {
        "schema_id": "eight_commanders_proving_roads_art_v1", "content_batch_id": SLICE_ID,
        "generation_mode": "built_in_imagegen", "source_model": "built_in_imagegen_original_eight_commanders_proving_roads_atlas",
        "prompt_set_summary": "Eight original transparent commander proving landmarks, each authored around a distinct live hero role and readable through non-color silhouette at 48px; no text, logos, scenery, copied franchise expression, or packaged source-master dependency.",
        "runtime_atlas": ATLAS_RES, "runtime_atlas_size": [384, 48], "runtime_atlas_sha256": atlas_sha,
        "source_package_policy": "retained_for_provenance_excluded_from_linux_and_windows_exports", "items": rows,
    }
    write_pretty(SOURCE_ROOT / "manifest.json", manifest)
    return atlas_sha, rows


def scenario_record(case: dict, hero: dict, army_id: str) -> dict:
    prefix = case["prefix"]
    stacks = OPENING_STACKS[case["faction_id"]]
    return {
        "id": case["scenario_id"], "name": case["scenario_name"],
        "selection": {
            "summary": f"Guide {hero['name']} through three live examinations, claim {case['site_name']}, and resolve every earned specialty lesson before Day 16.",
            "recommended_difficulty": "hard", "map_size_label": "Commander's Proving Road (15x10)",
            "player_summary": f"{hero['name']} begins at level one with a five-company field force and must earn three command specialties.",
            "enemy_summary": f"{case['enemy_label']} hold three independent fronts and commit a late reserve if the proving road remains unfinished.",
            "availability": {"campaign": False, "skirmish": True},
        },
        "map_size": {"width": 15, "height": 10}, "player_faction_id": case["faction_id"], "player_army_id": army_id,
        "hero_id": case["hero_id"],
        "starting_resources": {"gold": 9000, "wood": 10, "ore": 10, "embergrain": 4, "aetherglass": 4, "peatwax": 4, "verdant_grafts": 4, "brass_scrip": 4, "memory_salt": 4},
        "map": terrain_map(*case["terrain"]), "start": {"x": 2, "y": 5}, "hero_starts": [case["hero_id"]],
        "objectives": {
            "victory_text": f"{hero['name']} completes the proving road with three field-tested specialties and no lesson unresolved.",
            "defeat_text": "The home seat falls or the examiner cordon closes before the field lessons are resolved.",
            "victory": [
                {"id": f"{prefix}_master_three_lessons", "label": f"Raise {hero['name']} to level 4 and resolve all three specialty choices", "type": "hero_progression_meets_requirements", "hero_id": case["hero_id"], "minimum_level": 4, "minimum_resolved_specialty_choices": 3, "require_no_pending_specialty_choices": True},
                {"id": f"{prefix}_claim_landmark", "label": f"Complete {case['site_name']}", "type": "flag_true", "flag": f"{prefix}_proving_landmark_claimed"},
                {"id": f"clear_{prefix}_landmark_guard", "label": "Clear the central proving guard", "type": "encounter_resolved", "placement_id": f"{prefix}_landmark_guard"},
                {"id": f"clear_{prefix}_north_examination", "label": "Pass the north field examination", "type": "encounter_resolved", "placement_id": f"{prefix}_north_examination"},
                {"id": f"clear_{prefix}_south_examination", "label": "Pass the south field examination", "type": "encounter_resolved", "placement_id": f"{prefix}_south_examination"},
            ],
            "defeat": [
                {"id": f"{prefix}_lose_home", "label": "The proving-road town must remain under player control", "type": "town_not_owned_by_player", "placement_id": f"{prefix}_home"},
                {"id": f"{prefix}_hero_survives", "label": "The field commander must survive", "type": "session_flag_equals", "flag": "campaign", "value": "defeat"},
                {"id": f"{prefix}_pressure", "label": "Keep examiner pressure below 20", "type": "enemy_pressure_at_least", "faction_id": case["enemy_faction_id"], "threshold": 20},
                {"id": f"{prefix}_deadline", "label": "Complete the proving road before Day 16", "type": "day_at_least", "day": 16},
            ],
        },
        "script_hooks": [
            {"id": f"{prefix}_day_two_requisition", "priority": 130, "conditions": [{"type": "day_at_least", "day": 2}, {"type": "town_owned_by_player", "placement_id": f"{prefix}_home"}], "effects": [{"type": "add_resources", "resources": {"gold": 3200, "wood": 2, "ore": 2}}, {"type": "town_add_recruits", "placement_id": f"{prefix}_home", "recruits": {stacks[0][0]: 5, stacks[1][0]: 3}}, {"type": "message", "text": "The home council opens its field ledgers for the proving road."}]},
            {"id": f"{prefix}_central_lesson", "priority": 120, "conditions": [{"type": "encounter_resolved", "placement_id": f"{prefix}_landmark_guard"}], "effects": [{"type": "add_resources", "resources": {"gold": 700}}, {"type": "message", "text": "The central examiner records the first field lesson and opens the landmark approach."}]},
            {"id": f"{prefix}_north_company_returns", "priority": 110, "conditions": [{"type": "encounter_resolved", "placement_id": f"{prefix}_north_examination"}], "effects": [{"type": "add_army_units", "units": {stacks[0][0]: 3, stacks[2][0]: 1}}, {"type": "message", "text": "The north examination survivors return to the active commander's company."}]},
            {"id": f"{prefix}_south_company_returns", "priority": 100, "conditions": [{"type": "encounter_resolved", "placement_id": f"{prefix}_south_examination"}], "effects": [{"type": "add_army_units", "units": {stacks[1][0]: 2, stacks[3][0]: 1}}, {"type": "message", "text": "The south examination survivors return with the third field account."}]},
            {"id": f"{prefix}_day_ten_unfinished_reserve", "priority": 80, "conditions": [{"type": "day_at_least", "day": 10}, {"type": "objective_not_met", "objective_id": f"{prefix}_master_three_lessons"}], "effects": [{"type": "add_enemy_pressure", "faction_id": case["enemy_faction_id"], "amount": 3}, {"type": "town_add_recruits", "placement_id": f"{prefix}_home", "recruits": {stacks[2][0]: 2, stacks[3][0]: 1}}, {"type": "spawn_encounter", "placement": {"placement_id": f"{prefix}_late_reserve", "encounter_id": case["encounter_id"], "x": 13, "y": 5, "difficulty": "scripted", "spawned_by_faction_id": case["enemy_faction_id"], "days_active": 0, "arrived": False, "goal_distance": 9999}}, {"type": "message", "text": "The examiner cordon commits its reserve while specialty lessons remain unresolved."}]},
        ],
        "towns": [{"placement_id": f"{prefix}_home", "town_id": case["town_id"], "x": 1, "y": 5, "owner": "player", "recovery": {"pressure": 1, "source": "commander proving road"}}],
        "enemy_factions": [{"faction_id": case["enemy_faction_id"], "label": case["enemy_label"], "pressure_per_day": 1, "pressure_per_enemy_town": 0, "raid_threshold": 7, "max_active_raids": 1, "raid_pillage_delay": 2, "raid_pillage": {"gold": 180}, "raid_encounter_ids": [case["encounter_id"]], "spawn_points": [{"x": 14, "y": 0}], "siege_target_placement_id": f"{prefix}_home", "siege_active_raid_threshold": 2, "siege_capture_progress": 2, "priority_target_placement_ids": [f"{prefix}_home", f"{prefix}_landmark"]}],
        "resource_nodes": [
            {"placement_id": f"{prefix}_wood_north", "site_id": "site_wood_wagon", "x": 0, "y": 0}, {"placement_id": f"{prefix}_ore_north", "site_id": "site_ore_crates", "x": 3, "y": 0},
            {"placement_id": f"{prefix}_exchange", "site_id": "site_frontier_rare_exchange", "x": 7, "y": 0}, {"placement_id": f"{prefix}_rare_north", "site_id": case["rare_site_id"], "x": 11, "y": 0},
            {"placement_id": f"{prefix}_wood_south", "site_id": "site_wood_wagon", "x": 0, "y": 9}, {"placement_id": f"{prefix}_ore_south", "site_id": "site_ore_crates", "x": 3, "y": 9},
            {"placement_id": f"{prefix}_waystone", "site_id": "site_waystone_cache", "x": 7, "y": 9}, {"placement_id": f"{prefix}_rare_south", "site_id": case["rare_site_id"], "x": 13, "y": 9},
            {"placement_id": f"{prefix}_landmark", "site_id": case["site_id"], "x": 11, "y": 5, "guard_front_id": f"{prefix}_landmark_guard"},
        ],
        "artifact_nodes": [],
        "encounters": [
            {"placement_id": f"{prefix}_landmark_guard", "encounter_id": case["encounter_id"], "x": 9, "y": 5, "difficulty": "medium", "combat_seed": case["seed"] + 1, "prefer_identity_landmark": True, "guardian_role": "commander_proving_landmark_guard"},
            {"placement_id": f"{prefix}_north_examination", "encounter_id": case["encounter_id"], "x": 6, "y": 2, "difficulty": "low", "combat_seed": case["seed"] + 2, "prefer_identity_landmark": True, "guardian_role": "commander_proving_examination_front"},
            {"placement_id": f"{prefix}_south_examination", "encounter_id": case["encounter_id"], "x": 6, "y": 7, "difficulty": "low", "combat_seed": case["seed"] + 3, "prefer_identity_landmark": True, "guardian_role": "commander_proving_examination_front"},
        ],
        "content_status": "commander_proving_road_live", "content_batch_id": SLICE_ID, "scenario_family": "commander_proving_road", "deterministic_seed": case["seed"],
    }


def main() -> None:
    scenarios = load(CONTENT / "scenarios.json")
    groups = load(CONTENT / "army_groups.json")
    sites = load(CONTENT / "resource_sites.json")
    heroes = {row["id"]: row for row in load(CONTENT / "heroes.json")["items"]}
    art = load(ART_MANIFEST)
    atlas_sha, source_rows = render_art()
    for index, case in enumerate(CASES):
        hero = heroes[case["hero_id"]]
        army_id = f"army_{case['prefix']}_field_company"
        upsert(groups["items"], {"id": army_id, "name": f"{hero['name']} Proving-Road Company", "faction_id": case["faction_id"], "stacks": [{"unit_id": uid, "count": count} for uid, count in OPENING_STACKS[case["faction_id"]]], "content_status": "commander_proving_opening_company_live", "content_batch_id": SLICE_ID})
        upsert(sites["items"], {
            "id": case["site_id"], "name": case["site_name"], "family": "scenario_objective", "action_label": case["action_label"],
            "summary": f"{case['site_name']} asks {hero['name']} to reconcile three earned field lessons before the road closes.",
            "claim_rewards": {"experience": 250}, "hero_command_bonus": {case["command_key"]: 1}, "claim_flags": {f"{case['prefix']}_proving_landmark_claimed": True},
            "runtime_boundary": {"status": "commander_proving_road_live", "live_reward_grants": True, "save_payload_required": True, "renderer_sprite_required": True, "pathing_runtime_adopted": True, "route_effect_runtime_adopted": False, "hero_progression_activation": True, "scenario_placement_migration": True},
            "content_batch_id": SLICE_ID, "public_text": {"public_summary": case["description"], "no_internal_debug_score_fields": True, "large_text_panel_required": False},
        })
        upsert(scenarios["items"], scenario_record(case, hero, army_id))
        region = [index * 48, 0, 48, 48]
        art["object_assets"][case["asset_id"]] = {
            "path": ATLAS_RES, "atlas_region": region, "atlas_size": [384, 48], "runtime_sha256": atlas_sha,
            "source_trimmed": source_rows[index]["source_path"], "source_generated": source_rows[index]["source_path"],
            "source_model": "built_in_image_gen_original_eight_commanders_proving_roads_atlas", "asset_policy": "original_generated_runtime_sprite_no_homm3_art_import",
            "distinct_sprite_assignment": True, "assigned_resource_site_id": case["site_id"], "assigned_hero_id": case["hero_id"],
            "presentation_role": case["site_id"].removeprefix("site_"), "accessible_description": case["description"],
        }
        art["resource_site_sprites"][case["site_id"]] = {"asset_id": case["asset_id"], "unclaimed_asset_id": case["asset_id"], "fit": f"Exact original {case['site_name']} remains visible before and after its one-time proving-road claim."}
    scenarios["player_facing_active_scenario_count"] = len(scenarios["items"])
    write_compact(CONTENT / "scenarios.json", scenarios)
    write_groups(CONTENT / "army_groups.json", groups)
    write_pretty(CONTENT / "resource_sites.json", sites)
    write_pretty(ART_MANIFEST, art)
    print(json.dumps({"slice_id": SLICE_ID, "scenario_count": len(scenarios["items"]), "army_group_count": len(groups["items"]), "resource_site_count": len(sites["items"]), "atlas_sha256": atlas_sha}, sort_keys=True))


if __name__ == "__main__":
    main()
