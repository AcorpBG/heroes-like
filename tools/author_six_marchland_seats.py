#!/usr/bin/env python3
"""Author the Six Marchland Seats production content batch."""

from __future__ import annotations

import copy
import hashlib
import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / "content"
OVERWORLD_ART_MANIFEST = ROOT / "art" / "overworld" / "manifest.json"
SLICE_ID = "content-six-marchland-seats-10184"


CASES = [
    {
        "prefix": "amberweir",
        "scenario_id": "rainledger-amberweir-long-march",
        "scenario_name": "Rainledger Amberweir Long March",
        "town_id": "town_amberweir_granary",
        "town_name": "Amberweir Granary",
        "base_town": "town_rainwrit_bastion",
        "exclusive_building": "building_embercourt_rainwrit_stormseal_treasury",
        "faction": "faction_embercourt",
        "hero": "hero_embercourt_belis_rainledger",
        "army": [("unit_embercourt_fordhook_cadets", 18), ("unit_embercourt_bargebow_crews", 12), ("unit_embercourt_ash_oath_bailiffs", 6), ("unit_embercourt_sluicefire_lindworms", 2)],
        "enemy_faction": "faction_mireclaw",
        "enemy_town": "town_blackfen_gate",
        "rival_hero": "hero_orrik",
        "encounters": ["encounter_briarmarshal_drum_cordon", "encounter_mudkeel_fenbell_commission", "encounter_reedscript_fenhound_lexicon", "encounter_vellum_gorefen_audit", "encounter_sluice_raiders"],
        "terrain": ("grass", "dirt"),
        "rare": "embergrain",
        "rare_site": "site_embergrain_warm_granary",
        "artifact": "artifact_tollstone_ring",
        "seed": 47100,
        "role": "river granary stronghold",
        "identity": "A rain-fed river fortress where civic ledgers, sluice power, and protected grain rotations turn recovery into sustained road pressure.",
        "strategic": "Amberweir converts held river lanes into dependable stores and keeps damaged companies supplied during a long march.",
        "growth_unit": "unit_embercourt_bargebow_crews",
        "garrison": [("unit_embercourt_fordhook_cadets", 18), ("unit_embercourt_bargebow_crews", 10), ("unit_embercourt_ash_oath_bailiffs", 4)],
        "backdrop": "town_amberweir_granary",
    },
    {
        "prefix": "moonbite",
        "scenario_id": "votivejaw-moonbite-long-march",
        "scenario_name": "Votivejaw Moonbite Long March",
        "town_id": "town_moonbite_reedshrine",
        "town_name": "Moonbite Reedshrine",
        "base_town": "town_hollowreed_sanctuary",
        "exclusive_building": "building_mireclaw_hollowreed_moonwax_ossuary",
        "faction": "faction_mireclaw",
        "hero": "hero_mireclaw_nix_votivejaw",
        "army": [("unit_mireclaw_reedsnare_kin", 18), ("unit_mireclaw_mudglass_slingers", 12), ("unit_mireclaw_bogplate_maulers", 6), ("unit_mireclaw_ferrychain_lashers", 3)],
        "enemy_faction": "faction_sunvault",
        "enemy_town": "town_prismhearth",
        "rival_hero": "hero_sunvault_essa_daynote",
        "encounters": ["encounter_daynote_refraction_bench", "encounter_glassmarshal_counterseal_battery", "encounter_halometer_daylight_crown", "encounter_lenscaptain_reedbarge_survey", "encounter_tarn_daybreak_hunt"],
        "terrain": ("mire", "swamp"),
        "rare": "peatwax",
        "rare_site": "site_peatwax_reed_yard",
        "artifact": "artifact_mudglass_beads",
        "seed": 47200,
        "role": "votive marsh sanctuary",
        "identity": "A crescent shrine-town where moon pools, votive jars, and reed tolls turn battlefield tribute into spell and pressure tempo.",
        "strategic": "Moonbite controls the peatwater causeways and funds aggressive shrine companies from every banner that crosses its crescent court.",
        "growth_unit": "unit_mireclaw_mudglass_slingers",
        "garrison": [("unit_mireclaw_reedsnare_kin", 18), ("unit_mireclaw_mudglass_slingers", 10), ("unit_mireclaw_bogplate_maulers", 4)],
        "backdrop": "town_moonbite_reedshrine",
    },
    {
        "prefix": "splitprism",
        "scenario_id": "facetlane-splitprism-long-march",
        "scenario_name": "Facetlane Splitprism Long March",
        "town_id": "town_splitprism_duelcourt",
        "town_name": "Splitprism Duelcourt",
        "base_town": "town_meridian_choirhold",
        "exclusive_building": "building_sunvault_meridian_seven_facet_orrery",
        "faction": "faction_sunvault",
        "hero": "hero_sunvault_renn_facetlane",
        "army": [("unit_sunvault_shard_wardens", 18), ("unit_sunvault_prism_adepts", 12), ("unit_sunvault_mirror_duelists", 6), ("unit_sunvault_solar_array_striders", 3)],
        "enemy_faction": "faction_thornwake",
        "enemy_town": "town_briarwheel_enclave",
        "rival_hero": "hero_thornwake_veyra_seedseer",
        "encounters": ["encounter_damar_worldroot_wake", "encounter_graftsibyl_wake_cordon", "encounter_loamchant_crystal_sump_binding", "encounter_rootglass_border_cordon", "encounter_rootshade_facet_breaker"],
        "terrain": ("sand", "rough"),
        "rare": "aetherglass",
        "rare_site": "site_aetherglass_lens_house",
        "artifact": "artifact_choir_tuning_fork",
        "seed": 47300,
        "role": "duel-line observatory",
        "identity": "A divided prism observatory whose mirrored courts train timing, focus, and exact response along exposed desert lanes.",
        "strategic": "Splitprism rewards disciplined formations and gives a precise commander clean sightlines across the marchland approaches.",
        "growth_unit": "unit_sunvault_mirror_duelists",
        "garrison": [("unit_sunvault_shard_wardens", 18), ("unit_sunvault_prism_adepts", 10), ("unit_sunvault_mirror_duelists", 4)],
        "backdrop": "town_splitprism_duelcourt",
    },
    {
        "prefix": "woundroot",
        "scenario_id": "greenbarrow-woundroot-long-march",
        "scenario_name": "Greenbarrow Woundroot Long March",
        "town_id": "town_woundroot_hearthgrove",
        "town_name": "Woundroot Hearthgrove",
        "base_town": "town_crownroot_refuge",
        "exclusive_building": "building_thornwake_crownroot_heartseed_parliament",
        "faction": "faction_thornwake",
        "hero": "hero_thornwake_merek_greenbarrow",
        "army": [("unit_thornwake_seedcutters", 20), ("unit_thornwake_bramblekite_needlers", 12), ("unit_thornwake_seedshield_wardens", 7), ("unit_thornwake_sporeglass_menders", 3)],
        "enemy_faction": "faction_brasshollow",
        "enemy_town": "town_cindercoil_foundry",
        "rival_hero": "hero_brasshollow_pava_ashmeter",
        "encounters": ["encounter_debtrune_lastbell_audit", "encounter_horizon_blackbell_verdict_gantry", "encounter_ironclause_ninefold_assize", "encounter_red_ledger_pile_driver", "encounter_tallyspring_proving_rack"],
        "terrain": ("forest", "grass"),
        "rare": "verdant_grafts",
        "rare_site": "site_verdant_graft_nursery",
        "artifact": "artifact_living_bridge_knot",
        "seed": 47400,
        "role": "recovery hearthgrove",
        "identity": "A living hollow settlement where root-hearths and graft gardens return wounded companies to the road without severing the old canopy.",
        "strategic": "Woundroot anchors recovery across controlled woodland and keeps a patient army intact through repeated frontier battles.",
        "growth_unit": "unit_thornwake_sporeglass_menders",
        "garrison": [("unit_thornwake_seedcutters", 20), ("unit_thornwake_bramblekite_needlers", 10), ("unit_thornwake_seedshield_wardens", 5)],
        "backdrop": "town_woundroot_hearthgrove",
    },
    {
        "prefix": "whitegauge",
        "scenario_id": "gaugesavant-whitegauge-long-march",
        "scenario_name": "Gauge-Savant Whitegauge Long March",
        "town_id": "town_whitegauge_calibration_yard",
        "town_name": "Whitegauge Calibration Yard",
        "base_town": "town_blackbell_foundry",
        "exclusive_building": "building_brasshollow_blackbell_grand_assay_bell",
        "faction": "faction_brasshollow",
        "hero": "hero_brasshollow_lina_gaugesavant",
        "army": [("unit_brasshollow_scrip_haulers", 20), ("unit_brasshollow_quenchspool_slingers", 12), ("unit_brasshollow_gaugefire_arbalists", 7), ("unit_brasshollow_boiler_rivetcasters", 3)],
        "enemy_faction": "faction_veilmourn",
        "enemy_town": "town_gloamwake_anchorage",
        "rival_hero": "hero_veilmourn_thir_obituaryink",
        "encounters": ["encounter_keelwarden_dustjack_screen", "encounter_mistcorsair_foghook_boarding", "encounter_pale_sounding_memory_watch", "encounter_vowless_drowned_requiem", "encounter_gloamkeel_sounding_barricade"],
        "terrain": ("rough", "dirt"),
        "rare": "brass_scrip",
        "rare_site": "site_brass_scrip_mint",
        "artifact": "artifact_pressure_gauge_reliquary",
        "seed": 47500,
        "role": "calibration works",
        "identity": "A white-ceramic pressure yard where brass gauges, datum rails, and controlled furnace trials turn machine companies into exact field instruments.",
        "strategic": "Whitegauge favors measured ranged pressure and keeps its workshops inside safe heat tolerances during a prolonged campaign.",
        "growth_unit": "unit_brasshollow_gaugefire_arbalists",
        "garrison": [("unit_brasshollow_scrip_haulers", 20), ("unit_brasshollow_quenchspool_slingers", 10), ("unit_brasshollow_gaugefire_arbalists", 5)],
        "backdrop": "town_whitegauge_calibration_yard",
    },
    {
        "prefix": "dreamwake",
        "scenario_id": "wakeoracle-dreamwake-long-march",
        "scenario_name": "Wakeoracle Dreamwake Long March",
        "town_id": "town_dreamwake_oracle_harbor",
        "town_name": "Dreamwake Oracle Harbor",
        "base_town": "town_pale_sounding_harbor",
        "exclusive_building": "building_veilmourn_pale_sounding_last_memory_beacon",
        "faction": "faction_veilmourn",
        "hero": "hero_veilmourn_morwen_wakeoracle",
        "army": [("unit_veilmourn_bellwake_oars", 18), ("unit_veilmourn_mourning_lanterns", 12), ("unit_veilmourn_maskglass_corsairs", 6), ("unit_veilmourn_undertow_harpooners", 3)],
        "enemy_faction": "faction_embercourt",
        "enemy_town": "town_cinderlock_bastion",
        "rival_hero": "hero_embercourt_helva_tollbrand",
        "encounters": ["encounter_beaconscribe_frostwharf_writ", "encounter_lockmaster_archive_seal", "encounter_railhead_lockward_auditors", "encounter_rainbrand_border_cordon", "encounter_horizon_rainwrit_charter_gate"],
        "terrain": ("snow", "mire"),
        "rare": "memory_salt",
        "rare_site": "site_memory_salt_pan",
        "artifact": "artifact_black_sail_compass",
        "seed": 47600,
        "role": "oracle harbor",
        "identity": "A fogbound bell harbor whose tide pools and memory chimes reveal hidden sea lanes before hostile sails enter the inner wake.",
        "strategic": "Dreamwake extends scouting through fog and gives wake-readers a stable harbor from which to contest distant routes.",
        "growth_unit": "unit_veilmourn_mourning_lanterns",
        "garrison": [("unit_veilmourn_bellwake_oars", 18), ("unit_veilmourn_mourning_lanterns", 10), ("unit_veilmourn_maskglass_corsairs", 4)],
        "backdrop": "town_dreamwake_oracle_harbor",
    },
]


