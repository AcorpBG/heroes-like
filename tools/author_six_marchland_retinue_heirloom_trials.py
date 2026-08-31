#!/usr/bin/env python3
"""Author six Marchland retinue heirloom trials and their runtime art."""

from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path

from PIL import Image, ImageOps


ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / "content"
SOURCE_ROOT = ROOT / "art" / "artifacts" / "source" / "generated" / "marchland_retinue_heirlooms"
RUNTIME_ROOT = ROOT / "art" / "artifacts" / "runtime"
FIELD_ROOT = ROOT / "art" / "overworld" / "runtime" / "objects" / "artifacts" / "marchland_retinue_heirlooms"
FIELD_ATLAS = FIELD_ROOT / "marchland_retinue_heirlooms_atlas.png"
OVERWORLD_MANIFEST = ROOT / "art" / "overworld" / "manifest.json"
SLICE_ID = "content-six-marchland-retinue-heirloom-trials-10184"
SOURCE_TABLE_ID = "artifact_source_marchland_retinue_heirlooms"
GENERATOR_ROOT = Path("/root/.codex/generated_images/019fe72a-30b1-76f3-b911-385c4444bd16")


CASES = [
    {
        "prefix": "amberweirtrial", "scenario_id": "rainledger-amberweir-lockpike-trial", "scenario_name": "Rainledger Amberweir Lockpike Trial",
        "town_id": "town_amberweir_granary", "town_name": "Amberweir Granary", "hero_id": "hero_embercourt_belis_rainledger", "faction_id": "faction_embercourt",
        "enemy_faction_id": "faction_mireclaw", "enemy_town_id": "town_blackfen_gate", "rare_id": "embergrain", "rare_site_id": "site_embergrain_warm_granary",
        "unit_id": "unit_embercourt_amberweir_lockpike_wardens", "unit_name": "Lockpike Wardens", "building_id": "building_embercourt_amberweir_sluiceguard_lock",
        "artifact_id": "artifact_amberweir_lockpike_tallychain", "artifact_name": "Amberweir Lockpike Tallychain", "accord": "beacon",
        "source_name": "amberweir_lockpike_tallychain_source.png", "generation_original": "exec-7af734eb-fbc1-41d9-863d-9a55645548e3.png",
        "terrain": ("grass", "dirt"), "seed": 48100,
        "encounters": ["encounter_briarmarshal_drum_cordon", "encounter_mudkeel_fenbell_commission", "encounter_reedscript_fenhound_lexicon"],
        "conventional": [("unit_embercourt_fordhook_cadets", 14), ("unit_embercourt_bargebow_crews", 8), ("unit_embercourt_ash_oath_bailiffs", 4), ("unit_embercourt_sluicefire_lindworms", 1)],
        "bonuses": {"battle_defense": 1, "overworld_movement": 1}, "roles": ["defense", "movement"],
        "summary": "A lockpike tallychain that braces the field line and keeps Amberweir companies moving between measured sluice marks.",
        "description": "A rain-dark tally chain closes around a forked lockpike head, a sluice key, and three amber counting seals worn smooth by working river hands.",
        "prompt_subject": "One heavy brass tally chain forming an open angular loop around a short blackened lockpike head, with a small sluice-gate key, three amber ceramic counting seals, and a rain-dark iron clasp.",
        "non_color_identity": "A broad chain loop is crossed by one vertical spear point and one offset long key, with three round seals hanging below.",
    },
    {
        "prefix": "moonbitetrial", "scenario_id": "votivejaw-moonbite-drum-trial", "scenario_name": "Votivejaw Moonbite Drum Trial",
        "town_id": "town_moonbite_reedshrine", "town_name": "Moonbite Reedshrine", "hero_id": "hero_mireclaw_nix_votivejaw", "faction_id": "faction_mireclaw",
        "enemy_faction_id": "faction_sunvault", "enemy_town_id": "town_prismhearth", "rare_id": "peatwax", "rare_site_id": "site_peatwax_reed_yard",
        "unit_id": "unit_mireclaw_moonbite_votive_drummers", "unit_name": "Votive Drummers", "building_id": "building_mireclaw_moonbite_votive_drum_court",
        "artifact_id": "artifact_moonbite_votive_drumkey", "artifact_name": "Moonbite Votive Drum-Key", "accord": "mire",
        "source_name": "moonbite_votive_drumkey_source.png", "generation_original": "exec-2a862e52-17f2-4b91-8d3c-d349d040db2c.png",
        "terrain": ("mire", "swamp"), "seed": 48200,
        "encounters": ["encounter_daynote_refraction_bench", "encounter_glassmarshal_counterseal_battery", "encounter_halometer_daylight_crown"],
        "conventional": [("unit_mireclaw_reedsnare_kin", 14), ("unit_mireclaw_mudglass_slingers", 8), ("unit_mireclaw_bogplate_maulers", 4), ("unit_mireclaw_ferrychain_lashers", 2)],
        "bonuses": {"battle_attack": 1, "battle_initiative": 1}, "roles": ["combat", "morale"],
        "summary": "A crescent drum-key that sharpens Moonbite's opening cadence and drives the answering strike.",
        "description": "An off-center antler drum hangs across a long bone tuning key, bound with reed tassels, peatwax beads, and one hooked field mallet.",
        "prompt_subject": "One small crescent-shaped wet-hide hand drum with an off-center antler rim, a long bone tuning key crossing behind it, three uneven reed tassels, peatwax beads, and a single hooked drumstick.",
        "non_color_identity": "A broad crescent drum is crossed by one long diagonal bone key and ends in three unequal hanging tassels.",
    },
    {
        "prefix": "splitprismtrial", "scenario_id": "facetlane-splitprism-parallax-trial", "scenario_name": "Facetlane Splitprism Parallax Trial",
        "town_id": "town_splitprism_duelcourt", "town_name": "Splitprism Duelcourt", "hero_id": "hero_sunvault_renn_facetlane", "faction_id": "faction_sunvault",
        "enemy_faction_id": "faction_thornwake", "enemy_town_id": "town_briarwheel_enclave", "rare_id": "aetherglass", "rare_site_id": "site_aetherglass_lens_house",
        "unit_id": "unit_sunvault_splitprism_parallax_fencers", "unit_name": "Parallax Fencers", "building_id": "building_sunvault_splitprism_parallax_duel_hall",
        "artifact_id": "artifact_splitprism_parallax_duelglass", "artifact_name": "Splitprism Parallax Duelglass", "accord": "lens",
        "source_name": "splitprism_parallax_duelglass_source.png", "generation_original": "exec-ed8dd3aa-079d-4d87-93a3-a03011ede197.png",
        "terrain": ("sand", "rough"), "seed": 48300,
        "encounters": ["encounter_briarwheel_witness_watch", "encounter_graftsibyl_wake_cordon", "encounter_loamchant_crystal_sump_binding"],
        "conventional": [("unit_sunvault_shard_wardens", 14), ("unit_sunvault_prism_adepts", 8), ("unit_sunvault_mirror_duelists", 4), ("unit_sunvault_solar_array_striders", 2)],
        "bonuses": {"battle_initiative": 1, "battle_spell_resistance_pct": 8}, "roles": ["combat", "resistance"],
        "summary": "An offset duelglass that fixes Splitprism's first command angle and divides hostile magic across two measured facets.",
        "description": "Two overlapping prism panes turn on a broken brass oval while a single calibration needle passes through both impossible sightlines.",
        "prompt_subject": "One asymmetrical hand-sized duel lens built from two offset faceted glass panes in a broken oval brass frame, with a narrow ivory grip, a hinged mirror vane, and one fine calibration needle passing through both panes.",
        "non_color_identity": "Two overlapping tilted diamond panes rise above a short handle, with one narrow side vane and one crossing needle.",
    },
    {
        "prefix": "woundroottrial", "scenario_id": "greenbarrow-woundroot-hearthseed-trial", "scenario_name": "Greenbarrow Woundroot Hearthseed Trial",
        "town_id": "town_woundroot_hearthgrove", "town_name": "Woundroot Hearthgrove", "hero_id": "hero_thornwake_merek_greenbarrow", "faction_id": "faction_thornwake",
        "enemy_faction_id": "faction_brasshollow", "enemy_town_id": "town_cindercoil_foundry", "rare_id": "verdant_grafts", "rare_site_id": "site_verdant_graft_nursery",
        "unit_id": "unit_thornwake_woundroot_hearthseed_slingers", "unit_name": "Hearthseed Slingers", "building_id": "building_thornwake_woundroot_hearthseed_nursery",
        "artifact_id": "artifact_woundroot_hearthseed_slingknot", "artifact_name": "Woundroot Hearthseed Slingknot", "accord": "root",
        "source_name": "woundroot_hearthseed_slingknot_source.png", "generation_original": "exec-42acf4f6-c1c1-4cf1-9052-3b50c39bd744.png",
        "terrain": ("forest", "grass"), "seed": 48400,
        "encounters": ["encounter_gaugesavant_switchback_proof", "encounter_tallyspring_proving_rack", "encounter_ironclause_ninefold_assize"],
        "conventional": [("unit_thornwake_seedcutters", 22), ("unit_thornwake_bramblekite_needlers", 12), ("unit_thornwake_seedshield_wardens", 7), ("unit_thornwake_sporeglass_menders", 4)],
        "bonuses": {"battle_defense": 1, "scouting_radius": 1}, "roles": ["defense", "scouting"],
        "summary": "A living slingknot that shelters Woundroot's line and reads the root roads ahead.",
        "description": "A triangular cradle of braided living root holds three hearth-warm seed stones, one long sling tail, and a leaf counterweight split by amber growth seams.",
        "prompt_subject": "One thick braided living-root knot forming a low triangular sling cradle, holding three warm seed-stones, with one long bark-fiber sling tail, a small leaf-shaped counterweight, and tiny sprouting heartgrain seams.",
        "non_color_identity": "A triangular braided cradle holds three round stones and trails into one long curved cord with a leaf-shaped weight.",
    },
    {
        "prefix": "whitegaugetrial", "scenario_id": "gaugesavant-whitegauge-datum-trial", "scenario_name": "Gauge-Savant Whitegauge Datum Trial",
        "town_id": "town_whitegauge_calibration_yard", "town_name": "Whitegauge Calibration Yard", "hero_id": "hero_brasshollow_lina_gaugesavant", "faction_id": "faction_brasshollow",
        "enemy_faction_id": "faction_veilmourn", "enemy_town_id": "town_gloamwake_anchorage", "rare_id": "brass_scrip", "rare_site_id": "site_brass_scrip_mint",
        "unit_id": "unit_brasshollow_whitegauge_datum_lancers", "unit_name": "Datum Lancers", "building_id": "building_brasshollow_whitegauge_datum_railhouse",
        "artifact_id": "artifact_whitegauge_datum_spur", "artifact_name": "Whitegauge Datum Spur", "accord": "furnace",
        "source_name": "whitegauge_datum_spur_source.png", "generation_original": "exec-e04bc864-4710-4ca1-88d3-387259bbac44.png",
        "terrain": ("rough", "dirt"), "seed": 48500,
        "encounters": ["encounter_keelwarden_dustjack_screen", "encounter_mistcorsair_foghook_boarding", "encounter_pale_sounding_memory_watch"],
        "conventional": [("unit_brasshollow_scrip_haulers", 15), ("unit_brasshollow_quenchspool_slingers", 8), ("unit_brasshollow_gaugefire_arbalists", 4), ("unit_brasshollow_boiler_rivetcasters", 2)],
        "bonuses": {"battle_attack": 1, "overworld_movement": 1}, "roles": ["combat", "movement"],
        "summary": "A calibrated datum spur that converts Whitegauge's measured stride into field pressure.",
        "description": "A white-ceramic spur carries a square notched rowel, a red pressure dial, two unequal measuring pins, and a black leather calibration strap.",
        "prompt_subject": "One oversized white-ceramic riding spur shaped around a broad brass calibration arc, with a square notched rowel, a small red pressure dial, two offset measuring pins, and a black leather buckle strap.",
        "non_color_identity": "A wide U-shaped spur carries one square wheel, one round gauge, two unequal pointed pins, and a broad buckle strap.",
    },
    {
        "prefix": "dreamwaketrial", "scenario_id": "wakeoracle-dreamwake-tideglass-trial", "scenario_name": "Wakeoracle Dreamwake Tideglass Trial",
        "town_id": "town_dreamwake_oracle_harbor", "town_name": "Dreamwake Oracle Harbor", "hero_id": "hero_veilmourn_morwen_wakeoracle", "faction_id": "faction_veilmourn",
        "enemy_faction_id": "faction_embercourt", "enemy_town_id": "town_cinderlock_bastion", "rare_id": "memory_salt", "rare_site_id": "site_memory_salt_pan",
        "unit_id": "unit_veilmourn_dreamwake_tideglass_oracles", "unit_name": "Tideglass Oracles", "building_id": "building_veilmourn_dreamwake_tideglass_oratory",
        "artifact_id": "artifact_dreamwake_tideglass_sounding", "artifact_name": "Dreamwake Tideglass Sounding", "accord": "veil",
        "source_name": "dreamwake_tideglass_sounding_source.png", "generation_original": "exec-186536c1-6c92-42a4-80e1-5a9cb8d4d705.png",
        "terrain": ("snow", "mire"), "seed": 48600,
        "encounters": ["encounter_beaconscribe_frostwharf_writ", "encounter_lockmaster_archive_seal", "encounter_railhead_lockward_auditors"],
        "conventional": [("unit_veilmourn_bellwake_oars", 14), ("unit_veilmourn_mourning_lanterns", 8), ("unit_veilmourn_maskglass_corsairs", 4), ("unit_veilmourn_undertow_harpooners", 2)],
        "bonuses": {"battle_initiative": 1, "scouting_radius": 1}, "roles": ["magic", "scouting"],
        "summary": "A tideglass sounding that reads hidden routes and fixes Dreamwake's first safe command beat.",
        "description": "A crescent whalebone frame holds one pale tideglass drop beside a cracked bell, three depth cords, a wave fork, and a narrow sounding hook.",
        "prompt_subject": "One crescent whalebone sounding frame holding a suspended teardrop of pale tideglass, with an offset cracked hand bell, three knotted depth cords, a small wave-shaped tuning fork, and one long hook below.",
        "non_color_identity": "A tall crescent frame holds one large hanging droplet, one offset bell, a forked side cord, and a narrow lower hook.",
    },
]


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load(name: str) -> dict:
    return json.loads((CONTENT / name).read_text(encoding="utf-8"))


