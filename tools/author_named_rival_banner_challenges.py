#!/usr/bin/env python3
"""Author the Six Named Rival Banner Challenges production content batch."""

from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / "content"
ART_MANIFEST = ROOT / "art/overworld/manifest.json"
SOURCE_DIR = ROOT / "art/overworld/source/generated/resource_sites/named_rival_banners_wave1"
ATLAS_PATH = ROOT / "art/overworld/runtime/objects/resource_sites/named_rival_banners_atlas.png"
SLICE_ID = "content-six-named-rival-banner-challenges-10184"
ATLAS_RES = "res://art/overworld/runtime/objects/resource_sites/named_rival_banners_atlas.png"
SOURCE_RES = "res://art/overworld/source/generated/resource_sites/named_rival_banners_wave1"


CASES = [
    {
        "scenario_id": "powderwrit-tollreaver-rival-banner-challenge",
        "name": "Powderwrit-Tollreaver Rival Banner Challenge",
        "prefix": "tollmoon",
        "player_faction": "faction_embercourt",
        "player_hero": "hero_embercourt_maela_powderwrit",
        "player_town": "town_rainwrit_bastion",
        "rival_faction": "faction_mireclaw",
        "rival_hero": "hero_orrik",
        "rival_town": "town_blackfen_gate",
        "site_stem": "tollmoon_claim_post",
        "site_name": "Tollmoon Claim Post",
        "site_role": "crescent_toll_hook_tally_post",
        "site_description": "A low crescent toll hook carries a hide tally ring and three uneven marsh-reed weights, making the captured Mireclaw claim readable by its hooked silhouette.",
        "support_encounters": ["encounter_miremoon_hunt_reliquary", "encounter_bogbell_croft_watch"],
        "terrain": "mire",
        "battlefield_tags": ["bog_channels", "ambush_cover", "chokepoint"],
        "objective_type": "hazard_zone",
        "objective_label": "Tollmoon Claim Rings",
        "objective_summary": "Orrik's hooked tally rings keep the levy road flooded until both claim circles are taken.",
        "seed": 43100,
        "map_template": "tollbrand-cinderlock-border-oath-seizure",
    },
    {
        "scenario_id": "fenhook-facetlane-rival-banner-challenge",
        "name": "Fenhook-Facetlane Rival Banner Challenge",
        "prefix": "facetline",
        "player_faction": "faction_mireclaw",
        "player_hero": "hero_tarn",
        "player_town": "town_murkward_ford",
        "rival_faction": "faction_sunvault",
        "rival_hero": "hero_sunvault_renn_facetlane",
        "rival_town": "town_dawnmirror_observatory",
        "site_stem": "facetline_duel_standard",
        "site_name": "Facetline Duel Standard",
        "site_role": "split_prism_rapier_orbit_standard",
        "site_description": "A tall split-prism rapier is crossed by one off-center orbit ring, giving Renn's exact duel line a narrow asymmetric silhouette without relying on color.",
        "support_encounters": ["encounter_noonglass_orrery_reliquary", "encounter_kite_signal_eyrie_watch"],
        "terrain": "sand",
        "battlefield_tags": ["open_lane", "elevated_fire", "battery_nest"],
        "objective_type": "signal_beacon",
        "objective_label": "Facetline Orbit Signal",
        "objective_summary": "Renn's split-prism signal corrects the duel line until its offset orbit stations are seized.",
        "seed": 43200,
        "map_template": "rotlamp-nightglass-border-oath-seizure",
    },
    {
        "scenario_id": "choirward-greenbarrow-rival-banner-challenge",
        "name": "Choirward-Greenbarrow Rival Banner Challenge",
        "prefix": "greenbarrow",
        "player_faction": "faction_sunvault",
        "player_hero": "hero_thalen",
        "player_town": "town_meridian_choirhold",
        "rival_faction": "faction_thornwake",
        "rival_hero": "hero_thornwake_merek_greenbarrow",
        "rival_town": "town_briarwheel_enclave",
        "site_stem": "greenbarrow_recovery_mark",
        "site_name": "Greenbarrow Recovery Mark",
        "site_role": "root_barrows_and_three_recovery_jars",
        "site_description": "A broad living-root barrow arches over three unequal medicine jars and a low stone cairn, identifying Merek's recovery line by mass and hanging shapes.",
        "support_encounters": ["encounter_worldroot_covenant_reliquary", "encounter_greenbranch_copse_watch"],
        "terrain": "forest",
        "battlefield_tags": ["ambush_cover", "fortified_line", "fog_bank"],
        "objective_type": "supply_post",
        "objective_label": "Greenbarrow Recovery Line",
        "objective_summary": "Merek's root-bound medicine jars keep the rival company recovering until the barrow line is claimed.",
        "seed": 43300,
        "map_template": "lenscaptain-dawnmirror-border-oath-seizure",
    },
    {
        "scenario_id": "pollenglass-bellfounder-rival-banner-challenge",
        "name": "Pollenglass-Bellfounder Rival Banner Challenge",
        "prefix": "bellfounder",
        "player_faction": "faction_thornwake",
        "player_hero": "hero_thornwake_osmund_pollenglass",
        "player_town": "town_crownroot_refuge",
        "rival_faction": "faction_brasshollow",
        "rival_hero": "hero_brasshollow_oren_bellfounder",
        "rival_town": "town_cindercoil_foundry",
        "site_stem": "bellfounder_siege_gauge",
        "site_name": "Bellfounder Siege Gauge",
        "site_role": "asymmetric_foundry_bell_and_chained_hammer",
        "site_description": "An oversized black foundry bell hangs from an asymmetric pressure frame beside one chained square hammer, making Oren's siege gauge unmistakable in silhouette.",
        "support_encounters": ["encounter_seventh_clause_reliquary", "encounter_blackbell_quenchbell_proving"],
        "terrain": "rough",
        "battlefield_tags": ["fortress_lane", "wall_pressure", "battery_nest"],
        "objective_type": "lane_battery",
        "objective_label": "Bellfounder Pressure Lane",
        "objective_summary": "Oren's black bell ranges the siege road until both gauge catches are captured from the company.",
        "seed": 43400,
        "map_template": "boltroot-briarwheel-border-oath-seizure",
    },
    {
        "scenario_id": "heatpriest-vanehook-rival-banner-challenge",
        "name": "Heatpriest-Vanehook Rival Banner Challenge",
        "prefix": "vanehook",
        "player_faction": "faction_brasshollow",
        "player_hero": "hero_brasshollow_odrik_heatpriest",
        "player_town": "town_blackbell_foundry",
        "rival_faction": "faction_veilmourn",
        "rival_hero": "hero_veilmourn_ruln_vanehook",
        "rival_town": "town_gloamwake_anchorage",
        "site_stem": "vanehook_wake_pennant",
        "site_name": "Vanehook Wake Pennant",
        "site_role": "ship_rib_harpoon_vane_and_tideglass",
        "site_description": "A curved ship rib supports a long barbed harpoon vane and one hanging tideglass, giving Ruln's wake pennant a forward-leaning coastal silhouette.",
        "support_encounters": ["encounter_last_bell_tideglass_reliquary", "encounter_frostwharf_house_watch"],
        "terrain": "coast",
        "battlefield_tags": ["fog_bank", "chokepoint", "open_lane"],
        "objective_type": "obstruction_line",
        "objective_label": "Vanehook Wake Line",
        "objective_summary": "Ruln's harpoon vane closes the fog road until its tideglass moorings are taken together.",
        "seed": 43500,
        "map_template": "pitmarshal-cindercoil-border-oath-seizure",
    },
    {
        "scenario_id": "oriflag-pikeward-rival-banner-challenge",
        "name": "Oriflag-Pikeward Rival Banner Challenge",
        "prefix": "pikeward",
        "player_faction": "faction_veilmourn",
        "player_hero": "hero_veilmourn_damar_oriflag",
        "player_town": "town_pale_sounding_harbor",
        "rival_faction": "faction_embercourt",
        "rival_hero": "hero_torren",
        "rival_town": "town_cinderlock_bastion",
        "site_stem": "pikeward_charter_fork",
        "site_name": "Pikeward Charter Fork",
        "site_role": "forked_river_pike_three_charter_plates",
        "site_description": "A forked river pike carries three separate rain-charred charter plates above a small beacon bowl, identifying Torren's line by its open double-prong crown.",
        "support_encounters": ["encounter_lockfire_assize_reliquary", "encounter_frostbeacon_bothy_watch"],
        "terrain": "grass",
        "battlefield_tags": ["fortified_line", "open_lane", "elevated_fire"],
        "objective_type": "breach_point",
        "objective_label": "Pikeward Charter Fork",
        "objective_summary": "Torren's forked pike seals the charter road until its two approach catches are breached.",
        "seed": 43600,
        "map_template": "oriflag-gloamwake-border-oath-seizure",
    },
]