def load(name: str) -> dict:
    return json.loads((CONTENT / name).read_text(encoding="utf-8"))


def upsert(items: list[dict], row: dict) -> None:
    for index, current in enumerate(items):
        if current.get("id") == row["id"]:
            items[index] = row
            return
    items.append(row)


def dump_army_groups(payload: dict) -> str:
    text = json.dumps(payload, indent=2)
    return re.sub(
        r'\{\n\s+"unit_id": ("[^"]+"),\n\s+"count": ([0-9]+)\n\s+\}',
        r'{"unit_id": \1, "count": \2}',
        text,
    ) + "\n"


def terrain_map(primary: str, secondary: str, seed: int) -> list[list[str]]:
    board: list[list[str]] = []
    for y in range(12):
        row: list[str] = []
        for x in range(18):
            fringe = y in (0, 11) or x in (0, 17)
            varied = ((x * 7 + y * 11 + seed) % 17) in (0, 1, 2)
            row.append(secondary if fringe and varied or varied and (x + y) % 3 == 0 else primary)
        board.append(row)
    return board


def town_record(case: dict, town_by_id: dict[str, dict]) -> dict:
    town = copy.deepcopy(town_by_id[case["base_town"]])
    town.update({
        "id": case["town_id"],
        "name": case["town_name"],
        "scenic_backdrop_path": f"res://art/towns/runtime/backdrops/marchland_seats/{case['backdrop']}.png",
        "identity_summary": case["identity"],
        "strategic_role": case["role"],
        "strategic_summary": case["strategic"],
        "content_status": "marchland_seat_live",
        "content_batch_id": SLICE_ID,
        "marchland_seat": {
            "lead_hero_id": case["hero"],
            "scenario_id": case["scenario_id"],
            "long_form_board_size": [18, 12],
        },
    })
    town["logistics_plan"] = copy.deepcopy(town.get("logistics_plan", {}))
    town["logistics_plan"].update({
        "support_radius": max(7, int(town["logistics_plan"].get("support_radius", 6))),
        "recovery_relief": max(1, int(town["logistics_plan"].get("recovery_relief", 1))),
        "vulnerability_summary": f"If {case['town_name']} loses its common-road sources or {case['rare'].replace('_', ' ')} route, its long-march identity collapses into an isolated garrison.",
    })
    town["economy"] = copy.deepcopy(town.get("economy", {}))
    town["economy"]["base_income"] = {"gold": 160}
    town["economy"]["pressure_bonus"] = 2
    town["recruitment"] = copy.deepcopy(town.get("recruitment", {}))
    town["recruitment"].update({
        "readiness_bonus": 5,
        "growth_bonus": {case["growth_unit"]: 1},
        "cost_discount_percent": {case["growth_unit"]: 5},
    })
    town["garrison"] = [{"unit_id": unit_id, "count": count} for unit_id, count in case["garrison"]]
    for route_key in ("starting_building_ids", "buildable_building_ids"):
        town[route_key] = [building_id for building_id in town.get(route_key, []) if building_id != case["exclusive_building"]]
    return town


