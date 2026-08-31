#!/usr/bin/env python3
"""Author six town-exclusive Marchland retinues and their dwellings."""

from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / "content"
SLICE_ID = "content-six-marchland-local-retinues-10184"
UNIT_SOURCE_ROOT = ROOT / "art" / "units" / "source" / "generated" / "marchland_local_retinues"
UNIT_CURATED_ROOT = ROOT / "art" / "units" / "source" / "curated"
BUILDING_SOURCE_ROOT = ROOT / "art" / "towns" / "source" / "generated" / "buildings" / "marchland_local_retinues"
BUILDING_CURATED_ROOT = ROOT / "art" / "towns" / "source" / "buildings" / "curated"
GENERATOR_ROOT = Path("/root/.codex/generated_images/019fe72a-30b1-76f3-b911-385c4444bd16")


CASES = [
    {
        "prefix": "amberweir",
        "town_id": "town_amberweir_granary",
        "scenario_id": "rainledger-amberweir-long-march",
        "army_id": "army_amberweir_long_march_company",
        "faction_id": "faction_embercourt",
        "unit_id": "unit_embercourt_amberweir_lockpike_wardens",
        "unit_name": "Lockpike Wardens",
        "building_id": "building_embercourt_amberweir_sluiceguard_lock",
        "building_name": "Amberweir Sluiceguard Lock",
        "role": "melee", "hp": 24, "attack": 8, "defense": 11,
        "damage": [5, 8], "speed": 4, "initiative": 6, "cost": {"gold": 300, "wood": 1},
        "school": "beacon",
        "abilities": [
            {"id": "reach", "name": "Lockpike Reach", "description": "Forked lockpikes hold a half-closed sluice lane before the enemy line can settle.", "distance_one_multiplier": 0.9, "held_objective_types": ["cover_line", "obstruction_line", "breach_point"]},
            {"id": "brace", "name": "Sluice-Shield Brace", "description": "A linked wall of lock shields turns pressure at a held crossing into a disciplined counterstroke.", "retaliation_multiplier": 1.05, "held_objective_retaliation_multiplier": 1.08, "held_objective_types": ["cover_line", "obstruction_line", "breach_point"], "defending_cohesion_bonus": 2, "status_id": "status_staggered", "status_label": "Lockpike-Staggered", "duration_rounds": 1, "modifiers": {"initiative": -1}},
        ],
        "requires": ["building_embercourt_bargebow_slip", "building_embercourt_oath_pikehall"],
        "building_cost": {"gold": 1300},
        "building_description": "A fortified river lock drills local pike wardens to defend Amberweir's working sluices without halting the grain road.",
        "unit_prompt": "Polished hand-painted transparent production game-unit master of one original Amberweir Lockpike Warden, a disciplined woman in rust-red and bronze river armor carrying a long forked sluice pike and broad lock-gate shield, full-body three-quarter defensive pose, strong 96px silhouette, no scenery, text, logo, watermark, franchise design, or cropped limbs.",
        "building_prompt": "Polished hand-painted transparent production town-building master of the original Amberweir Sluiceguard Lock, a compact fortified river lock with bronze waterwheel, heavy timber floodgate, pike racks, rust-red tile roofs and civic banners, elevated three-quarter isometric view, no scenery, people, text, logo, watermark, or franchise design.",
        "unit_generated": "exec-7a352357-3c73-44cf-bd68-d4b1ccc1768c.png",
        "building_generated": "exec-7213090c-738b-49a4-868e-b30f5f149ca4.png",
    },
    {
        "prefix": "moonbite", "town_id": "town_moonbite_reedshrine", "scenario_id": "votivejaw-moonbite-long-march", "army_id": "army_moonbite_long_march_company", "faction_id": "faction_mireclaw",
        "unit_id": "unit_mireclaw_moonbite_votive_drummers", "unit_name": "Votive Drummers", "building_id": "building_mireclaw_moonbite_votive_drum_court", "building_name": "Moonbite Votive Drum-Court",
        "role": "ranged", "hp": 19, "attack": 8, "defense": 8, "damage": [4, 7], "speed": 5, "initiative": 8, "cost": {"gold": 290, "wood": 1}, "school": "mire",
        "abilities": [
            {"id": "harry", "name": "Votive Cadence", "description": "Once per battle, the crescent drum fixes one veteran line inside a tightening moonlit rhythm.", "status_id": "status_mire_harried", "status_label": "Votive-Harried", "duration_rounds": 1, "uses_per_battle": 1, "target_min_tier": 3, "momentum_gain": 0, "modifiers": {"initiative": -1, "cohesion": -1}, "ai_target_priority_bonus": 0.25},
            {"id": "volley", "name": "Lanternbeat Volley", "description": "Reed darts arrive on the drum's second beat and bite harder into harried formations.", "damage_multiplier": 1.04, "min_distance": 1, "status_ids": ["status_mire_harried", "status_harried"], "status_damage_multiplier": 1.05, "ally_defending_multiplier": 1.02},
        ],
        "requires": ["building_mireclaw_war_drum_circle", "building_mireclaw_chainboom_ferry"], "building_cost": {"gold": 1280},
        "building_description": "A crescent reed amphitheater trains votive drummers to carry Moonbite's binding cadence beyond the shrine pools.",
        "unit_prompt": "Polished hand-painted transparent production game-unit master of one original Moonbite Votive Drummer, a marsh woman with a crescent hip drum, reed-and-bone shield, ritual mallet and hanging amber votive lanterns, full-body three-quarter battle pose, strong 96px silhouette, no scenery, text, logo, watermark, franchise design, or cropped limbs.",
        "building_prompt": "Polished hand-painted transparent production town-building master of the original Moonbite Votive Drum-Court, a compact crescent reed amphitheater centered on an immense hide drum with bone arches, votive lanterns and rough plank stages, elevated three-quarter isometric view, no scenery, people, text, logo, watermark, or franchise design.",
        "unit_generated": "exec-02ecbb5d-bf7b-4986-a82a-dad406b5ed51.png", "building_generated": "exec-26aa6683-082b-4c67-907e-1e73a5698407.png",
    },
    {
        "prefix": "splitprism", "town_id": "town_splitprism_duelcourt", "scenario_id": "facetlane-splitprism-long-march", "army_id": "army_splitprism_long_march_company", "faction_id": "faction_sunvault",
        "unit_id": "unit_sunvault_splitprism_parallax_fencers", "unit_name": "Parallax Fencers", "building_id": "building_sunvault_splitprism_parallax_duel_hall", "building_name": "Splitprism Parallax Duel Hall",
        "role": "melee", "hp": 21, "attack": 10, "defense": 8, "damage": [6, 9], "speed": 7, "initiative": 9, "cost": {"gold": 320, "ore": 1}, "school": "lens",
        "abilities": [
            {"id": "reach", "name": "Parallax Lunge", "description": "Paired prism blades find a reflected half-step through an open lens lane.", "distance_one_multiplier": 0.95, "held_objective_types": ["cover_line", "lane_battery", "ritual_pylon"]},
            {"id": "backstab", "name": "Second-Facet Cut", "description": "The amber blade arrives through the timing broken by the blue blade's first reflection.", "damage_multiplier": 1.04, "momentum_gain": 1, "primary_melee_only": True, "status_ids": ["status_harried", "status_staggered"]},
        ],
        "requires": ["building_sunvault_mirror_forge", "building_sunvault_harmonic_cloister"], "building_cost": {"gold": 1320},
        "building_description": "A bifurcated mirror court trains local fencers to attack one line from two measured angles.",
        "unit_prompt": "Polished hand-painted transparent production game-unit master of one original Splitprism Parallax Fencer, a poised woman in white and cobalt armor wielding paired asymmetric blue and amber prism blades, full-body three-quarter dueling pose, strong 96px silhouette, no scenery, text, logo, watermark, franchise design, or cropped limbs.",
        "building_prompt": "Polished hand-painted transparent production town-building master of the original Splitprism Parallax Duel Hall, a compact white-stone mirror court split by blue and amber crystal arches around a circular dueling floor, elevated three-quarter isometric view, no scenery, people, text, logo, watermark, or franchise design.",
        "unit_generated": "exec-54fd7960-9348-4ce2-a104-387a728d4da2.png", "building_generated": "exec-659a7261-3ef2-4d2f-a375-74ba78e2f680.png",
    },
    {
        "prefix": "woundroot", "town_id": "town_woundroot_hearthgrove", "scenario_id": "greenbarrow-woundroot-long-march", "army_id": "army_woundroot_long_march_company", "faction_id": "faction_thornwake",
        "unit_id": "unit_thornwake_woundroot_hearthseed_slingers", "unit_name": "Hearthseed Slingers", "building_id": "building_thornwake_woundroot_hearthseed_nursery", "building_name": "Woundroot Hearthseed Nursery",
        "role": "ranged", "hp": 20, "attack": 8, "defense": 9, "damage": [5, 8], "speed": 5, "initiative": 7, "cost": {"gold": 285, "wood": 2}, "school": "root",
        "abilities": [
            {"id": "harry", "name": "Hearthseed Snare", "description": "Once per battle, a warm seed-stone cracks into roots beneath one veteran line.", "status_id": "status_rooted", "status_label": "Hearthseed-Rooted", "duration_rounds": 1, "uses_per_battle": 1, "target_min_tier": 3, "momentum_gain": 0, "modifiers": {"defense": -1}, "ai_target_priority_bonus": 0.25},
            {"id": "volley", "name": "Root-Cradle Cast", "description": "Living sling staves release together and strike hardest where roots already hold the lane.", "damage_multiplier": 1.04, "min_distance": 1, "status_ids": ["status_rooted", "status_staggered"], "status_damage_multiplier": 1.05, "ally_defending_multiplier": 1.02},
        ],
        "requires": ["building_thornwake_barkmantle_run", "building_thornwake_pilgrim_orchard"], "building_cost": {"gold": 1260},
        "building_description": "A rootwoven greenhouse and communal hearth cultivates living sling staves and warm seed-stones for Woundroot's local defenders.",
        "unit_prompt": "Polished hand-painted transparent production game-unit master of one original Woundroot Hearthseed Slinger, a forest woman with living-wood sling staff, root shield and glowing amber seed stones, full-body three-quarter battle pose, strong 96px silhouette, no scenery, text, logo, watermark, franchise design, or cropped limbs.",
        "building_prompt": "Stylized fantasy strategy town-building source art of the original Woundroot Hearthseed Nursery, a compact rootwoven greenhouse and hearth with amber seed beds, living-wood arches, sling-staff racks and leaf canopies, elevated three-quarter isometric view, transparent background, no scenery, people, text, logo, watermark, or franchise design.",
        "unit_generated": "exec-8b2374ce-e210-40b5-89e4-2b6f67963b29.png", "building_generated": "exec-08e5a25c-fc06-4db5-a67f-e81f1c29cbc3.png",
    },
    {
        "prefix": "whitegauge", "town_id": "town_whitegauge_calibration_yard", "scenario_id": "gaugesavant-whitegauge-long-march", "army_id": "army_whitegauge_long_march_company", "faction_id": "faction_brasshollow",
        "unit_id": "unit_brasshollow_whitegauge_datum_lancers", "unit_name": "Datum Lancers", "building_id": "building_brasshollow_whitegauge_datum_railhouse", "building_name": "Whitegauge Datum Railhouse",
        "role": "melee", "hp": 25, "attack": 9, "defense": 10, "damage": [6, 9], "speed": 5, "initiative": 7, "cost": {"gold": 330, "ore": 2}, "school": "furnace",
        "abilities": [
            {"id": "reach", "name": "Datum Lance", "description": "A calibrated rail-lance remains exact across the final open pace.", "distance_one_multiplier": 1.0},
            {"id": "brace", "name": "Whitegauge Set", "description": "Plumb-weight bucklers lock the measured line before the enemy's impact arrives.", "retaliation_multiplier": 1.06, "defending_cohesion_bonus": 2, "status_id": "status_staggered", "status_label": "Gauge-Staggered", "duration_rounds": 1, "modifiers": {"initiative": -1}},
        ],
        "requires": ["building_brasshollow_pressure_rail", "building_brasshollow_boiler_cathedral"], "building_cost": {"gold": 1420},
        "building_description": "A white-ceramic calibration rail aligns local lances, bucklers, and pressure gauges to a single field datum.",
        "unit_prompt": "Polished hand-painted transparent production game-unit master of one original Whitegauge Datum Lancer in white ceramic, aged brass and soot-black plate carrying a long calibrated gauge lance and plumb-weight buckler, full-body three-quarter battle pose, strong 96px silhouette, no scenery, text, logo, watermark, franchise design, or cropped limbs.",
        "building_prompt": "Stylized fantasy strategy town-building source art of the original Whitegauge Datum Railhouse, a compact white ceramic, aged brass and soot-black calibration hall with long datum rail, lance racks, gauge tower and plumb weights, elevated three-quarter isometric view, transparent background, no scenery, people, text, logo, watermark, or franchise design.",
        "unit_generated": "exec-f2edc0e6-c44e-4ba4-9b3f-b8ff32f33123.png", "building_generated": "exec-66fc0cad-4f96-43c9-889e-771d2b3e0c8b.png",
    },
    {
        "prefix": "dreamwake", "town_id": "town_dreamwake_oracle_harbor", "scenario_id": "wakeoracle-dreamwake-long-march", "army_id": "army_dreamwake_long_march_company", "faction_id": "faction_veilmourn",
        "unit_id": "unit_veilmourn_dreamwake_tideglass_oracles", "unit_name": "Tideglass Oracles", "building_id": "building_veilmourn_dreamwake_tideglass_oratory", "building_name": "Dreamwake Tideglass Oratory",
        "role": "ranged", "hp": 20, "attack": 9, "defense": 8, "damage": [5, 9], "speed": 5, "initiative": 8, "cost": {"gold": 315, "wood": 1}, "school": "veil",
        "abilities": [
            {"id": "harry", "name": "Tideglass Reading", "description": "Once per battle, the oracle names the veteran line whose next motion is already reflected in the basin.", "status_id": "status_fogbound", "status_label": "Tideglass-Fogbound", "duration_rounds": 1, "uses_per_battle": 1, "target_min_tier": 3, "momentum_gain": 0, "modifiers": {"defense": -1, "initiative": -1}, "ai_target_priority_bonus": 0.25},
            {"id": "volley", "name": "Bell-Basin Surge", "description": "Cold tideglass shards cross the lane in a low wave and find fogbound ranks twice.", "damage_multiplier": 1.04, "min_distance": 1, "status_ids": ["status_fogbound", "status_harried"], "status_damage_multiplier": 1.05, "ally_defending_multiplier": 1.02},
        ],
        "requires": ["building_veilmourn_wake_oratory", "building_veilmourn_harpoon_gantry"], "building_cost": {"gold": 1340, "wood": 2},
        "building_description": "A crescent tideglass pavilion trains harbor oracles to read hostile motion in bell-basins and memory chimes.",
        "unit_prompt": "Polished hand-painted transparent production game-unit master of one original Dreamwake Tideglass Oracle, a maritime woman in navy and pearl robes carrying a crescent tideglass staff and reflecting basin shield, full-body three-quarter battle pose, strong 96px silhouette, no scenery, text, logo, watermark, franchise design, or cropped limbs.",
        "building_prompt": "Stylized fantasy strategy town-building source art of the original Dreamwake Tideglass Oratory, a compact fog-harbor oracle pavilion with navy roof, crescent translucent tideglass arch, reflecting bell-basin, silver memory chimes and black rope rigging, elevated three-quarter isometric view, transparent background, no scenery, people, text, logo, watermark, or franchise design.",
        "unit_generated": "exec-93501f61-04bb-4ca8-9f53-9bb85588f3b6.png", "building_generated": "exec-3209fdc3-f20f-4740-b846-786c27ae8e0a.png",
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


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def dump_groups(payload: dict) -> str:
    text = json.dumps(payload, indent=2)
    return re.sub(r'\{\n\s+"unit_id": ("[^"]+"),\n\s+"count": ([0-9]+)\n\s+\}', r'{"unit_id": \1, "count": \2}', text) + "\n"


def append_pretty_items(path: Path, rows: list[dict]) -> None:
    """Append authored rows without reformatting legacy hand-compacted records."""
    text = path.read_text(encoding="utf-8")
    missing = [row for row in rows if f'"id": "{row["id"]}"' not in text]
    if not missing:
        return
    marker = "\n  ]\n}\n"
    if marker not in text:
        raise RuntimeError(f"Unexpected JSON layout: {path}")
    rendered = []
    for row in missing:
        block = json.dumps(row, indent=2)
        rendered.append("\n".join(f"    {line}" for line in block.splitlines()))
    text = text.replace(marker, ",\n" + ",\n".join(rendered) + marker, 1)
    path.write_text(text, encoding="utf-8")


def main() -> None:
    units = load("units.json")
    buildings = load("buildings.json")
    towns = load("towns.json")
    groups = load("army_groups.json")
    scenarios = load("scenarios.json")
    town_by_id = {row["id"]: row for row in towns["items"]}
    group_by_id = {row["id"]: row for row in groups["items"]}
    scenario_by_id = {row["id"]: row for row in scenarios["items"]}
    authored_buildings: list[dict] = []

    for case in CASES:
        unit = {
            "id": case["unit_id"], "name": case["unit_name"], "faction_id": case["faction_id"],
            "role": case["role"], "tier": 4, "hp": case["hp"], "attack": case["attack"], "defense": case["defense"],
            "min_damage": case["damage"][0], "max_damage": case["damage"][1], "speed": case["speed"], "initiative": case["initiative"],
            "retaliations": 1, "ranged": case["role"] == "ranged", "growth": 3, "cost": case["cost"],
            "content_status": "marchland_local_retinue_live", "content_batch_id": SLICE_ID,
            "abilities": case["abilities"], "spell_resistance_pct": 5, "control_resistance_pct": 5,
            "spell_school_resistance_pct": {case["school"]: 10}, "status_immunity_ids": [],
        }
        if unit["ranged"]:
            unit["shots"] = 7
        upsert(units["items"], unit)

        building = {
            "id": case["building_id"], "name": case["building_name"], "category": "dwelling",
            "description": case["building_description"], "cost": case["building_cost"],
            "content_status": "marchland_local_retinue_live", "content_batch_id": SLICE_ID,
            "faction_id": case["faction_id"], "requires": case["requires"], "unlock_unit_id": case["unit_id"],
            "growth_bonus": {case["unit_id"]: 3}, "recruitment_discount_percent": {case["unit_id"]: 4},
            "readiness_bonus": 2, "pressure_bonus": 1,
        }
        upsert(buildings["items"], building)
        authored_buildings.append(building)

        for town in towns["items"]:
            buildable = town.get("buildable_building_ids", [])
            town["buildable_building_ids"] = [value for value in buildable if value != case["building_id"]]
        town = town_by_id[case["town_id"]]
        town["buildable_building_ids"].append(case["building_id"])
        seat = town.setdefault("marchland_seat", {})
        seat["local_retinue_unit_id"] = case["unit_id"]
        seat["local_retinue_building_id"] = case["building_id"]

        group = group_by_id[case["army_id"]]
        group["stacks"] = [stack for stack in group["stacks"] if stack.get("unit_id") != case["unit_id"]]
        group["stacks"].append({"unit_id": case["unit_id"], "count": 4})
        group["content_batch_id"] = "content-six-marchland-seats-10184"
        group["local_retinue_batch_id"] = SLICE_ID

        scenario = scenario_by_id[case["scenario_id"]]
        scenario["selection"]["player_summary"] = scenario["selection"]["player_summary"].replace("four-stack", "five-stack")
        scenario["marchland_local_retinue"] = {"unit_id": case["unit_id"], "building_id": case["building_id"]}

    (CONTENT / "units.json").write_text(json.dumps(units, separators=(",", ":")) + "\n", encoding="utf-8")
    append_pretty_items(CONTENT / "buildings.json", authored_buildings)
    (CONTENT / "towns.json").write_text(json.dumps(towns, indent=2) + "\n", encoding="utf-8")
    (CONTENT / "army_groups.json").write_text(dump_groups(groups), encoding="utf-8")
    (CONTENT / "scenarios.json").write_text(json.dumps(scenarios, separators=(",", ":")) + "\n", encoding="utf-8")

    unit_manifest = {"schema_id": "generated_unit_source_provenance_v1", "generator_mode": "built_in_imagegen", "generated_at": "2026-08-31T20:19:00Z", "curation": "Each transparent master was visually reviewed before deterministic 512x512 curation.", "items": []}
    building_manifest = {"schema_id": "generated_building_source_provenance_v1", "generator_mode": "built_in_imagegen", "generated_at": "2026-08-31T20:19:00Z", "curation": "Each transparent isometric master was visually reviewed before deterministic 1254x1254 curation.", "items": []}
    for case in CASES:
        unit_source = UNIT_SOURCE_ROOT / f"{case['unit_id']}_source.png"
        unit_curated = UNIT_CURATED_ROOT / f"{case['unit_id']}.png"
        unit_manifest["items"].append({"unit_id": case["unit_id"], "source_path": f"res://{unit_source.relative_to(ROOT)}", "source_sha256": sha256(unit_source), "curated_path": f"res://{unit_curated.relative_to(ROOT)}", "curated_sha256": sha256(unit_curated), "original_generated_path": str(GENERATOR_ROOT / case["unit_generated"]), "prompt": case["unit_prompt"]})
        building_source = BUILDING_SOURCE_ROOT / f"{case['building_id']}_source.png"
        building_curated = BUILDING_CURATED_ROOT / f"{case['building_id']}.png"
        building_manifest["items"].append({"building_id": case["building_id"], "source_path": f"res://{building_source.relative_to(ROOT)}", "source_sha256": sha256(building_source), "curated_path": f"res://{building_curated.relative_to(ROOT)}", "curated_sha256": sha256(building_curated), "original_generated_path": str(GENERATOR_ROOT / case["building_generated"]), "prompt": case["building_prompt"]})
    (UNIT_SOURCE_ROOT / "manifest.json").write_text(json.dumps(unit_manifest, indent=2) + "\n", encoding="utf-8")
    (BUILDING_SOURCE_ROOT / "manifest.json").write_text(json.dumps(building_manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Authored {len(CASES)} Marchland retinues and {len(CASES)} exclusive dwellings.")


if __name__ == "__main__":
    main()