RARE_BY_FACTION = {
    "faction_embercourt": "embergrain",
    "faction_mireclaw": "peatwax",
    "faction_sunvault": "aetherglass",
    "faction_thornwake": "verdant_grafts",
    "faction_brasshollow": "brass_scrip",
    "faction_veilmourn": "memory_salt",
}


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def write_compact(path: Path, payload: dict) -> None:
    path.write_text(json.dumps(payload, separators=(",", ":")) + "\n", encoding="utf-8")


def write_pretty(path: Path, payload: dict) -> None:
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def write_army_groups(path: Path, payload: dict) -> None:
    text = json.dumps(payload, indent=2)
    text = re.sub(
        r'\{\n\s+"unit_id": ("[^"]+"),\n\s+"count": (\d+)\n\s+\}',
        r'{"unit_id": \1, "count": \2}',
        text,
    )
    path.write_text(text + "\n", encoding="utf-8")


def upsert(items: list[dict], row: dict) -> None:
    for index, existing in enumerate(items):
        if existing.get("id") == row["id"]:
            items[index] = row
            return
    items.append(row)


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    factions_payload = load(CONTENT / "factions.json")
    heroes_payload = load(CONTENT / "heroes.json")
    scenarios_payload = load(CONTENT / "scenarios.json")
    groups_payload = load(CONTENT / "army_groups.json")
    encounters_payload = load(CONTENT / "encounters.json")
    sites_payload = load(CONTENT / "resource_sites.json")
    art_payload = load(ART_MANIFEST)

    factions = {row["id"]: row for row in factions_payload["items"]}
    heroes = {row["id"]: row for row in heroes_payload["items"]}
    scenarios = {row["id"]: row for row in scenarios_payload["items"]}
    hero_assets = art_payload["hero_identity_sprites"]
    atlas_sha = sha(ATLAS_PATH)

    source_rows = []
    for index, case in enumerate(CASES):
        player_faction = factions[case["player_faction"]]
        rival_faction = factions[case["rival_faction"]]
        player_hero = heroes[case["player_hero"]]
        rival_hero = heroes[case["rival_hero"]]
        player_units = [player_faction["unit_ladder_ids"][i] for i in (0, 1, 2, 4, 6)]
        rival_units = [rival_faction["unit_ladder_ids"][i] for i in (0, 1, 2, 4, 6)]
        prefix = case["prefix"]
        site_id = f"site_named_rival_{case['site_stem']}"
        asset_id = f"resource_site_named_rival_{case['site_stem']}"
        player_group_id = f"army_{prefix}_challenge_company"
        rival_group_id = f"army_{prefix}_rival_company"
        encounter_id = f"encounter_{prefix}_named_rival_company"
        source_path = SOURCE_DIR / f"{case['site_stem']}.png"
        source_res = f"{SOURCE_RES}/{case['site_stem']}.png"
        region = [index * 48, 0, 48, 48]

        upsert(groups_payload["items"], {
            "id": player_group_id,
            "name": f"{player_hero['name']}'s Banner Challenge Company",
            "faction_id": case["player_faction"],
            "stacks": [{"unit_id": unit_id, "count": count} for unit_id, count in zip(player_units, (30, 18, 11, 5, 2))],
            "content_status": "named_rival_player_company_live",
            "content_batch_id": SLICE_ID,
        })
        upsert(groups_payload["items"], {
            "id": rival_group_id,
            "name": f"{rival_hero['name']}'s Rival Banner Company",
            "faction_id": case["rival_faction"],
            "stacks": [{"unit_id": unit_id, "count": count} for unit_id, count in zip(rival_units, (28, 17, 10, 5, 2))],
            "content_status": "named_rival_enemy_company_live",
            "content_batch_id": SLICE_ID,
        })
        command = dict(rival_hero.get("command", {}))
        upsert(encounters_payload["items"], {
            "id": encounter_id,
            "name": f"{rival_hero['name']}'s Rival Banner Company",
            "enemy_group_id": rival_group_id,
            "affiliation": case["rival_faction"],
            "terrain": case["terrain"],
            "battlefield_tags": case["battlefield_tags"],
            "max_rounds": 15,
            "enemy_commander": {
                "name": rival_hero["name"],
                "command": command,
                "starting_spell_ids": list(rival_hero.get("starting_spell_ids", [])),
                "battle_traits": list(rival_hero.get("battle_traits", [])),
            },
            "field_objectives": [{
                "id": f"{prefix}_rival_banner_field",
                "type": case["objective_type"],
                "label": case["objective_label"],
                "summary": case["objective_summary"],
                "starting_side": "enemy",
                "capture_threshold": 2,
                "urgency_round": 2,
                "pressure_tags": ["cohesion", "urgency", "momentum"],
            }],
            "rewards": {"gold": 450, RARE_BY_FACTION[case["player_faction"]]: 1, "experience": 400},
            "victory_flags": [f"{prefix}_named_rival_broken"],
            "content_status": "named_rival_encounter_live",
            "content_batch_id": SLICE_ID,
        })
        upsert(sites_payload["items"], {
            "id": site_id,
            "name": case["site_name"],
            "family": "faction_outpost",
            "persistent_control": True,
            "claim_rewards": {"gold": 300, RARE_BY_FACTION[case["player_faction"]]: 1},
            "control_income": {"gold": 110},
            "vision_radius": 3,
            "pressure_guard": 2,
            "faction_id": case["rival_faction"],
            "response_profile": {
                "action_label": f"Turn {case['site_name']}",
                "summary": f"Seize {rival_hero['name']}'s command mark and turn its signal against the rival company.",
                "movement_cost": 3,
                "resource_cost": {"gold": 120, "wood": 1},
                "watch_days": 2,
                "readiness_bonus": 2,
                "pressure_guard_bonus": 2,
            },
            "public_text": {
                "public_summary": case["site_description"],
                "large_text_panel_required": False,
            },
            "runtime_boundary": {
                "status": "named_rival_banner_live",
                "live_reward_grants": True,
                "ownership_capture_runtime_adopted": True,
                "controlled_income_runtime_adopted": True,
                "save_payload_required": True,
                "renderer_sprite_required": True,
                "rare_resource_activation": True,
                "market_changes": False,
            },
            "content_status": "named_rival_banner_live",
            "content_batch_id": SLICE_ID,
            "named_rival_banner_role": "exact_three_position_command_mark",
        })

        template = scenarios[case["map_template"]]
        rare = RARE_BY_FACTION[case["player_faction"]]
        scenario = {
            "id": case["scenario_id"],
            "name": case["name"],
            "selection": {
                "summary": f"Break {rival_hero['name']}'s two approach companies, defeat the named rival in person, turn all three {case['site_name']} positions, and take the opposing town.",
                "recommended_difficulty": "normal",
                "map_size_label": "Named Rival Banner Challenge (15x9)",
                "player_summary": f"{player_hero['name']} leads a five-stack field company from {case['player_town'].replace('town_', '').replace('_', ' ').title()}.",
                "enemy_summary": f"{rival_hero['name']} commands a roster-backed rival company, an enemy town, and three mutually supporting banner positions.",
                "availability": {"campaign": False, "skirmish": True},
            },
            "map_size": {"width": 15, "height": 9},
            "player_faction_id": case["player_faction"],
            "player_army_id": player_group_id,
            "hero_id": case["player_hero"],
            "starting_resources": {"gold": 3200, "wood": 6, "ore": 6, "embergrain": 1, "aetherglass": 1, "peatwax": 1, "verdant_grafts": 1, "brass_scrip": 1, "memory_salt": 1},
            "map": template["map"],
            "start": {"x": 0, "y": 4},
            "hero_starts": [case["player_hero"]],
            "objectives": {
                "victory_text": f"All three command marks answer to {player_hero['name']}, the rival town is taken, and {rival_hero['name']}'s company is broken.",
                "defeat_text": "The home town falls, rival pressure reaches twenty-two, or Day 15 closes the banner challenge.",
                "victory": [
                    {"id": f"{prefix}_three_banner_control", "label": "Control all three rival command marks", "type": "resource_sites_controlled_at_least", "placement_ids": [f"{prefix}_banner_west", f"{prefix}_banner_south", f"{prefix}_banner_east"], "minimum_count": 3},
                    {"id": f"{prefix}_capture_rival_town", "label": "Capture the rival town", "type": "town_owned_by_player", "placement_id": f"{prefix}_rival_town"},
                    {"id": f"{prefix}_clear_west", "label": "Break the western approach company", "type": "encounter_resolved", "placement_id": f"{prefix}_west_company"},
                    {"id": f"{prefix}_clear_south", "label": "Break the southern approach company", "type": "encounter_resolved", "placement_id": f"{prefix}_south_company"},
                    {"id": f"{prefix}_defeat_named_rival", "label": f"Defeat {rival_hero['name']}", "type": "encounter_resolved", "placement_id": f"{prefix}_named_rival"},
                ],
                "defeat": [
                    {"id": f"{prefix}_lose_home", "label": "Keep the challenge town under player control", "type": "town_not_owned_by_player", "placement_id": f"{prefix}_home"},
                    {"id": f"{prefix}_pressure", "label": "Keep rival pressure below 22", "type": "enemy_pressure_at_least", "faction_id": case["rival_faction"], "threshold": 22},
                    {"id": f"{prefix}_deadline", "label": "Complete the challenge before Day 15", "type": "day_at_least", "day": 15},
                ],
            },
            "script_hooks": [
                {"id": f"{prefix}_day_two_stipend", "priority": 130, "conditions": [{"type": "day_at_least", "day": 2}, {"type": "town_owned_by_player", "placement_id": f"{prefix}_home"}], "effects": [{"type": "add_resources", "resources": {"gold": 500, "wood": 1, "ore": 1}}, {"type": "message", "text": "The home council releases supplies for the named-rival challenge."}]},
                {"id": f"{prefix}_west_company_tallies", "priority": 120, "conditions": [{"type": "encounter_resolved", "placement_id": f"{prefix}_west_company"}], "effects": [{"type": "add_resources", "resources": {"gold": 250, rare: 1}}, {"type": "message", "text": "The western approach yields its rival tallies."}]},
                {"id": f"{prefix}_south_company_relief", "priority": 110, "conditions": [{"type": "encounter_resolved", "placement_id": f"{prefix}_south_company"}], "effects": [{"type": "town_add_recruits", "placement_id": f"{prefix}_home", "recruits": {player_units[0]: 5}}, {"type": "message", "text": "Released field hands reinforce the challenge company."}]},
                {"id": f"{prefix}_day_five_rival_pressure", "priority": 80, "conditions": [{"type": "day_at_least", "day": 5}, {"type": "objective_not_met", "objective_id": f"{prefix}_defeat_named_rival"}], "effects": [{"type": "add_enemy_pressure", "faction_id": case["rival_faction"], "amount": 3}, {"type": "message", "text": f"{rival_hero['name']} tightens the command line around the remaining banners."}]},
                {"id": f"{prefix}_day_eight_replacement", "priority": 70, "conditions": [{"type": "day_at_least", "day": 8}, {"type": "objective_not_met", "objective_id": f"{prefix}_three_banner_control"}], "effects": [{"type": "spawn_encounter", "placement": {"placement_id": f"{prefix}_replacement_company", "encounter_id": case["support_encounters"][0], "x": 10, "y": 4, "difficulty": "high", "spawned_by_faction_id": case["rival_faction"]}}, {"type": "message", "text": "A replacement company moves onto the center command road."}]},
            ],
            "towns": [
                {"placement_id": f"{prefix}_home", "town_id": case["player_town"], "x": 0, "y": 4, "owner": "player", "built_buildings": ["building_market_square"]},
                {"placement_id": f"{prefix}_rival_town", "town_id": case["rival_town"], "x": 14, "y": 4, "owner": "enemy"},
            ],
            "enemy_factions": [{
                "faction_id": case["rival_faction"],
                "label": f"{rival_hero['name']}'s Rival Company",
                "pressure_per_day": 1,
                "pressure_per_enemy_town": 1,
                "raid_threshold": 9,
                "max_active_raids": 2,
                "raid_pillage_delay": 2,
                "raid_pillage": {"gold": 180},
                "raid_encounter_ids": list(case["support_encounters"]),
                "spawn_points": [{"x": 14, "y": 0}, {"x": 14, "y": 8}],
                "siege_target_placement_id": f"{prefix}_home",
                "priority_target_placement_ids": [f"{prefix}_banner_east", f"{prefix}_banner_south", f"{prefix}_banner_west", f"{prefix}_home"],
            }],
            "resource_nodes": [
                {"placement_id": f"{prefix}_banner_west", "site_id": site_id, "x": 2, "y": 1, "guard_front_id": f"{prefix}_west_company"},
                {"placement_id": f"{prefix}_banner_south", "site_id": site_id, "x": 7, "y": 7, "guard_front_id": f"{prefix}_south_company"},
                {"placement_id": f"{prefix}_banner_east", "site_id": site_id, "x": 12, "y": 1, "guard_front_id": f"{prefix}_named_rival"},
                {"placement_id": f"{prefix}_wood_north", "site_id": "site_wood_wagon", "x": 0, "y": 0},
                {"placement_id": f"{prefix}_ore_north", "site_id": "site_ore_crates", "x": 5, "y": 0},
                {"placement_id": f"{prefix}_exchange", "site_id": "site_frontier_rare_exchange", "x": 10, "y": 0},
                {"placement_id": f"{prefix}_waystone", "site_id": "site_waystone_cache", "x": 14, "y": 0},
                {"placement_id": f"{prefix}_wood_south", "site_id": "site_wood_wagon", "x": 0, "y": 8},
                {"placement_id": f"{prefix}_ore_south", "site_id": "site_ore_crates", "x": 14, "y": 8},
            ],
            "artifact_nodes": [],
            "encounters": [
                {"placement_id": f"{prefix}_west_company", "encounter_id": case["support_encounters"][0], "x": 2, "y": 2, "difficulty": "medium", "combat_seed": case["seed"] + 1, "prefer_identity_landmark": True},
                {"placement_id": f"{prefix}_south_company", "encounter_id": case["support_encounters"][1], "x": 7, "y": 6, "difficulty": "medium", "combat_seed": case["seed"] + 2, "prefer_identity_landmark": True},
                {"placement_id": f"{prefix}_named_rival", "encounter_id": encounter_id, "x": 12, "y": 2, "difficulty": "high", "combat_seed": case["seed"] + 3, "spawned_by_faction_id": case["rival_faction"], "enemy_commander_state": {"roster_hero_id": case["rival_hero"], "faction_id": case["rival_faction"]}},
            ],
            "content_status": "named_rival_banner_challenge_live",
            "content_batch_id": SLICE_ID,
            "scenario_family": "named_rival_banner_challenge",
            "deterministic_seed": case["seed"],
        }
        upsert(scenarios_payload["items"], scenario)

        art_payload["object_assets"][asset_id] = {
            "path": ATLAS_RES,
            "atlas_region": region,
            "atlas_size": [288, 48],
            "runtime_sha256": atlas_sha,
            "source_trimmed": source_res,
            "source_generated": source_res,
            "source_model": "built_in_image_gen_original_named_rival_banner_atlas",
            "asset_policy": "original_generated_runtime_sprite_no_homm3_art_import",
            "distinct_sprite_assignment": True,
            "assigned_resource_site_id": site_id,
            "assigned_faction_id": case["rival_faction"],
            "presentation_role": case["site_role"],
            "accessible_description": case["site_description"],
        }
        art_payload["resource_site_sprites"][site_id] = {
            "asset_id": asset_id,
            "unclaimed_asset_id": asset_id,
            "fit": f"Exact original {case['site_name']} remains visible before and after persistent command-banner control.",
        }
        art_payload["encounter_identity_sprites"][encounter_id] = hero_assets[case["rival_hero"]]
        source_rows.append({
            "site_id": site_id,
            "asset_id": asset_id,
            "path": source_res,
            "sha256": sha(source_path),
            "atlas_region": region,
            "accessible_description": case["site_description"],
        })

    source_manifest = {
        "schema_id": "named_rival_banner_source_manifest_v1",
        "content_batch_id": SLICE_ID,
        "generator_mode": "built_in_image_gen",
        "generated_at": "2026-08-31",
        "identity_sheet": f"{SOURCE_RES}/named_rival_banners_identity_sheet.png",
        "identity_sheet_sha256": sha(SOURCE_DIR / "named_rival_banners_identity_sheet.png"),
        "final_prompt": "Six original Aurelion Reach rival command-banner landmarks in an exact 3x2 sheet: crescent toll hook and tally ring, split-prism rapier and orbit, root barrow with medicine jars, black foundry bell and chained hammer, ship-rib harpoon vane and tideglass, and forked river pike with three charter plates; hand-painted map-object sprites, distinct non-color silhouettes, no text or franchise symbols, genuine transparency.",
        "background_extraction_prompt": "Remove only the dark blurred background and replace it with genuine alpha transparency while preserving all six objects, materials, lighting, scale, grid positions, spacing, and fine edges without halos, additions, restyling, or text.",
        "generated_original": "/root/.codex/generated_images/019fe72a-30b1-76f3-b911-385c4444bd16/exec-5c4735f2-5d20-41c4-a57c-2456f90f98bc.png",
        "runtime_atlas": {"path": ATLAS_RES, "size": [288, 48], "cell_size": [48, 48], "region_count": 6, "sha256": atlas_sha, "package_policy": "single_imported_atlas_only"},
        "sources": source_rows,
    }

    scenarios_payload["player_facing_active_scenario_count"] = len(scenarios_payload["items"])
    write_army_groups(CONTENT / "army_groups.json", groups_payload)
    write_compact(CONTENT / "encounters.json", encounters_payload)
    write_pretty(CONTENT / "resource_sites.json", sites_payload)
    write_compact(CONTENT / "scenarios.json", scenarios_payload)
    write_pretty(ART_MANIFEST, art_payload)
    write_pretty(SOURCE_DIR / "manifest.json", source_manifest)
    print(json.dumps({
        "slice_id": SLICE_ID,
        "scenario_count": len(scenarios_payload["items"]),
        "army_group_count": len(groups_payload["items"]),
        "encounter_count": len(encounters_payload["items"]),
        "resource_site_count": len(sites_payload["items"]),
        "atlas_sha256": atlas_sha,
    }, sort_keys=True))


if __name__ == "__main__":
    main()