def scenario_record(case: dict) -> dict:
    prefix = case["prefix"]
    encounter_placements = []
    coords = [(5, 3), (5, 8), (11, 3), (11, 8)]
    for index, ((x, y), encounter_id) in enumerate(zip(coords, case["encounters"][:4]), start=1):
        placement = {
            "placement_id": f"{prefix}_front_{index}",
            "encounter_id": encounter_id,
            "x": x,
            "y": y,
            "difficulty": "medium" if index < 4 else "high",
            "combat_seed": case["seed"] + index,
            "prefer_identity_landmark": True,
        }
        if index == 4:
            placement.update({
                "spawned_by_faction_id": case["enemy_faction"],
                "enemy_commander_state": {"roster_hero_id": case["rival_hero"], "faction_id": case["enemy_faction"]},
            })
        encounter_placements.append(placement)
    victories = [
        {"id": f"{prefix}_capture_enemy_seat", "label": "Capture the opposing marchland seat", "type": "town_owned_by_player", "placement_id": f"{prefix}_enemy_town"},
    ]
    victories.extend({"id": f"{prefix}_clear_front_{index}", "label": f"Break march front {index}", "type": "encounter_resolved", "placement_id": f"{prefix}_front_{index}"} for index in range(1, 5))
    victories.append({"id": f"{prefix}_repulse_counterstroke", "label": "Repulse the marchland counterstroke", "type": "encounter_resolved", "placement_id": f"{prefix}_counterstroke"})
    resource_nodes = [
        {"placement_id": f"{prefix}_wood_north", "site_id": "site_wood_wagon", "x": 1, "y": 1},
        {"placement_id": f"{prefix}_ore_north", "site_id": "site_ore_crates", "x": 4, "y": 1},
        {"placement_id": f"{prefix}_rare_route", "site_id": case["rare_site"], "x": 8, "y": 1},
        {"placement_id": f"{prefix}_exchange", "site_id": "site_frontier_rare_exchange", "x": 12, "y": 1},
        {"placement_id": f"{prefix}_waystone", "site_id": "site_waystone_cache", "x": 16, "y": 1},
        {"placement_id": f"{prefix}_wood_south", "site_id": "site_wood_wagon", "x": 1, "y": 10},
        {"placement_id": f"{prefix}_ore_south", "site_id": "site_ore_crates", "x": 4, "y": 10},
        {"placement_id": f"{prefix}_rare_relief", "site_id": case["rare_site"], "x": 8, "y": 10},
        {"placement_id": f"{prefix}_scout_shrine", "site_id": "site_scout_shrine", "x": 12, "y": 10},
        {"placement_id": f"{prefix}_sanctum", "site_id": "site_roadside_sanctum", "x": 16, "y": 10},
    ]
    return {
        "id": case["scenario_id"],
        "name": case["scenario_name"],
        "selection": {
            "summary": f"Lead a long march from {case['town_name']}, break four fixed fronts and a counterstroke, then capture the opposing seat before the development road closes.",
            "recommended_difficulty": "normal",
            "map_size_label": "Long March (18x12)",
            "player_summary": f"The underused commander begins at a new developable {case['role']} with a balanced four-stack field company.",
            "enemy_summary": "Four authored fronts, a roster-backed rival, an enemy town, and a triggered counterstroke contest the complete development route.",
            "availability": {"campaign": False, "skirmish": True},
        },
        "map_size": {"width": 18, "height": 12},
        "player_faction_id": case["faction"],
        "player_army_id": f"army_{prefix}_long_march_company",
        "hero_id": case["hero"],
        "starting_resources": {"gold": 3600, "wood": 7, "ore": 7, case["rare"]: 2},
        "map": terrain_map(*case["terrain"], case["seed"]),
        "start": {"x": 2, "y": 5},
        "hero_starts": [case["hero"]],
        "objectives": {
            "victory_text": f"{case['town_name']} holds the full march and the opposing seat has fallen.",
            "defeat_text": "The home seat falls, enemy pressure reaches twenty-eight, or Day 24 closes the long march.",
            "victory": victories,
            "defeat": [
                {"id": f"{prefix}_lose_home", "label": f"Keep {case['town_name']} under player control", "type": "town_not_owned_by_player", "placement_id": f"{prefix}_home"},
                {"id": f"{prefix}_pressure", "label": "Keep enemy pressure below 28", "type": "enemy_pressure_at_least", "faction_id": case["enemy_faction"], "threshold": 28},
                {"id": f"{prefix}_deadline", "label": "Complete the march before Day 24", "type": "day_at_least", "day": 24},
            ],
        },
        "script_hooks": [
            {"id": f"{prefix}_day_two_relief", "priority": 140, "conditions": [{"type": "day_at_least", "day": 2}, {"type": "town_owned_by_player", "placement_id": f"{prefix}_home"}], "effects": [{"type": "add_resources", "resources": {"gold": 550, "wood": 1, "ore": 1}}, {"type": "message", "text": f"{case['town_name']} releases its first long-road relief wagons."}]},
            {"id": f"{prefix}_north_front_stores", "priority": 125, "conditions": [{"type": "encounter_resolved", "placement_id": f"{prefix}_front_1"}], "effects": [{"type": "add_resources", "resources": {"gold": 300, case["rare"]: 1}}, {"type": "message", "text": "The northern front yields stores for the next leg of the march."}]},
            {"id": f"{prefix}_south_front_recruits", "priority": 115, "conditions": [{"type": "encounter_resolved", "placement_id": f"{prefix}_front_2"}], "effects": [{"type": "town_add_recruits", "placement_id": f"{prefix}_home", "recruits": {case["growth_unit"]: 4}}, {"type": "message", "text": "Freed road companies reinforce the home seat."}]},
            {"id": f"{prefix}_counterstroke", "priority": 105, "conditions": [{"type": "encounter_resolved", "placement_id": f"{prefix}_front_2"}], "effects": [{"type": "spawn_encounter", "placement": {"placement_id": f"{prefix}_counterstroke", "encounter_id": case["encounters"][4], "x": 14, "y": 5, "difficulty": "high", "combat_seed": case["seed"] + 5, "spawned_by_faction_id": case["enemy_faction"], "prefer_identity_landmark": True}}, {"type": "message", "text": "The broken flank calls a counterstroke onto the central road."}]},
            {"id": f"{prefix}_day_eight_pressure", "priority": 80, "conditions": [{"type": "day_at_least", "day": 8}, {"type": "objective_not_met", "objective_id": f"{prefix}_capture_enemy_seat"}], "effects": [{"type": "add_enemy_pressure", "faction_id": case["enemy_faction"], "amount": 3}, {"type": "message", "text": "The uncaptured enemy seat sends another levy into the marchland."}]},
        ],
        "towns": [
            {"placement_id": f"{prefix}_home", "town_id": case["town_id"], "x": 0, "y": 5, "owner": "player", "built_buildings": ["building_market_square"]},
            {"placement_id": f"{prefix}_enemy_town", "town_id": case["enemy_town"], "x": 17, "y": 5, "owner": "enemy"},
        ],
        "enemy_factions": [{
            "faction_id": case["enemy_faction"],
            "label": "Marchland Opposition",
            "pressure_per_day": 1,
            "pressure_per_enemy_town": 1,
            "raid_threshold": 9,
            "max_active_raids": 2,
            "raid_pillage_delay": 2,
            "raid_pillage": {"gold": 180},
            "raid_encounter_ids": case["encounters"][:2],
            "spawn_points": [{"x": 17, "y": 1}, {"x": 17, "y": 10}],
            "siege_target_placement_id": f"{prefix}_home",
            "priority_target_placement_ids": [f"{prefix}_home", f"{prefix}_rare_route", f"{prefix}_rare_relief"],
        }],
        "resource_nodes": resource_nodes,
        "artifact_nodes": [
            {"placement_id": f"{prefix}_faction_relic", "artifact_id": case["artifact"], "x": 7, "y": 5},
            {"placement_id": f"{prefix}_field_standard", "artifact_id": "artifact_warcrest_pennon", "x": 12, "y": 5},
        ],
        "encounters": encounter_placements,
        "content_status": "marchland_seat_long_form_skirmish_live",
        "content_batch_id": SLICE_ID,
        "scenario_family": "marchland_seat_long_march",
        "deterministic_seed": case["seed"],
        "marchland_seat": {"town_id": case["town_id"], "lead_hero_id": case["hero"], "direct_front_count": 4, "counterstroke_placement_id": f"{prefix}_counterstroke"},
    }