def upsert(items: list[dict], row: dict) -> None:
    for index, current in enumerate(items):
        if current.get("id") == row["id"]:
            items[index] = row
            return
    items.append(row)


def dump_groups(payload: dict) -> str:
    text = json.dumps(payload, indent=2)
    return re.sub(r'\{\n\s+"unit_id": ("[^"]+"),\n\s+"count": ([0-9]+)\n\s+\}', r'{"unit_id": \1, "count": \2}', text) + "\n"


def append_source_table(path: Path, table: dict) -> None:
    text = path.read_text(encoding="utf-8")
    if f'"id": "{table["id"]}"' in text:
        return
    marker = '\n  ],\n  "items": [\n'
    index = text.rfind(marker)
    if index < 0:
        raise RuntimeError(f"Unexpected source table layout: {path}")
    block = json.dumps(table, indent=2)
    rendered = "\n".join(f"    {line}" for line in block.splitlines())
    text = text[:index] + ",\n" + rendered + text[index:]
    path.write_text(text, encoding="utf-8")


def append_pretty_items(path: Path, rows: list[dict]) -> None:
    text = path.read_text(encoding="utf-8")
    missing = [row for row in rows if f'"id": "{row["id"]}"' not in text]
    if not missing:
        return
    marker = "\n  ]\n}\n"
    if marker not in text:
        raise RuntimeError(f"Unexpected item layout: {path}")
    rendered = []
    for row in missing:
        block = json.dumps(row, indent=2)
        rendered.append("\n".join(f"    {line}" for line in block.splitlines()))
    path.write_text(text.replace(marker, ",\n" + ",\n".join(rendered) + marker, 1), encoding="utf-8")


