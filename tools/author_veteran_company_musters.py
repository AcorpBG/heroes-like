#!/usr/bin/env python3
"""Author the Six Veteran Company Musters production content batch."""

from __future__ import annotations

import copy
import hashlib
import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / "content"
ART_MANIFEST = ROOT / "art/overworld/manifest.json"
MAP_SPRITES = ROOT / "art/overworld/map_object_sprites.json"
SOURCE_DIR = ROOT / "art/overworld/source/generated/resource_sites/veteran_company_musters_wave1"
ATLAS_PATH = ROOT / "art/overworld/runtime/objects/resource_sites/veteran_company_musters_wave1/veteran_company_musters_atlas.png"
ATLAS_RES = "res://art/overworld/runtime/objects/resource_sites/veteran_company_musters_wave1/veteran_company_musters_atlas.png"
SOURCE_RES = "res://art/overworld/source/generated/resource_sites/veteran_company_musters_wave1"
SLICE_ID = "content-six-veteran-company-musters-10184"
SOURCE_MODEL = "built_in_image_gen_original_veteran_company_musters_wave1"


CASES = [
    {
        "scenario_id": "pikeward-ashcharter-veteran-muster",
        "name": "Pikeward Ash-Charter Veteran Muster",
        "prefix": "ashcharter",
        "faction": "faction_embercourt",
        "hero": "hero_torren",
        "home_town": "town_rainwrit_bastion",
        "enemy_faction": "faction_veilmourn",
        "enemy_town": "town_gloamwake_anchorage",
        "site_stem": "ash_charter_rollhouse",
        "site_name": "Ash-Charter Rollhouse",
        "base_site": "site_stormseal_powder_wharf",
        "base_object": "object_stormseal_powder_wharf",
        "targets": [
            "unit_embercourt_lantern_sappers",
            "unit_embercourt_ash_oath_bailiffs",
            "unit_embercourt_charter_colossus",
        ],
        "starting": [("unit_embercourt_fordhook_cadets", 28), ("unit_embercourt_bargebow_crews", 14)],
        "encounters": [
            "encounter_keelwarden_dustjack_screen",
            "encounter_vowless_drowned_requiem",
            "encounter_gloamkeel_sounding_barricade",
        ],
        "template": "powderwrit-tollreaver-rival-banner-challenge",
        "rare": "embergrain",
        "seed": 46100,
        "site_summary": "A rain-black charter house trains the sapper, bailiff, and colossus companies that keep Embercourt's veteran writs enforceable.",
        "unclaimed_description": "A shuttered rain-black rollhouse stands behind a cold charter brazier and lowered forked pennant.",
        "controlled_description": "The same rollhouse opens beneath a raised ember pennant, lit brazier, and ready veteran-company muster racks.",
    },
    {
        "scenario_id": "chainboom-gorefen-veteran-muster",
        "name": "Chainboom Gorefen Veteran Muster",
        "prefix": "gorefenring",
        "faction": "faction_mireclaw",
        "hero": "hero_mireclaw_kessa_chainboom",
        "home_town": "town_murkward_ford",
        "enemy_faction": "faction_sunvault",
        "enemy_town": "town_meridian_choirhold",
        "site_stem": "gorefen_chain_ring",
        "site_name": "Gorefen Chain Ring",
        "base_site": "site_moonwax_reed_circle",
        "base_object": "object_moonwax_reed_circle",
        "targets": ["unit_mireclaw_ferrychain_lashers", "unit_mireclaw_gorefen_rippers"],
        "starting": [("unit_mireclaw_reedsnare_kin", 28), ("unit_mireclaw_mudglass_slingers", 18)],
        "encounters": [
            "encounter_glassmarshal_counterseal_battery",
            "encounter_halometer_daylight_crown",
            "encounter_lenscaptain_reedbarge_survey",
        ],
        "template": "fenhook-facetlane-rival-banner-challenge",
        "rare": "peatwax",
        "seed": 46200,
        "site_summary": "A chained fen ring binds ferry crews and Gorefen shock companies into a repeatable veteran levy.",
        "unclaimed_description": "A dark iron chain ring lies slack among drowned posts, sealed drums, and an unlit fen lantern.",
        "controlled_description": "The same ring stands taut beneath raised chain pennants, lit drums, and occupied veteran muster posts.",
    },
    {
        "scenario_id": "glassmarshal-daybreak-veteran-muster",
        "name": "Glassmarshal Daybreak Veteran Muster",
        "prefix": "daybreakprism",
        "faction": "faction_sunvault",
        "hero": "hero_sunvault_ilyr_glassmarshal",
        "home_town": "town_meridian_choirhold",
        "enemy_faction": "faction_thornwake",
        "enemy_town": "town_crownroot_refuge",
        "site_stem": "mirror_daybreak_drill_prism",
        "site_name": "Mirror-Daybreak Drill Prism",
        "base_site": "site_facet_vigil",
        "base_object": "object_facet_vigil",
        "targets": ["unit_sunvault_mirror_duelists", "unit_sunvault_daybreak_colossus"],
        "starting": [("unit_sunvault_shard_wardens", 28), ("unit_sunvault_prism_adepts", 18)],
        "encounters": [
            "encounter_graftsibyl_wake_cordon",
            "encounter_loamchant_crystal_sump_binding",
            "encounter_seedseer_kite_root_omen",
        ],
        "template": "choirward-greenbarrow-rival-banner-challenge",
        "rare": "aetherglass",
        "seed": 46300,
        "site_summary": "A split drill prism aligns mirror duelists and Daybreak colossi under one precise Sunvault training cadence.",
        "unclaimed_description": "A folded ivory drill prism rests between dark mirror fins and an empty sun-dial court.",
        "controlled_description": "The same prism opens into a bright daybreak array with raised mirror fins and supplied drill stations.",
    },
    {
        "scenario_id": "bramblehound-worldroot-veteran-muster",
        "name": "Bramblehound Worldroot Veteran Muster",
        "prefix": "fivebough",
        "faction": "faction_thornwake",
        "hero": "hero_thornwake_silsa_bramblehound",
        "home_town": "town_crownroot_refuge",
        "enemy_faction": "faction_brasshollow",
        "enemy_town": "town_blackbell_foundry",
        "site_stem": "five_bough_veteran_grove",
        "site_name": "Five-Bough Veteran Grove",
        "base_site": "site_heartseed_bolt_grove",
        "base_object": "object_heartseed_bolt_grove",
        "targets": [
            "unit_thornwake_pollenhook_whistlers",
            "unit_thornwake_bramblekite_needlers",
            "unit_thornwake_seedshield_wardens",
            "unit_thornwake_graft_matriarchs",
            "unit_thornwake_worldroot_bastion",
        ],
        "starting": [("unit_thornwake_seedcutters", 28), ("unit_thornwake_thornwhip_carriers", 18)],
        "encounters": [
            "encounter_debtrune_lastbell_audit",
            "encounter_gaugesavant_switchback_proof",
            "encounter_ironclause_ninefold_assize",
        ],
        "template": "pollenglass-bellfounder-rival-banner-challenge",
        "rare": "verdant_grafts",
        "seed": 46400,
        "site_summary": "Five living boughs call every Thornwake company grade, from pollenhook scouts to the Worldroot Bastion.",
        "unclaimed_description": "Five dormant boughs curl around sealed seed shields, folded kite racks, and a sleeping root altar.",
        "controlled_description": "The same five boughs flower around raised pennants, opened racks, and a luminous worldroot muster heart.",
    },
    {
        "scenario_id": "pitmarshal-foundry-veteran-muster",
        "name": "Pitmarshal Foundry Veteran Muster",
        "prefix": "threegauge",
        "faction": "faction_brasshollow",
        "hero": "hero_brasshollow_selka_pitmarshal",
        "home_town": "town_blackbell_foundry",
        "enemy_faction": "faction_embercourt",
        "enemy_town": "town_cinderlock_bastion",
        "site_stem": "three_gauge_chapter_foundry",
        "site_name": "Three-Gauge Chapter Foundry",
        "base_site": "site_blackbell_assay_watch",
        "base_object": "object_blackbell_assay_watch",
        "targets": [
            "unit_brasshollow_quenchspool_slingers",
            "unit_brasshollow_gaugefire_arbalists",
            "unit_brasshollow_foundry_saint",
        ],
        "starting": [("unit_brasshollow_scrip_haulers", 28), ("unit_brasshollow_rivet_hounds", 18)],
        "encounters": [
            "encounter_beaconscribe_frostwharf_writ",
            "encounter_lockmaster_archive_seal",
            "encounter_rainwrit_charter_watch",
        ],
        "template": "heatpriest-vanehook-rival-banner-challenge",
        "rare": "brass_scrip",
        "seed": 46500,
        "site_summary": "Three independently read gauges certify quenchspool, gaugefire, and Foundry Saint chapters for field service.",
        "unclaimed_description": "A cold black-brick foundry holds three dark gauges, a lowered bell hammer, and empty chapter racks.",
        "controlled_description": "The same foundry burns beneath three live gauges, a raised chapter pennant, and supplied veteran weapon racks.",
    },
    {
        "scenario_id": "keelwarden-fogkeel-veteran-muster",
        "name": "Keelwarden Fog-Keel Veteran Muster",
        "prefix": "fogkeel",
        "faction": "faction_veilmourn",
        "hero": "hero_veilmourn_jessa_keelwarden",
        "home_town": "town_pale_sounding_harbor",
        "enemy_faction": "faction_mireclaw",
        "enemy_town": "town_blackfen_gate",
        "site_stem": "fog_keel_lastwatch_mooring",
        "site_name": "Fog-Keel Lastwatch Mooring",
        "base_site": "site_last_memory_mooring",
        "base_object": "object_last_memory_mooring",
        "targets": [
            "unit_veilmourn_wakechain_boarders",
            "unit_veilmourn_mirrorkeel_reavers",
            "unit_veilmourn_fogbound_leviathan",
        ],
        "starting": [("unit_veilmourn_bellwake_oars", 28), ("unit_veilmourn_mourning_lanterns", 18)],
        "encounters": [
            "encounter_chainboom_daybreak_snare",
            "encounter_fenwake_crown_drum_verdict",
            "encounter_votivejaw_nightglass_bite",
        ],
        "template": "oriflag-pikeward-rival-banner-challenge",
        "rare": "memory_salt",
        "seed": 46600,
        "site_summary": "A fog-keel mooring restores Veilmourn's boarder, reaver, and leviathan companies to the weekly harbor rolls.",
        "unclaimed_description": "A pale ribbed mooring stands under a furled fog sail, dark lantern, and sealed lastwatch bell.",
        "controlled_description": "The same mooring carries a raised pearl sail, lit bell-lanterns, and occupied veteran boarding racks.",
    },
]