def main() -> None:
    towns_payload = load("towns.json")
    factions_payload = load("factions.json")
    groups_payload = load("army_groups.json")
    scenarios_payload = load("scenarios.json")
    overworld_art = json.loads(OVERWORLD_ART_MANIFEST.read_text(encoding="utf-8"))
    town_by_id = {row["id"]: row for row in towns_payload["items"]}
    faction_by_id = {row["id"]: row for row in factions_payload["items"]}
    for case in CASES:
        upsert(towns_payload["items"], town_record(case, town_by_id))
        faction_town_ids = faction_by_id[case["faction"]].setdefault("town_ids", [])
        if case["town_id"] not in faction_town_ids:
            faction_town_ids.append(case["town_id"])
        upsert(groups_payload["items"], {
            "id": f"army_{case['prefix']}_long_march_company",
            "name": f"{case['town_name']} Long-March Company",
            "faction_id": case["faction"],
            "stacks": [{"unit_id": unit_id, "count": count} for unit_id, count in case["army"]],
            "content_status": "marchland_seat_player_company_live",
            "content_batch_id": SLICE_ID,
        })
        upsert(scenarios_payload["items"], scenario_record(case))
        town_asset_id = f"town_identity_{case['town_id'].removeprefix('town_')}"
        faction_stem = case["faction"].removeprefix("faction_")
        runtime_path = ROOT / "art" / "overworld" / "runtime" / "objects" / "towns" / "factions" / f"{faction_stem}.png"
        scenic_source = ROOT / "art" / "towns" / "source" / "generated" / "marchland_seats" / f"{case['backdrop']}_source.png"
        overworld_art.setdefault("town_identity_sprites", {})[case["town_id"]] = town_asset_id
        overworld_art.setdefault("object_assets", {})[town_asset_id] = {
            "path": f"res://art/overworld/runtime/objects/towns/factions/{faction_stem}.png",
            "runtime_sha256": hashlib.sha256(runtime_path.read_bytes()).hexdigest(),
            "source_atlas": "res://art/overworld/source/faction_town_sprite_atlas.png",
            "scenic_source": f"res://art/towns/source/generated/marchland_seats/{case['backdrop']}_source.png",
            "scenic_source_sha256": hashlib.sha256(scenic_source.read_bytes()).hexdigest(),
            "source_model": "built_in_image_gen_original_marchland_seat_scenic_with_faction_overworld_silhouette",
            "assigned_town_id": case["town_id"],
            "assigned_faction_id": case["faction"],
            "presentation_role": case["role"].replace(" ", "_"),
            "accessible_description": case["identity"],
        }
    scenarios_payload["player_facing_active_scenario_count"] = len(scenarios_payload["items"])
    # Batch ownership belongs on the authored records, not on the shared catalog.
    # Keep the catalog root schema stable for existing consumers.
    towns_payload.pop("content_batch_id", None)
    towns_payload.pop("player_facing_town_count", None)
    (CONTENT / "towns.json").write_text(json.dumps(towns_payload, indent=2) + "\n", encoding="utf-8")
    (CONTENT / "factions.json").write_text(json.dumps(factions_payload, indent=2) + "\n", encoding="utf-8")
    (CONTENT / "army_groups.json").write_text(dump_army_groups(groups_payload), encoding="utf-8")
    (CONTENT / "scenarios.json").write_text(json.dumps(scenarios_payload, separators=(",", ":")) + "\n", encoding="utf-8")
    OVERWORLD_ART_MANIFEST.write_text(json.dumps(overworld_art, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({
        "slice_id": SLICE_ID,
        "town_count": len(towns_payload["items"]),
        "army_group_count": len(groups_payload["items"]),
        "scenario_count": len(scenarios_payload["items"]),
        "new_town_ids": [case["town_id"] for case in CASES],
        "new_scenario_ids": [case["scenario_id"] for case in CASES],
        "direct_battles": 24,
        "scripted_counterstrokes": 6,
    }, indent=2))


if __name__ == "__main__":
    main()