def transparent_contain(source: Path, size: tuple[int, int], inset: int) -> Image.Image:
    with Image.open(source) as opened:
        image = opened.convert("RGBA")
    alpha = image.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        raise RuntimeError(f"Source has no visible alpha: {source}")
    cropped = image.crop(bbox)
    fitted = ImageOps.contain(cropped, (size[0] - inset * 2, size[1] - inset * 2), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    canvas.alpha_composite(fitted, ((size[0] - fitted.width) // 2, (size[1] - fitted.height) // 2))
    return canvas


def render_art() -> tuple[dict, list[Image.Image]]:
    RUNTIME_ROOT.mkdir(parents=True, exist_ok=True)
    FIELD_ROOT.mkdir(parents=True, exist_ok=True)
    frames: list[Image.Image] = []
    manifest = {
        "schema_id": "marchland_retinue_heirloom_art_v1",
        "content_batch_id": SLICE_ID,
        "generator_mode": "built_in_imagegen",
        "prompt_set_summary": "Six original transparent Marchland retinue heirlooms with silhouette-first inventory and field identities; no text, logos, characters, scenery, copied franchise art, or source-master package inclusion.",
        "runtime_icon_size": [128, 128],
        "field_atlas_path": "res://art/overworld/runtime/objects/artifacts/marchland_retinue_heirlooms/marchland_retinue_heirlooms_atlas.png",
        "field_atlas_size": [288, 48],
        "items": [],
    }
    for index, case in enumerate(CASES):
        source = SOURCE_ROOT / case["source_name"]
        runtime = RUNTIME_ROOT / f"{case['artifact_id'].removeprefix('artifact_')}.png"
        icon = transparent_contain(source, (128, 128), 8)
        icon.save(runtime, optimize=True, compress_level=9)
        frame = transparent_contain(source, (48, 48), 3)
        frames.append(frame)
        prompt = (
            "Use case: stylized-concept; Asset type: production fantasy strategy-game artifact inventory icon and overworld pickup source; "
            f"Primary request: Create the original {case['artifact_name']}; Subject: {case['prompt_subject']} "
            "Style: polished painterly 2D fantasy game object art in original Aurelion Reach visual language; "
            "Composition: one centered high-three-quarter object with generous transparent padding and a silhouette readable at 48x48; "
            "Constraints: genuinely transparent background, preserved alpha, object only, no floor, scenery, characters, hands, border, frame, text, letters, numbers, logo, watermark, cast shadow, or copied franchise design."
        )
        manifest["items"].append({
            "artifact_id": case["artifact_id"],
            "source_path": f"res://{source.relative_to(ROOT)}", "source_sha256": sha256(source),
            "runtime_path": f"res://{runtime.relative_to(ROOT)}", "runtime_sha256": sha256(runtime),
            "field_region": [index * 48, 0, 48, 48],
            "generation_original": str(GENERATOR_ROOT / case["generation_original"]),
            "prompt": prompt, "accessible_description": case["non_color_identity"],
        })
    atlas = Image.new("RGBA", (288, 48), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        atlas.alpha_composite(frame, (index * 48, 0))
    atlas.save(FIELD_ATLAS, optimize=True, compress_level=9)
    manifest["field_atlas_sha256"] = sha256(FIELD_ATLAS)
    (SOURCE_ROOT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return manifest, frames


def artifact_record(case: dict) -> dict:
    bonus_metadata = []
    value_driver_by_bonus = {
        "battle_attack": "battle_pressure",
        "battle_defense": "frontline_survival",
        "battle_initiative": "initiative_tempo",
        "battle_spell_resistance_pct": "spell_resistance",
        "overworld_movement": "route_tempo",
        "scouting_radius": "fog_route_scouting",
    }
    summaries = {
        "battle_attack": "Raises the equipped commander's battle pressure.",
        "battle_defense": "Hardens the equipped commander's formation.",
        "battle_initiative": "Advances the equipped commander's opening beat.",
        "battle_spell_resistance_pct": "Divides hostile spell pressure across the heirloom's warding surface.",
        "overworld_movement": "Keeps the equipped commander's road column moving.",
        "scouting_radius": "Reveals one additional ring of nearby terrain.",
    }
    for stat in case["bonuses"]:
        bonus_metadata.append({"bonus_type": "stat", "scope": "equipped", "stat": stat, "public_summary": summaries[stat]})
    preferred_roles = ["defender", "scout"] if "battle_defense" in case["bonuses"] else ["might", "raider"]
    return {
        "id": case["artifact_id"], "name": case["artifact_name"], "slot": "trinket", "artifact_class": "faction", "rarity": "rare",
        "family": "marchland_retinue_heirlooms", "roles": case["roles"], "accord_affinity": case["accord"],
        "faction_affinity": [case["faction_id"]], "source_tags": ["pickup"],
        "equip_constraints": {"slot_limit": 2, "unique_per_hero": True, "allowed_faction_ids": [], "required_tags": []},
        "bonus_metadata": bonus_metadata,
        "risk": {"cursed": False, "tradeoff": False, "warning_tags": []},
        "ui": {
            "summary": case["summary"],
            "icon_id": f"artifact_icon_{case['artifact_id'].removeprefix('artifact_')}",
            "icon_path": f"res://art/artifacts/runtime/{case['artifact_id'].removeprefix('artifact_')}.png",
            "effect_tags": list(case["bonuses"].keys()) + [case["faction_id"].removeprefix("faction_")],
            "comparison_priority": list(case["bonuses"].keys()) + ["faction_affinity"],
        },
        "ai_hints": {
            "value_drivers": [value_driver_by_bonus[bonus] for bonus in case["bonuses"]], "preferred_hero_roles": preferred_roles,
            "preferred_faction_ids": [case["faction_id"]], "combo_tags": [case["accord"], case["prefix"], "retinue"],
        },
        "validation_tags": {"schema": "artifact_taxonomy_v1", "save_behavior": "content_reference_only", "set_id": "", "mutual_exclusions": [], "stack_rule": "unique_per_hero"},
        "description": case["description"], "bonuses": case["bonuses"],
        "content_status": "marchland_retinue_heirloom_live", "content_batch_id": SLICE_ID,
    }


def terrain_map(primary: str, secondary: str, seed: int) -> list[list[str]]:
    return [[secondary if ((x * 7 + y * 11 + seed) % 13) in (0, 1) else primary for x in range(13)] for y in range(8)]


def scenario_record(case: dict, building: dict) -> dict:
    prefix = case["prefix"]
    prerequisite_ids = list(building.get("requires", []))
    encounters = []
    for index, (encounter_id, coords) in enumerate(zip(case["encounters"], [(4, 1), (5, 5), (9, 2)]), start=1):
        encounters.append({
            "placement_id": f"{prefix}_front_{index}", "encounter_id": encounter_id,
            "x": coords[0], "y": coords[1], "difficulty": "medium" if index < 3 else "high",
            "combat_seed": case["seed"] + index, "prefer_identity_landmark": True,
        })
    victories = [
        {"id": f"{prefix}_build_dwelling", "label": f"Build {building['name']}", "type": "building_built_in_player_town", "placement_id": f"{prefix}_home", "building_id": case["building_id"]},
        {"id": f"{prefix}_reinforce_retinue", "label": f"Field at least five {case['unit_name']}", "type": "hero_army_meets_requirements", "hero_id": case["hero_id"], "requirements": [{"unit_id": case["unit_id"], "minimum_count": 5}]},
        {"id": f"{prefix}_recover_heirloom", "label": f"Recover {case['artifact_name']}", "type": "artifact_owned_by_player", "artifact_id": case["artifact_id"]},
    ]
    victories.extend({"id": f"{prefix}_clear_front_{index}", "label": f"Break retinue trial front {index}", "type": "encounter_resolved", "placement_id": f"{prefix}_front_{index}"} for index in range(1, 4))
    resources = [
        {"placement_id": f"{prefix}_wood_1", "site_id": "site_wood_wagon", "x": 1, "y": 0},
        {"placement_id": f"{prefix}_ore_1", "site_id": "site_ore_crates", "x": 3, "y": 0},
        {"placement_id": f"{prefix}_rare_1", "site_id": case["rare_site_id"], "x": 6, "y": 0},
        {"placement_id": f"{prefix}_exchange", "site_id": "site_frontier_rare_exchange", "x": 10, "y": 0},
        {"placement_id": f"{prefix}_wood_2", "site_id": "site_wood_wagon", "x": 2, "y": 7},
        {"placement_id": f"{prefix}_ore_2", "site_id": "site_ore_crates", "x": 6, "y": 7},
        {"placement_id": f"{prefix}_rare_2", "site_id": case["rare_site_id"], "x": 9, "y": 7},
        {"placement_id": f"{prefix}_sanctum", "site_id": "site_roadside_sanctum", "x": 11, "y": 7},
    ]
    return {
        "id": case["scenario_id"], "name": case["scenario_name"],
        "selection": {
            "summary": f"Reopen {case['town_name']}'s retinue road, build its local dwelling, reinforce the exact company, and recover the heirloom behind three hostile fronts.",
            "recommended_difficulty": "normal", "map_size_label": "Retinue Trial (13x8)",
            "player_summary": f"The Marchland commander begins with four conventional stacks and two {case['unit_name']}, then must grow the local company through normal town authority.",
            "enemy_summary": "Three authored fronts, an enemy town, and rising pressure contest the local dwelling and heirloom route.",
            "availability": {"campaign": False, "skirmish": True},
        },
        "map_size": {"width": 13, "height": 8}, "player_faction_id": case["faction_id"],
        "player_army_id": f"army_{prefix}_retinue_company", "hero_id": case["hero_id"],
        "starting_resources": {"gold": 5000, "wood": 8, "ore": 8, case["rare_id"]: 2},
        "map": terrain_map(*case["terrain"], case["seed"]), "start": {"x": 1, "y": 3}, "hero_starts": [case["hero_id"]],
        "objectives": {
            "victory_text": f"{case['town_name']} has restored its local retinue and recovered {case['artifact_name']}.",
            "defeat_text": "The home seat falls, hostile pressure closes the trial road, or Day 16 ends the commission.",
            "victory": victories,
            "defeat": [
                {"id": f"{prefix}_lose_home", "label": f"Keep {case['town_name']} under player control", "type": "town_not_owned_by_player", "placement_id": f"{prefix}_home"},
                {"id": f"{prefix}_pressure", "label": "Keep hostile pressure below 22", "type": "enemy_pressure_at_least", "faction_id": case["enemy_faction_id"], "threshold": 22},
                {"id": f"{prefix}_deadline", "label": "Complete the retinue trial before Day 16", "type": "day_at_least", "day": 16},
            ],
        },
        "script_hooks": [
            {"id": f"{prefix}_day_two_relief", "priority": 130, "conditions": [{"type": "day_at_least", "day": 2}, {"type": "town_owned_by_player", "placement_id": f"{prefix}_home"}], "effects": [{"type": "add_resources", "resources": {"gold": 350, "wood": 1, "ore": 1}}, {"type": "message", "text": f"{case['town_name']} sends tools and pay chests onto the retinue road."}]},
            {"id": f"{prefix}_front_one_recruits", "priority": 120, "conditions": [{"type": "encounter_resolved", "placement_id": f"{prefix}_front_1"}], "effects": [{"type": "town_add_recruits", "placement_id": f"{prefix}_home", "recruits": {case["unit_id"]: 3}}, {"type": "message", "text": f"Freed local veterans add three {case['unit_name']} to the town muster."}]},
            {"id": f"{prefix}_heirloom_recovery", "priority": 110, "conditions": [{"type": "objective_met", "objective_id": f"{prefix}_recover_heirloom"}], "effects": [{"type": "award_experience", "amount": 150}, {"type": "add_resources", "resources": {case["rare_id"]: 1}}, {"type": "message", "text": f"{case['artifact_name']} returns to its local company."}]},
            {"id": f"{prefix}_day_eight_pressure", "priority": 80, "conditions": [{"type": "day_at_least", "day": 8}, {"type": "objective_not_met", "objective_id": f"{prefix}_recover_heirloom"}], "effects": [{"type": "add_enemy_pressure", "faction_id": case["enemy_faction_id"], "amount": 3}, {"type": "message", "text": "The unrecovered heirloom draws another hostile claim onto the trial road."}]},
            {"id": f"{prefix}_day_ten_counterstroke", "priority": 70, "conditions": [{"type": "day_at_least", "day": 10}, {"type": "town_owned_by_player", "placement_id": f"{prefix}_home"}, {"type": "objective_not_met", "objective_id": f"{prefix}_recover_heirloom"}], "effects": [{"type": "spawn_encounter", "placement": {"placement_id": f"{prefix}_counterstroke", "encounter_id": case["encounters"][1], "x": 11, "y": 6, "difficulty": "scripted", "spawned_by_faction_id": case["enemy_faction_id"], "days_active": 0, "arrived": False, "goal_distance": 9999}}, {"type": "message", "text": "A late claimant column crosses the outer road before the heirloom can be secured."}]},
        ],
        "towns": [
            {"placement_id": f"{prefix}_home", "town_id": case["town_id"], "x": 0, "y": 3, "owner": "player", "built_buildings": ["building_market_square"] + prerequisite_ids},
            {"placement_id": f"{prefix}_enemy_town", "town_id": case["enemy_town_id"], "x": 12, "y": 3, "owner": "enemy"},
        ],
        "enemy_factions": [{
            "faction_id": case["enemy_faction_id"], "label": "Heirloom Claimants", "pressure_per_day": 1, "pressure_per_enemy_town": 1,
            "raid_threshold": 8, "max_active_raids": 1, "raid_pillage_delay": 2, "raid_pillage": {"gold": 160},
            "raid_encounter_ids": case["encounters"][:2], "spawn_points": [{"x": 12, "y": 1}, {"x": 12, "y": 6}],
            "siege_target_placement_id": f"{prefix}_home", "priority_target_placement_ids": [f"{prefix}_home", f"{prefix}_heirloom", f"{prefix}_rare_1"],
        }],
        "resource_nodes": resources,
        "artifact_nodes": [{"placement_id": f"{prefix}_heirloom", "artifact_id": case["artifact_id"], "x": 10, "y": 5, "guard_front_id": f"{prefix}_front_3"}],
        "encounters": encounters,
        "content_status": "marchland_retinue_heirloom_trial_live", "content_batch_id": SLICE_ID,
        "scenario_family": "marchland_retinue_heirloom_trial", "deterministic_seed": case["seed"],
        "marchland_retinue_heirloom": {"town_id": case["town_id"], "unit_id": case["unit_id"], "building_id": case["building_id"], "artifact_id": case["artifact_id"]},
    }


def main() -> None:
    art_manifest, _frames = render_art()
    artifact_rows = [artifact_record(case) for case in CASES]
    source_table = {
        "id": SOURCE_TABLE_ID, "schema": "artifact_source_reward_v1", "source_tag": "pickup",
        "reward_context": "authored_scenario_placement", "eligible_object_families": ["pickup"],
        "eligible_site_families": ["one_shot_pickup"], "required_object_tags": ["small_reward"], "required_reward_categories": [],
        "guard_tiers": ["unguarded", "light"], "rarity_bands": ["rare"],
        "artifact_ids": [case["artifact_id"] for case in CASES],
        "artifact_ids_by_faction": {case["faction_id"]: [case["artifact_id"]] for case in CASES},
        "faction_constraints": [case["faction_id"] for case in CASES],
        "set_constraints": {"allowed_set_ids": [], "piece_limit_per_table": 0},
        "runtime_policy": {"metadata_only": True, "live_drop_execution": False, "save_version_bump": False, "equipment_runtime_effects": False, "ai_valuation_behavior": False, "rare_resource_activation": False},
    }
    artifact_path = CONTENT / "artifacts.json"
    append_source_table(artifact_path, source_table)
    append_pretty_items(artifact_path, artifact_rows)

    buildings = {row["id"]: row for row in load("buildings.json")["items"]}
    groups = load("army_groups.json")
    scenarios = load("scenarios.json")
    overworld = json.loads(OVERWORLD_MANIFEST.read_text(encoding="utf-8"))
    atlas_hash = art_manifest["field_atlas_sha256"]
    for index, case in enumerate(CASES):
        stacks = [{"unit_id": unit_id, "count": count} for unit_id, count in case["conventional"]]
        stacks.append({"unit_id": case["unit_id"], "count": 2})
        upsert(groups["items"], {
            "id": f"army_{case['prefix']}_retinue_company", "name": f"{case['town_name']} Heirloom Company",
            "faction_id": case["faction_id"], "stacks": stacks,
            "content_status": "marchland_retinue_heirloom_company_live", "content_batch_id": SLICE_ID,
        })
        upsert(scenarios["items"], scenario_record(case, buildings[case["building_id"]]))
        asset_id = f"artifact_field_{case['artifact_id'].removeprefix('artifact_')}"
        overworld.setdefault("artifact_field_sprites", {})[case["artifact_id"]] = asset_id
        overworld.setdefault("object_assets", {})[asset_id] = {
            "path": "res://art/overworld/runtime/objects/artifacts/marchland_retinue_heirlooms/marchland_retinue_heirlooms_atlas.png",
            "atlas_region": [index * 48, 0, 48, 48], "atlas_size": [288, 48], "runtime_sha256": atlas_hash,
            "source_icon": f"res://art/artifacts/runtime/{case['artifact_id'].removeprefix('artifact_')}.png",
            "source_model": "built_in_imagegen_marchland_retinue_heirloom_compact_field_atlas",
            "asset_policy": "exact_original_artifact_identity_shared_into_distinct_field_surface",
            "assigned_artifact_id": case["artifact_id"], "assigned_faction_id": case["faction_id"],
            "presentation_role": "marchland_retinue_heirloom_field_pickup",
            "accessible_description": case["non_color_identity"], "background": "transparent",
        }
    scenarios["player_facing_active_scenario_count"] = len(scenarios["items"])
    (CONTENT / "army_groups.json").write_text(dump_groups(groups), encoding="utf-8")
    (CONTENT / "scenarios.json").write_text(json.dumps(scenarios, separators=(",", ":")) + "\n", encoding="utf-8")
    OVERWORLD_MANIFEST.write_text(json.dumps(overworld, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({
        "slice_id": SLICE_ID, "scenario_count": len(scenarios["items"]), "army_group_count": len(groups["items"]),
        "artifact_count": len(load("artifacts.json")["items"]), "new_scenario_ids": [case["scenario_id"] for case in CASES],
        "new_artifact_ids": [case["artifact_id"] for case in CASES], "direct_battle_count": 18,
    }, indent=2))


if __name__ == "__main__":
    main()