CLAIM_BY_TIER = {1: 6, 2: 4, 3: 3, 4: 2, 5: 2, 6: 1, 7: 1}


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def write_pretty(path: Path, payload: dict) -> None:
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def write_compact(path: Path, payload: dict) -> None:
    path.write_text(json.dumps(payload, separators=(",", ":")) + "\n", encoding="utf-8")


def write_armies(path: Path, payload: dict) -> None:
    text = json.dumps(payload, indent=2)
    text = re.sub(r'\{\n\s+"unit_id": ("[^"]+"),\n\s+"count": (\d+)\n\s+\}', r'{"unit_id": \1, "count": \2}', text)
    path.write_text(text + "\n", encoding="utf-8")


def upsert(items: list[dict], row: dict) -> None:
    for index, current in enumerate(items):
        if current.get("id") == row["id"]:
            items[index] = row
            return
    items.append(row)


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    scenarios_payload = load(CONTENT / "scenarios.json")
    groups_payload = load(CONTENT / "army_groups.json")
    sites_payload = load(CONTENT / "resource_sites.json")
    objects_payload = load(CONTENT / "map_objects.json")
    units_payload = load(CONTENT / "units.json")
    heroes_payload = load(CONTENT / "heroes.json")
    encounters_payload = load(CONTENT / "encounters.json")
    art_payload = load(ART_MANIFEST)
    sprite_payload = load(MAP_SPRITES)

    scenarios = {row["id"]: row for row in scenarios_payload["items"]}
    sites = {row["id"]: row for row in sites_payload["items"]}
    objects = {row["id"]: row for row in objects_payload["items"]}
    units = {row["id"]: row for row in units_payload["items"]}
    heroes = {row["id"]: row for row in heroes_payload["items"]}
    encounters = {row["id"]: row for row in encounters_payload["items"]}
    atlas_sha = sha(ATLAS_PATH)
    source_manifest_items = []

    for index, case in enumerate(CASES):
        hero_name = heroes[case["hero"]]["name"]
        prefix = case["prefix"]
        site_id = f"site_{case['site_stem']}"
        object_id = f"object_{case['site_stem']}"
        placement_id = f"{prefix}_veteran_muster"
        claim_recruits = {unit_id: CLAIM_BY_TIER[int(units[unit_id]["tier"])] for unit_id in case["targets"]}
        weekly_recruits = {unit_id: 1 for unit_id in case["targets"]}
        target_names = [units[unit_id]["name"] for unit_id in case["targets"]]
        army_id = f"army_{prefix}_veteran_muster_company"

        upsert(groups_payload["items"], {
            "id": army_id,
            "name": f"{hero_name}'s Veteran Muster Company",
            "faction_id": case["faction"],
            "stacks": [{"unit_id": unit_id, "count": count} for unit_id, count in case["starting"]],
            "content_status": "veteran_company_muster_player_company_live",
            "content_batch_id": SLICE_ID,
        })

        site = copy.deepcopy(sites[case["base_site"]])
        site.update({
            "id": site_id,
            "name": case["site_name"],
            "faction_id": case["faction"],
            "claim_rewards": {"gold": 180, case["rare"]: 1},
            "claim_flags": {f"{prefix}_veteran_muster_claimed": True},
            "control_income": {"gold": 40, case["rare"]: 1},
            "claim_recruits": claim_recruits,
            "weekly_recruits": weekly_recruits,
            "response_profile": {
                "action_label": "Send the Veteran Roll",
                "summary": f"{case['site_name']} dispatches its certified companies to the nearest held town.",
                "movement_cost": 6,
                "resource_cost": {"gold": 300, case["rare"]: 1},
                "watch_days": 5,
                "quality_bonus": 6,
                "readiness_bonus": 4,
                "pressure_bonus": 1,
                "recovery_relief": 1,
            },
            "veteran_company_contract": {
                "company_unit_ids": case["targets"],
                "recruit_policy": "immediate_and_weekly_muster",
                "recurring_recruit_access": True,
                "faction_linked": True,
                "guarded_claim": True,
            },
            "public_summary": case["site_summary"],
            "accessibility_text": f"Guarded faction muster for {', '.join(target_names)}; the controlled state raises its standard and lights its company stations.",
            "runtime_boundary": {
                "status": "guarded_faction_linked_dwelling_live",
                "resource_site_runtime_supported": True,
                "save_payload_required": True,
                "renderer_sprite_required": True,
                "pathing_runtime_adopted": True,
                "weekly_town_delivery_live": True,
                "guard_resolution_runtime_adopted": True,
            },
            "content_status": "veteran_company_muster_live",
            "content_batch_id": SLICE_ID,
            "batch_role": "guarded_faction_veteran_company_muster",
        })
        site.pop("company_contract", None)
        upsert(sites_payload["items"], site)

        map_object = copy.deepcopy(objects[case["base_object"]])
        map_object.update({
            "id": object_id,
            "name": case["site_name"],
            "resource_site_id": site_id,
            "faction_id": case["faction"],
            "map_roles": ["faction_recruit_source", "weekly_muster", "counter_capture_target", "guarded_reward"],
            "secondary_tags": [f"{prefix}_veteran_muster", "weekly_muster", "persistent_control", "guarded_reward"],
            "veteran_company_contract": {
                "company_unit_ids": case["targets"],
                "resource_site_id": site_id,
                "recruit_policy": "immediate_and_weekly_muster",
                "faction_linked": True,
                "guarded_claim": True,
            },
            "guard_expectation": {
                "tier": "veteran",
                "visible_cue": "authored encounter occupies the entrance before recruitment",
                "clear_required_for_recruitment": True,
                "blocks_approach": True,
                "scenario_placement_required": True,
            },
            "content_status": "veteran_company_muster_live",
            "content_batch_id": SLICE_ID,
            "batch_role": "guarded_faction_veteran_company_muster",
        })
        map_object.pop("company_contract", None)
        map_object["approach"]["guard_clearance_required"] = True
        map_object["interaction"]["requires_guard_clear"] = True
        map_object["editor_placement"]["requires_guard_space"] = True
        map_object["ai_hints"].update({"strategic_value": 10, "risk_tier": "veteran", "guard_target_value_hint": 5, "avoid_until_strength": "veteran"})
        map_object["runtime_boundary"]["status"] = "guarded_faction_linked_dwelling_live"
        map_object["runtime_boundary"]["guard_resolution_runtime_adopted"] = True
        upsert(objects_payload["items"], map_object)

        template = scenarios[case["template"]]
        encounter_placements = [
            {"placement_id": f"{prefix}_west_company", "encounter_id": case["encounters"][0], "x": 3, "y": 2, "difficulty": "medium", "combat_seed": case["seed"] + 1, "prefer_identity_landmark": True},
            {"placement_id": f"{prefix}_south_company", "encounter_id": case["encounters"][1], "x": 7, "y": 6, "difficulty": "medium", "combat_seed": case["seed"] + 2, "prefer_identity_landmark": True},
            {"placement_id": f"{prefix}_muster_guard", "encounter_id": case["encounters"][2], "x": 12, "y": 2, "difficulty": "high", "combat_seed": case["seed"] + 3, "prefer_identity_landmark": True},
        ]
        requirements = [{"unit_id": unit_id, "minimum_count": claim_recruits[unit_id]} for unit_id in case["targets"]]
        victory = [{
            "id": f"{prefix}_assemble_veterans",
            "label": f"Assemble {hero_name}'s complete veteran roll",
            "type": "hero_army_meets_requirements",
            "hero_id": case["hero"],
            "requirements": requirements,
        }, {
            "id": f"{prefix}_control_muster",
            "label": f"Control {case['site_name']}",
            "type": "resource_sites_controlled_at_least",
            "placement_ids": [placement_id],
            "minimum_count": 1,
        }]
        for position, placement in zip(("west", "south", "guard"), encounter_placements):
            victory.append({"id": f"{prefix}_clear_{position}", "label": f"Break the {position} veteran screen", "type": "encounter_resolved", "placement_id": placement["placement_id"]})

        scenario = {
            "id": case["scenario_id"],
            "name": case["name"],
            "selection": {
                "summary": f"Break three opposing screens, open {case['site_name']}, and assemble every missing {hero_name} veteran company before the relief window closes.",
                "recommended_difficulty": "normal",
                "map_size_label": "Veteran Muster Operation (15x9)",
                "player_summary": f"{hero_name} begins with a lean two-stack road company; the veteran grades must be won on the map.",
                "enemy_summary": "Three roster-backed companies guard the only recurring veteran recruitment route while an enemy town feeds counter-raids.",
                "availability": {"campaign": False, "skirmish": True},
            },
            "map_size": {"width": 15, "height": 9},
            "player_faction_id": case["faction"],
            "player_army_id": army_id,
            "hero_id": case["hero"],
            "starting_resources": {"gold": 2800, "wood": 6, "ore": 6, case["rare"]: 2},
            "map": copy.deepcopy(template["map"]),
            "start": {"x": 0, "y": 4},
            "hero_starts": [case["hero"]],
            "objectives": {
                "victory_text": f"{case['site_name']} is open and every veteran company has answered {hero_name}'s field roll.",
                "defeat_text": "The home town falls, enemy pressure reaches twenty-four, or Day 18 closes the muster road.",
                "victory": victory,
                "defeat": [
                    {"id": f"{prefix}_lose_home", "label": "Keep the muster town under player control", "type": "town_not_owned_by_player", "placement_id": f"{prefix}_home"},
                    {"id": f"{prefix}_pressure", "label": "Keep enemy pressure below 24", "type": "enemy_pressure_at_least", "faction_id": case["enemy_faction"], "threshold": 24},
                    {"id": f"{prefix}_deadline", "label": "Complete the muster before Day 18", "type": "day_at_least", "day": 18},
                ],
            },
            "script_hooks": [
                {"id": f"{prefix}_day_two_stipend", "priority": 130, "conditions": [{"type": "day_at_least", "day": 2}, {"type": "town_owned_by_player", "placement_id": f"{prefix}_home"}], "effects": [{"type": "add_resources", "resources": {"gold": 450, "wood": 1, "ore": 1}}, {"type": "message", "text": "The home quartermasters release the veteran-roll stipend."}]},
                {"id": f"{prefix}_west_tallies", "priority": 120, "conditions": [{"type": "encounter_resolved", "placement_id": f"{prefix}_west_company"}], "effects": [{"type": "add_resources", "resources": {"gold": 240, case["rare"]: 1}}, {"type": "message", "text": "The western screen yields its sealed muster tallies."}]},
                {"id": f"{prefix}_south_relief", "priority": 110, "conditions": [{"type": "encounter_resolved", "placement_id": f"{prefix}_south_company"}], "effects": [{"type": "town_add_recruits", "placement_id": f"{prefix}_home", "recruits": {case["starting"][0][0]: 5}}, {"type": "message", "text": "Freed road hands reinforce the home garrison."}]},
                {"id": f"{prefix}_day_six_pressure", "priority": 80, "conditions": [{"type": "day_at_least", "day": 6}, {"type": "objective_not_met", "objective_id": f"{prefix}_control_muster"}], "effects": [{"type": "add_enemy_pressure", "faction_id": case["enemy_faction"], "amount": 3}, {"type": "message", "text": "The unopened muster draws another hostile levy onto the road."}]},
                {"id": f"{prefix}_day_ten_counterstroke", "priority": 70, "conditions": [{"type": "day_at_least", "day": 10}, {"type": "objective_not_met", "objective_id": f"{prefix}_control_muster"}], "effects": [{"type": "spawn_encounter", "placement": {"placement_id": f"{prefix}_counterstroke", "encounter_id": case["encounters"][0], "x": 10, "y": 4, "difficulty": "high", "spawned_by_faction_id": case["enemy_faction"]}}, {"type": "message", "text": "A replacement company advances before the veteran roll can open."}]},
            ],
            "towns": [
                {"placement_id": f"{prefix}_home", "town_id": case["home_town"], "x": 0, "y": 4, "owner": "player", "built_buildings": ["building_market_square"]},
                {"placement_id": f"{prefix}_enemy_town", "town_id": case["enemy_town"], "x": 14, "y": 4, "owner": "enemy"},
            ],
            "enemy_factions": [{
                "faction_id": case["enemy_faction"],
                "label": "Veteran Muster Interdictors",
                "pressure_per_day": 1,
                "pressure_per_enemy_town": 1,
                "raid_threshold": 9,
                "max_active_raids": 2,
                "raid_pillage_delay": 2,
                "raid_pillage": {"gold": 180},
                "raid_encounter_ids": case["encounters"][:2],
                "spawn_points": [{"x": 14, "y": 0}, {"x": 14, "y": 8}],
                "siege_target_placement_id": f"{prefix}_home",
                "priority_target_placement_ids": [placement_id, f"{prefix}_home"],
            }],
            "resource_nodes": [
                {"placement_id": placement_id, "site_id": site_id, "x": 12, "y": 1, "guard_front_id": f"{prefix}_muster_guard"},
                {"placement_id": f"{prefix}_wood_north", "site_id": "site_wood_wagon", "x": 0, "y": 0},
                {"placement_id": f"{prefix}_ore_north", "site_id": "site_ore_crates", "x": 5, "y": 0},
                {"placement_id": f"{prefix}_exchange", "site_id": "site_frontier_rare_exchange", "x": 10, "y": 0},
                {"placement_id": f"{prefix}_waystone", "site_id": "site_waystone_cache", "x": 14, "y": 0},
                {"placement_id": f"{prefix}_wood_south", "site_id": "site_wood_wagon", "x": 0, "y": 8},
                {"placement_id": f"{prefix}_ore_south", "site_id": "site_ore_crates", "x": 14, "y": 8},
            ],
            "artifact_nodes": [],
            "encounters": encounter_placements,
            "content_status": "veteran_company_muster_operation_live",
            "content_batch_id": SLICE_ID,
            "scenario_family": "veteran_company_muster_operation",
            "deterministic_seed": case["seed"],
        }
        upsert(scenarios_payload["items"], scenario)

        unclaimed_asset = f"mapobj_{case['site_stem']}"
        controlled_asset = f"resource_site_veteran_{case['site_stem']}_controlled"
        unclaimed_source = SOURCE_DIR / f"{case['site_stem']}_unclaimed.png"
        controlled_source = SOURCE_DIR / f"{case['site_stem']}_controlled.png"
        unclaimed_region = [index * 96, 0, 48, 48]
        controlled_region = [index * 96 + 48, 0, 48, 48]
        art_payload["object_assets"][unclaimed_asset] = {
            "path": ATLAS_RES,
            "atlas_region": unclaimed_region,
            "atlas_size": [576, 48],
            "source_generated": f"{SOURCE_RES}/{unclaimed_source.name}",
            "source_model": SOURCE_MODEL,
            "asset_policy": "original_generated_runtime_sprite_no_homm3_art_import",
            "distinct_sprite_assignment": True,
            "assigned_map_object_id": object_id,
            "assigned_map_object_family": "neutral_dwelling",
            "presentation_role": f"unclaimed {case['site_name'].lower()}",
            "accessible_description": case["unclaimed_description"],
        }
        art_payload["object_assets"][controlled_asset] = {
            "path": ATLAS_RES,
            "atlas_region": controlled_region,
            "atlas_size": [576, 48],
            "source_generated": f"{SOURCE_RES}/{controlled_source.name}",
            "source_model": SOURCE_MODEL,
            "asset_policy": "original_generated_runtime_sprite_no_homm3_art_import",
            "distinct_sprite_assignment": True,
            "assigned_resource_site_id": site_id,
            "presentation_role": "controlled_veteran_company_muster_state",
            "accessible_description": case["controlled_description"],
        }
        art_payload["resource_site_sprites"][site_id] = {
            "asset_id": controlled_asset,
            "unclaimed_asset_id": unclaimed_asset,
            "fit": f"Exact original {case['site_name']} paired with its raised-standard, supplied veteran muster state.",
        }
        sprite_payload["object_sprite_mappings"][object_id] = {
            "asset_id": unclaimed_asset,
            "fit": f"Distinct original {case['site_name']} assigned to its guarded faction-veteran muster.",
            "assignment_source": "veteran_company_muster_completion",
            "family": "neutral_dwelling",
            "source_batch": 19,
        }
        if unclaimed_asset not in sprite_payload["distinct_asset_ids"]:
            sprite_payload["distinct_asset_ids"].append(unclaimed_asset)
        source_manifest_items.append({
            "site_id": site_id,
            "generation_original": f"{SOURCE_RES}/veteran_company_musters_identity_sheet.png",
            "prompt_summary": f"Paired unclaimed and controlled states for {case['site_name']}: {case['site_summary']}",
            "states": [
                {"state": "unclaimed", "source_path": f"{SOURCE_RES}/{unclaimed_source.name}", "source_sha256": sha(unclaimed_source), "atlas_region": unclaimed_region},
                {"state": "controlled", "source_path": f"{SOURCE_RES}/{controlled_source.name}", "source_sha256": sha(controlled_source), "atlas_region": controlled_region},
            ],
        })

    scenarios_payload["player_facing_active_scenario_count"] = len(scenarios_payload["items"])
    sprite_payload["source"]["new_generated_sprite_count"] = len(sprite_payload["distinct_asset_ids"])
    sprite_payload["source"]["generated_batch_count"] = 19
    batches = sprite_payload["source"]["generated_batches"]
    batch = {
        "batch_index": 19,
        "workspace_source_manifest": f"{SOURCE_RES}/manifest.json",
        "object_index_range": [211, 216],
    }
    batches[:] = [row for row in batches if row.get("batch_index") != 19] + [batch]
    coverage = sprite_payload["coverage"]
    coverage["authored_map_object_count"] = len(objects_payload["items"])
    coverage["new_distinct_non_decorative_asset_count"] = len(sprite_payload["distinct_asset_ids"])
    coverage["total_distinct_authored_map_object_count_after_pass"] = len(objects_payload["items"])
    coverage["by_family"]["neutral_dwelling"] = int(coverage["by_family"].get("neutral_dwelling", 0)) + (6 if int(coverage["by_family"].get("neutral_dwelling", 0)) == 57 else 0)

    source_manifest = {
        "source_model": SOURCE_MODEL,
        "content_batch_id": SLICE_ID,
        "asset_policy": "original_generated_runtime_sprite_no_homm3_art_import",
        "generation_original": f"{SOURCE_RES}/veteran_company_musters_identity_sheet.png",
        "generation_original_sha256": sha(SOURCE_DIR / "veteran_company_musters_identity_sheet.png"),
        "runtime_atlas": ATLAS_RES,
        "runtime_atlas_sha256": atlas_sha,
        "runtime_cell_size": [48, 48],
        "sheet_layout": "exact 4 columns by 3 rows; each faction pair is unclaimed then controlled",
        "shared_prompt_constraints": [
            "Six original paired-state fantasy strategy landmarks on genuine transparency.",
            "Each controlled state preserves the same structure while raising a pennant, adding light, or opening working geometry.",
            "Readable at 48 pixels; no people, creatures, text, logos, watermarks, UI frames, copied franchise art, or protected heraldry.",
        ],
        "items": source_manifest_items,
    }

    write_compact(CONTENT / "scenarios.json", scenarios_payload)
    write_armies(CONTENT / "army_groups.json", groups_payload)
    write_pretty(CONTENT / "resource_sites.json", sites_payload)
    write_pretty(CONTENT / "map_objects.json", objects_payload)
    write_pretty(ART_MANIFEST, art_payload)
    write_pretty(MAP_SPRITES, sprite_payload)
    write_pretty(SOURCE_DIR / "manifest.json", source_manifest)
    print(json.dumps({
        "slice_id": SLICE_ID,
        "scenarios": len(scenarios_payload["items"]),
        "army_groups": len(groups_payload["items"]),
        "resource_sites": len(sites_payload["items"]),
        "map_objects": len(objects_payload["items"]),
        "target_units": sum(len(case["targets"]) for case in CASES),
        "atlas_sha256": atlas_sha,
    }, indent=2))


if __name__ == "__main__":
    main()
