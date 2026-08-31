#!/usr/bin/env python3
"""Author twelve cross-faction command relic marches and their runtime art."""

from __future__ import annotations

import json
from collections import defaultdict
from pathlib import Path

from PIL import Image

import author_six_marchland_retinue_heirloom_trials as base


ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / "content"
SOURCE_ROOT = ROOT / "art/artifacts/source/generated/command_relic_marches"
RUNTIME_ROOT = ROOT / "art/artifacts/runtime"
FIELD_ROOT = ROOT / "art/overworld/runtime/objects/artifacts/command_relic_marches"
FIELD_ATLAS = FIELD_ROOT / "command_relic_marches_atlas.png"
FIELD_ATLAS_RES = "res://art/overworld/runtime/objects/artifacts/command_relic_marches/command_relic_marches_atlas.png"
OVERWORLD_MANIFEST = ROOT / "art/overworld/manifest.json"
SLICE_ID = "content-twelve-command-relic-marches-10184"
SOURCE_TABLE_ID = "artifact_source_command_relic_marches"
GENERATOR_ROOT = Path("/root/.codex/generated_images/019fe72a-30b1-76f3-b911-385c4444bd16")


FACTION_ROUTES = {
    "faction_brasshollow": {
        "enemy_faction_id": "faction_veilmourn", "enemy_label": "Pale Signal Claimants",
        "rare_id": "brass_scrip", "rare_site_id": "site_brass_scrip_mint", "accord": "furnace",
        "terrain": ("rough", "dirt"),
        "encounters": ["encounter_keelwarden_dustjack_screen", "encounter_mistcorsair_foghook_boarding", "encounter_pale_sounding_memory_watch"],
        "stacks": [("unit_brasshollow_scrip_haulers", 18), ("unit_brasshollow_quenchspool_slingers", 10), ("unit_brasshollow_gaugefire_arbalists", 6), ("unit_brasshollow_boiler_rivetcasters", 3), ("unit_brasshollow_pressure_lancers", 2)],
    },
    "faction_embercourt": {
        "enemy_faction_id": "faction_mireclaw", "enemy_label": "Fen Charter Claimants",
        "rare_id": "embergrain", "rare_site_id": "site_embergrain_warm_granary", "accord": "beacon",
        "terrain": ("grass", "dirt"),
        "encounters": ["encounter_briarmarshal_drum_cordon", "encounter_mudkeel_fenbell_commission", "encounter_reedscript_fenhound_lexicon"],
        "stacks": [("unit_embercourt_fordhook_cadets", 18), ("unit_embercourt_lantern_sappers", 10), ("unit_embercourt_bargebow_crews", 6), ("unit_embercourt_ash_oath_bailiffs", 3), ("unit_embercourt_lockglass_writcasters", 2)],
    },
    "faction_mireclaw": {
        "enemy_faction_id": "faction_sunvault", "enemy_label": "Noon-Glass Claimants",
        "rare_id": "peatwax", "rare_site_id": "site_peatwax_reed_yard", "accord": "mire",
        "terrain": ("mire", "swamp"),
        "encounters": ["encounter_daynote_refraction_bench", "encounter_glassmarshal_counterseal_battery", "encounter_halometer_daylight_crown"],
        "stacks": [("unit_mireclaw_reedsnare_kin", 24), ("unit_mireclaw_mudglass_slingers", 14), ("unit_mireclaw_bogplate_maulers", 9), ("unit_mireclaw_ferrychain_lashers", 5), ("unit_mireclaw_mireglass_reedcasters", 4)],
    },
    "faction_sunvault": {
        "enemy_faction_id": "faction_thornwake", "enemy_label": "Root-Jury Claimants",
        "rare_id": "aetherglass", "rare_site_id": "site_aetherglass_lens_house", "accord": "lens",
        "terrain": ("sand", "rough"),
        "encounters": ["encounter_briarwheel_witness_watch", "encounter_graftsibyl_wake_cordon", "encounter_loamchant_crystal_sump_binding"],
        "stacks": [("unit_sunvault_shard_wardens", 18), ("unit_sunvault_prism_adepts", 10), ("unit_sunvault_mirror_duelists", 6), ("unit_sunvault_resonant_choristers", 3), ("unit_sunvault_noonfacet_sentinels", 2)],
    },
    "faction_thornwake": {
        "enemy_faction_id": "faction_brasshollow", "enemy_label": "Iron-Clause Claimants",
        "rare_id": "verdant_grafts", "rare_site_id": "site_verdant_graft_nursery", "accord": "root",
        "terrain": ("forest", "grass"),
        "encounters": ["encounter_gaugesavant_switchback_proof", "encounter_tallyspring_proving_rack", "encounter_ironclause_ninefold_assize"],
        "stacks": [("unit_thornwake_seedcutters", 18), ("unit_thornwake_bramblekite_needlers", 10), ("unit_thornwake_seedshield_wardens", 6), ("unit_thornwake_barkmantle_rams", 3), ("unit_thornwake_seedglass_cantors", 2)],
    },
    "faction_veilmourn": {
        "enemy_faction_id": "faction_embercourt", "enemy_label": "Beacon Writ Claimants",
        "rare_id": "memory_salt", "rare_site_id": "site_memory_salt_pan", "accord": "veil",
        "terrain": ("snow", "mire"),
        "encounters": ["encounter_beaconscribe_frostwharf_writ", "encounter_lockmaster_archive_seal", "encounter_railhead_lockward_auditors"],
        "stacks": [("unit_veilmourn_bellwake_oars", 18), ("unit_veilmourn_mourning_lanterns", 10), ("unit_veilmourn_maskglass_corsairs", 6), ("unit_veilmourn_undertow_harpooners", 3), ("unit_veilmourn_wakeglass_navigators", 2)],
    },
}


CASES = [
    {"prefix": "blackgauge", "hero_id": "hero_brasshollow_kestra_blackgauge", "faction_id": "faction_brasshollow", "town_id": "town_blackbell_foundry", "enemy_town_id": "town_veilmourn_fogchart_mooring", "scenario_id": "blackgauge-muster-bell-march", "scenario_name": "Blackgauge Muster-Bell March", "artifact_id": "artifact_blackgauge_muster_bell", "artifact_name": "Blackgauge Muster Bell", "source_name": "blackgauge_muster_bell_source.png", "generation_original": "exec-8a93510c-372e-49f1-83e3-226c8f32c1a1.png", "seed": 50100, "bonuses": {"battle_defense": 1, "battle_initiative": 1}, "roles": ["defense", "morale"], "summary": "A black assay bell that steadies reinforced levies and fixes their first measured beat.", "description": "A squat black-iron assay bell hangs beneath a long tally rod, three unequal chain tags, a square clapper, and a narrow gauge needle.", "prompt_subject": "one squat asymmetrical black-iron assay bell crossed by a long brass tally rod, with three unequal chain tags, a square clapper, and a narrow red gauge needle", "non_color_identity": "A broad bell is crossed by one long horizontal rod and carries three unequal hanging tags beside a square clapper."},
    {"prefix": "switchrail", "hero_id": "hero_brasshollow_kuld_varn", "faction_id": "faction_brasshollow", "town_id": "town_brasshollow_orevein_gantry", "enemy_town_id": "town_gloamwake_anchorage", "scenario_id": "varn-switchrail-compass-march", "scenario_name": "Varn Switchrail Compass March", "artifact_id": "artifact_varn_switchrail_compass", "artifact_name": "Varn Switchrail Compass", "source_name": "varn_switchrail_compass_source.png", "generation_original": "exec-9c651f5b-f2a2-4a9c-a441-e4be9461cf99.png", "seed": 50200, "bonuses": {"overworld_movement": 1, "scouting_radius": 1}, "roles": ["movement", "scouting"], "summary": "A rail compass that reads mine roads, broken switches, and the shortest safe line between holdings.", "description": "A triangular brass compass closes around a black switch lever, split rails, an offset toothed wheel, and one white direction bead.", "prompt_subject": "one triangular brass rail compass built around a short black switch lever, an offset toothed wheel, two split iron rails, and a single white ceramic direction bead", "non_color_identity": "Two split rails form a wide triangle around one lever, one toothed wheel, and a single round direction bead."},
    {"prefix": "valechant", "hero_id": "hero_seren", "faction_id": "faction_embercourt", "town_id": "town_rainwrit_bastion", "enemy_town_id": "town_blackfen_gate", "scenario_id": "valechant-star-cadence-march", "scenario_name": "Valechant Star-Cadence March", "artifact_id": "artifact_valechant_star_cadence_astrolabe", "artifact_name": "Valechant Star-Cadence Astrolabe", "source_name": "valechant_star_cadence_astrolabe_source.png", "generation_original": "exec-7ec09ea5-2d17-4867-85f6-d655e997bf13.png", "seed": 50300, "bonuses": {"battle_initiative": 1, "scouting_radius": 1}, "roles": ["magic", "scouting"], "summary": "A star-cadence instrument that joins archive routes to the opening rhythm of battle.", "description": "A pale crescent astrolabe holds a seven-point lens among three unequal tuning forks, one chain, and a dark archive bead.", "prompt_subject": "one open crescent astrolabe of pale silver and emberglass, with three unequal tuning forks around a seven-point star lens, a short chain, and one dark archive bead", "non_color_identity": "A large open crescent encloses a pointed star lens while three uneven forks and one long chain break its circular outline."},
    {"prefix": "millward", "hero_id": "hero_caelen", "faction_id": "faction_embercourt", "town_id": "town_riverwatch", "enemy_town_id": "town_duskfen", "scenario_id": "ashgrove-millward-march", "scenario_name": "Ashgrove Millward Lantern March", "artifact_id": "artifact_ashgrove_millward_lantern", "artifact_name": "Ashgrove Millward Lantern", "source_name": "ashgrove_millward_lantern_source.png", "generation_original": "exec-cb43e756-8543-44ca-81aa-a4f0d9448b49.png", "seed": 50400, "bonuses": {"battle_defense": 1, "overworld_movement": 1}, "roles": ["defense", "movement"], "summary": "A mill-country ward lantern that shelters the line without slowing the frontier column.", "description": "A shield-shaped river lantern burns behind a small millwheel, layered guard plates, and a short green carrying cord.", "prompt_subject": "one broad shield-shaped river lantern whose iron face is crossed by a small wooden millwheel, with a hooded amber flame, two layered guard plates, and a short green cord", "non_color_identity": "A tall shield lantern is crossed by one round millwheel and closes to a pointed base beneath a hooded flame."},
    {"prefix": "reedcaller", "hero_id": "hero_mireclaw_rhask_reedcaller", "faction_id": "faction_mireclaw", "town_id": "town_hollowreed_sanctuary", "enemy_town_id": "town_prismhearth", "scenario_id": "reedcaller-circle-horn-march", "scenario_name": "Reedcaller Circle-Horn March", "artifact_id": "artifact_reedcaller_circle_horn", "artifact_name": "Reedcaller Circle Horn", "source_name": "reedcaller_circle_horn_source.png", "generation_original": "exec-80403ae6-e708-49ac-8534-0a658c968e25.png", "seed": 50500, "bonuses": {"battle_attack": 1, "overworld_movement": 1}, "roles": ["combat", "movement"], "summary": "A coiled fen horn that gathers scattered reed circles into one hard-moving hunt.", "description": "A spiral marsh-reed horn is bound by three hide rings, a forked mouthpiece, two tally teeth, and a hooked carrying loop.", "prompt_subject": "one coiled marsh-reed muster horn forming an open spiral, bound by three broad hide rings, with a forked antler mouthpiece, two dangling tally teeth, and a hooked carrying loop", "non_color_identity": "A thick open spiral ends in a wide horn mouth and a forked handle, with two small teeth hanging from the inner coil."},
    {"prefix": "muckscribe", "hero_id": "hero_sable", "faction_id": "faction_mireclaw", "town_id": "town_nightglass_redoubt", "enemy_town_id": "town_halo_spire", "scenario_id": "muckscribe-fen-ink-march", "scenario_name": "Muckscribe Fen-Ink March", "artifact_id": "artifact_muckscribe_fen_ink_reliquary", "artifact_name": "Muckscribe Fen-Ink Reliquary", "source_name": "muckscribe_fen_ink_reliquary_source.png", "generation_original": "exec-5e42d107-5e68-43b6-94d0-0d5ba064f666.png", "seed": 50600, "bonuses": {"battle_spell_resistance_pct": 8, "scouting_radius": 1}, "roles": ["magic", "resistance"], "summary": "A caged fen-ink vessel that records hidden routes and blots hostile spell clauses.", "description": "A crooked black-glass flask sits in a ribbed bone cage beneath a hooked quill, peatwax stopper, and three seal chips.", "prompt_subject": "one crooked black-glass ink flask in a ribbed bone cage, crossed by a long hooked quill, with a peatwax stopper, three dangling seal chips, and a small spout shaped like a fen beak", "non_color_identity": "A bulbous caged flask is crossed by one enormous hooked quill and carries three small seals below its stopper."},
    {"prefix": "sevenfold", "hero_id": "hero_sunvault_aven_sevenfold", "faction_id": "faction_sunvault", "town_id": "town_meridian_choirhold", "enemy_town_id": "town_briarwheel_enclave", "scenario_id": "sevenfold-reserve-prism-march", "scenario_name": "Sevenfold Reserve-Prism March", "artifact_id": "artifact_sevenfold_reserve_prism", "artifact_name": "Sevenfold Reserve Prism", "source_name": "sevenfold_reserve_prism_source.png", "generation_original": "exec-ce7551a7-1c87-43e7-866d-d1a4b7e57bfc.png", "seed": 50700, "bonuses": {"battle_defense": 1, "battle_initiative": 1}, "roles": ["defense", "morale"], "summary": "A seven-plate reserve prism that locks shield cadence before the line is tested.", "description": "Seven unequal translucent shield plates fold around a brass boss, two hinges, a white grip, and one narrow light fin.", "prompt_subject": "one compact folding shield made from seven visibly unequal translucent prism plates around a brass central boss, with two offset hinges, a short white grip, and a narrow light-catching fin", "non_color_identity": "Seven unequal plates radiate from one round boss, creating a broken flower-like shield with two offset hinges."},
    {"prefix": "glasswind", "hero_id": "hero_neral", "faction_id": "faction_sunvault", "town_id": "town_dawnmirror_observatory", "enemy_town_id": "town_thornwake_rootgate_nursery", "scenario_id": "glasswind-sightline-march", "scenario_name": "Glasswind Sightline-Fan March", "artifact_id": "artifact_glasswind_sightline_fan", "artifact_name": "Glasswind Sightline Fan", "source_name": "glasswind_sightline_fan_source.png", "generation_original": "exec-537e114e-5fe6-4d60-829f-9d23ec8a3df3.png", "seed": 50800, "bonuses": {"battle_attack": 1, "scouting_radius": 1}, "roles": ["combat", "scouting"], "summary": "A mirrored sightline fan that reads exposed wings and focuses reflected fire along them.", "description": "Five mirrored glass vanes spread from an ivory pivot beneath a long sighting needle, wind vane, and hanging glass bead.", "prompt_subject": "one half-open asymmetrical fan of five mirrored glass vanes, pierced by a long brass sighting needle, with a small arrow-shaped wind vane, an ivory pivot, and one hanging aetherglass bead", "non_color_identity": "Five broad fan vanes spread beneath one long piercing needle and a tiny arrow vane, with a single bead below."},
    {"prefix": "boltroot", "hero_id": "hero_thornwake_bryn_boltroot", "faction_id": "faction_thornwake", "town_id": "town_crownroot_refuge", "enemy_town_id": "town_cindercoil_foundry", "scenario_id": "boltroot-quiver-loom-march", "scenario_name": "Boltroot Quiver-Loom March", "artifact_id": "artifact_boltroot_quiver_loom", "artifact_name": "Boltroot Quiver Loom", "source_name": "boltroot_quiver_loom_source.png", "generation_original": "exec-a924dd6a-8322-48d5-988a-940e8d5a6be4.png", "seed": 50900, "bonuses": {"battle_attack": 1, "scouting_radius": 1}, "roles": ["combat", "scouting"], "summary": "A living quiver loom that grows measured bolt stores along every newly rooted firing line.", "description": "A tall rootwoven quiver carries three unequal bolts, a crosswise shuttle, two leaf weights, and a hooked shoulder strap.", "prompt_subject": "one tall rootwoven quiver shaped like a narrow loom, holding three oversized unequal bolts, with a crosswise shuttle, two leaf-shaped tension weights, and a hooked bark shoulder strap", "non_color_identity": "A tall woven case holds three unequal bolt heads and is crossed by one narrow shuttle beside a strongly curved strap."},
    {"prefix": "pollenglass", "hero_id": "hero_thornwake_osmund_pollenglass", "faction_id": "faction_thornwake", "town_id": "town_briarwheel_enclave", "enemy_town_id": "town_blackbell_foundry", "scenario_id": "pollenglass-spore-ampoule-march", "scenario_name": "Pollenglass Spore-Ampoule March", "artifact_id": "artifact_pollenglass_spore_ampoule", "artifact_name": "Pollenglass Spore Ampoule", "source_name": "pollenglass_spore_ampoule_source.png", "generation_original": "exec-380ce140-c1f9-4572-ac77-6d1bc9ba112f.png", "seed": 51000, "bonuses": {"battle_defense": 1, "battle_spell_resistance_pct": 8}, "roles": ["defense", "resistance"], "summary": "A measured spore ampoule that hardens living lines against wounds and hostile magic.", "description": "A tall faceted ampoule is clasped by living leaf jaws, a bent dose tube, three pollen chambers, and a rootwood stopper.", "prompt_subject": "one tall faceted glass ampoule filled with layered luminous spores, clasped by two living leaf jaws, with a bent copper dose tube, three round pollen chambers, and a rootwood stopper", "non_color_identity": "A long pointed ampoule is clasped by two leaf jaws and carries three round side chambers beneath a bent tube."},
    {"prefix": "oriflag", "hero_id": "hero_veilmourn_damar_oriflag", "faction_id": "faction_veilmourn", "town_id": "town_veilmourn_fogchart_mooring", "enemy_town_id": "town_riverwatch", "scenario_id": "oriflag-stolen-signal-march", "scenario_name": "Oriflag Stolen-Signal March", "artifact_id": "artifact_oriflag_stolen_signal_pennon", "artifact_name": "Oriflag Stolen Signal Pennon", "source_name": "oriflag_stolen_signal_pennon_source.png", "generation_original": "exec-f23a415d-091d-4a9f-809a-2d3e88411a14.png", "seed": 51100, "bonuses": {"overworld_movement": 1, "scouting_radius": 1}, "roles": ["movement", "scouting"], "summary": "A stolen signal pennon that opens fog lanes and misdirects the pursuit behind them.", "description": "A folded swallowtail pennon wraps a crooked signal pole beneath three mismatched discs, a hook clasp, and a mistglass tip.", "prompt_subject": "one tightly folded swallowtail pennon of dark sailcloth wrapped around a crooked silver signal pole, with three mismatched brass signal discs, a hooked clasp, and a short mistglass lens at the tip", "non_color_identity": "A long crooked pole carries one tightly folded triangular pennon, three round discs, and a narrow hooked lower tip."},
    {"prefix": "tidehook", "hero_id": "hero_veilmourn_olan_tidehook", "faction_id": "faction_veilmourn", "town_id": "town_veilmourn_bellwake_harbor", "enemy_town_id": "town_cinderlock_bastion", "scenario_id": "tidehook-memory-bosun-march", "scenario_name": "Tidehook Memory-Bosun March", "artifact_id": "artifact_tidehook_memory_bosun_bell", "artifact_name": "Tidehook Memory Bosun Bell", "source_name": "tidehook_memory_bosun_bell_source.png", "generation_original": "exec-c0784b9b-1f62-45e7-8ee5-9c0fafd0b559.png", "seed": 51200, "bonuses": {"battle_defense": 1, "overworld_movement": 1}, "roles": ["defense", "movement"], "summary": "A hooked bosun bell that recalls forgotten deck crews and keeps their retreat lane open.", "description": "A cracked ship bell ends in a crescent boarding hook beneath two rope loops, three memory chimes, and a wave-bone grip.", "prompt_subject": "one elongated cracked ship's bell ending in a large crescent boarding hook, wrapped by two uneven rope loops, with three small memory chimes and a bone handle shaped like a wave crest", "non_color_identity": "A narrow cracked bell extends into one enormous lower hook and carries three small side chimes beneath a wave-shaped handle."},
]


def render_art() -> dict:
    RUNTIME_ROOT.mkdir(parents=True, exist_ok=True)
    FIELD_ROOT.mkdir(parents=True, exist_ok=True)
    frames: list[Image.Image] = []
    manifest = {
        "schema_id": "command_relic_marches_art_v1", "content_batch_id": SLICE_ID,
        "generator_mode": "built_in_imagegen",
        "prompt_set_summary": "Twelve original transparent command relics, two per faction, with silhouette-first inventory and field identities tied to twelve live hero-led marches; no text, logos, characters, scenery, copied franchise art, or packaged source-master dependency.",
        "runtime_icon_size": [128, 128], "field_atlas_path": FIELD_ATLAS_RES,
        "field_atlas_size": [576, 48], "source_package_policy": "retained_for_provenance_excluded_from_linux_and_windows_exports", "items": [],
    }
    for index, case in enumerate(CASES):
        source = SOURCE_ROOT / case["source_name"]
        runtime = RUNTIME_ROOT / f"{case['artifact_id'].removeprefix('artifact_')}.png"
        base.transparent_contain(source, (128, 128), 8).save(runtime, optimize=True, compress_level=9)
        frames.append(base.transparent_contain(source, (48, 48), 3))
        prompt = (
            "Use case: stylized-concept; Asset type: production 2D fantasy strategy-game artifact source; "
            f"Primary request: Create {case['artifact_name']} for the original Aurelion Reach setting; Subject: {case['prompt_subject']}; "
            "Style: polished hand-painted 2D original fantasy game item art with crisp material separation; Composition: isolated high three-quarter view, centered with generous padding, strong silhouette readable at 48x48 and 128x128; "
            "Constraints: genuinely transparent background with preserved alpha, one object only, no ground, scenery, characters, text, letters, numbers, logos, watermark, border, frame, cast shadow, or copied franchise design."
        )
        manifest["items"].append({
            "artifact_id": case["artifact_id"], "hero_id": case["hero_id"], "faction_id": case["faction_id"],
            "source_path": f"res://{source.relative_to(ROOT)}", "source_sha256": base.sha256(source),
            "runtime_path": f"res://{runtime.relative_to(ROOT)}", "runtime_sha256": base.sha256(runtime),
            "field_region": [index * 48, 0, 48, 48], "generation_original": str(GENERATOR_ROOT / case["generation_original"]),
            "prompt": prompt, "accessible_description": case["non_color_identity"],
        })
    atlas = Image.new("RGBA", (576, 48), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        atlas.alpha_composite(frame, (index * 48, 0))
    atlas.save(FIELD_ATLAS, optimize=True, compress_level=9)
    manifest["field_atlas_sha256"] = base.sha256(FIELD_ATLAS)
    (SOURCE_ROOT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return manifest


def artifact_record(case: dict) -> dict:
    enriched = dict(case)
    enriched["accord"] = FACTION_ROUTES[case["faction_id"]]["accord"]
    record = base.artifact_record(enriched)
    record["family"] = "command_relic_marches"
    record["content_status"] = "command_relic_march_live"
    record["content_batch_id"] = SLICE_ID
    record["ai_hints"]["combo_tags"] = [enriched["accord"], case["prefix"], "command_relic"]
    return record


def terrain_map(primary: str, secondary: str, seed: int) -> list[list[str]]:
    return [[secondary if ((x * 7 + y * 11 + seed) % 17) in (0, 1, 2) else primary for x in range(15)] for y in range(10)]


def scenario_record(case: dict, hero_name: str) -> dict:
    route = FACTION_ROUTES[case["faction_id"]]
    prefix = case["prefix"]
    encounters = [{
        "placement_id": f"{prefix}_front_{index}", "encounter_id": encounter_id,
        "x": coords[0], "y": coords[1], "difficulty": "medium" if index < 3 else "high",
        "combat_seed": case["seed"] + index, "prefer_identity_landmark": True,
    } for index, (encounter_id, coords) in enumerate(zip(route["encounters"], [(4, 2), (7, 7), (11, 3)]), start=1)]
    victories = [
        {"id": f"{prefix}_prove_commander", "label": f"Keep {hero_name} in command of the march company", "type": "hero_army_meets_requirements", "hero_id": case["hero_id"], "requirements": [{"unit_id": route["stacks"][0][0], "minimum_count": 1}]},
        {"id": f"{prefix}_recover_relic", "label": f"Recover {case['artifact_name']}", "type": "artifact_owned_by_player", "artifact_id": case["artifact_id"]},
    ]
    victories.extend({"id": f"{prefix}_clear_front_{index}", "label": f"Break command relic front {index}", "type": "encounter_resolved", "placement_id": f"{prefix}_front_{index}"} for index in range(1, 4))
    return {
        "id": case["scenario_id"], "name": case["scenario_name"],
        "selection": {
            "summary": f"Lead {hero_name} across three contested fronts, recover {case['artifact_name']}, and return the relic to active command before Day 17.",
            "recommended_difficulty": "normal", "map_size_label": "Command Relic March (15x10)",
            "player_summary": f"{hero_name} begins with a five-company faction force and must personally prove the recovered relic in live battle.",
            "enemy_summary": f"{route['enemy_label']} hold three independent fronts, a rival town, and a late reserve route.",
            "availability": {"campaign": False, "skirmish": True},
        },
        "map_size": {"width": 15, "height": 10}, "player_faction_id": case["faction_id"],
        "player_army_id": f"army_{prefix}_command_relic_company", "hero_id": case["hero_id"],
        "starting_resources": {"gold": 7000, "wood": 10, "ore": 10, route["rare_id"]: 4},
        "map": terrain_map(*route["terrain"], case["seed"]), "start": {"x": 1, "y": 5}, "hero_starts": [case["hero_id"]],
        "objectives": {
            "victory_text": f"{hero_name} has recovered and field-proved {case['artifact_name']} across the full march.",
            "defeat_text": "The home seat falls, claimant pressure closes the road, or Day 17 ends the relic march.",
            "victory": victories,
            "defeat": [
                {"id": f"{prefix}_lose_home", "label": "Keep the home seat under player control", "type": "town_not_owned_by_player", "placement_id": f"{prefix}_home"},
                {"id": f"{prefix}_pressure", "label": "Keep claimant pressure below 24", "type": "enemy_pressure_at_least", "faction_id": route["enemy_faction_id"], "threshold": 24},
                {"id": f"{prefix}_deadline", "label": "Complete the command relic march before Day 17", "type": "day_at_least", "day": 17},
            ],
        },
        "script_hooks": [
            {"id": f"{prefix}_day_two_relief", "priority": 130, "conditions": [{"type": "day_at_least", "day": 2}, {"type": "town_owned_by_player", "placement_id": f"{prefix}_home"}], "effects": [{"type": "add_resources", "resources": {"gold": 450, "wood": 1, "ore": 1}}, {"type": "message", "text": "The home seat sends road stores and replacement hands onto the command march."}]},
            {"id": f"{prefix}_relic_recovery", "priority": 110, "conditions": [{"type": "objective_met", "objective_id": f"{prefix}_recover_relic"}], "effects": [{"type": "award_experience", "hero_id": case["hero_id"], "amount": 200}, {"type": "add_resources", "resources": {route["rare_id"]: 1}}, {"type": "message", "text": f"{case['artifact_name']} returns to an active commander's hands."}]},
            {"id": f"{prefix}_front_one_reinforcement", "priority": 100, "conditions": [{"type": "encounter_resolved", "placement_id": f"{prefix}_front_1"}], "effects": [{"type": "town_add_recruits", "placement_id": f"{prefix}_home", "recruits": {route["stacks"][0][0]: 2}}, {"type": "message", "text": "Freed road hands reinforce the home muster after the first claimant front falls."}]},
            {"id": f"{prefix}_day_seven_pressure", "priority": 90, "conditions": [{"type": "day_at_least", "day": 7}, {"type": "objective_not_met", "objective_id": f"{prefix}_recover_relic"}], "effects": [{"type": "add_enemy_pressure", "faction_id": route["enemy_faction_id"], "amount": 3}, {"type": "message", "text": "The unrecovered relic draws another claimant column onto the road."}]},
            {"id": f"{prefix}_day_nine_counterstroke", "priority": 70, "conditions": [{"type": "day_at_least", "day": 9}, {"type": "town_owned_by_player", "placement_id": f"{prefix}_home"}, {"type": "objective_not_met", "objective_id": f"{prefix}_recover_relic"}], "effects": [{"type": "spawn_encounter", "placement": {"placement_id": f"{prefix}_counterstroke", "encounter_id": route["encounters"][1], "x": 13, "y": 8, "difficulty": "scripted", "spawned_by_faction_id": route["enemy_faction_id"], "days_active": 0, "arrived": False, "goal_distance": 9999}}, {"type": "message", "text": "A late claimant reserve crosses the outer road before the relic can be secured."}]},
        ],
        "towns": [
            {"placement_id": f"{prefix}_home", "town_id": case["town_id"], "x": 0, "y": 5, "owner": "player", "built_buildings": ["building_market_square"]},
            {"placement_id": f"{prefix}_enemy_town", "town_id": case["enemy_town_id"], "x": 14, "y": 5, "owner": "enemy"},
        ],
        "enemy_factions": [{
            "faction_id": route["enemy_faction_id"], "label": route["enemy_label"], "pressure_per_day": 1, "pressure_per_enemy_town": 1,
            "raid_threshold": 9, "max_active_raids": 1, "raid_pillage_delay": 2, "raid_pillage": {"gold": 180},
            "raid_encounter_ids": route["encounters"][:2], "spawn_points": [{"x": 14, "y": 1}, {"x": 14, "y": 8}],
            "siege_target_placement_id": f"{prefix}_home", "priority_target_placement_ids": [f"{prefix}_home", f"{prefix}_relic", f"{prefix}_rare_1"],
        }],
        "resource_nodes": [
            {"placement_id": f"{prefix}_wood_1", "site_id": "site_wood_wagon", "x": 1, "y": 0},
            {"placement_id": f"{prefix}_ore_1", "site_id": "site_ore_crates", "x": 4, "y": 0},
            {"placement_id": f"{prefix}_rare_1", "site_id": route["rare_site_id"], "x": 8, "y": 0},
            {"placement_id": f"{prefix}_exchange", "site_id": "site_frontier_rare_exchange", "x": 12, "y": 0},
            {"placement_id": f"{prefix}_wood_2", "site_id": "site_wood_wagon", "x": 2, "y": 9},
            {"placement_id": f"{prefix}_ore_2", "site_id": "site_ore_crates", "x": 6, "y": 9},
            {"placement_id": f"{prefix}_rare_2", "site_id": route["rare_site_id"], "x": 10, "y": 9},
            {"placement_id": f"{prefix}_sanctum", "site_id": "site_roadside_sanctum", "x": 13, "y": 9},
        ],
        "artifact_nodes": [{"placement_id": f"{prefix}_relic", "artifact_id": case["artifact_id"], "x": 12, "y": 7, "guard_front_id": f"{prefix}_front_3"}],
        "encounters": encounters,
        "content_status": "command_relic_march_live", "content_batch_id": SLICE_ID,
        "scenario_family": "command_relic_march", "deterministic_seed": case["seed"],
        "command_relic_march": {"hero_id": case["hero_id"], "artifact_id": case["artifact_id"], "home_town_id": case["town_id"]},
    }


def main() -> None:
    art_manifest = render_art()
    artifact_rows = [artifact_record(case) for case in CASES]
    faction_artifacts: dict[str, list[str]] = defaultdict(list)
    for case in CASES:
        faction_artifacts[case["faction_id"]].append(case["artifact_id"])
    source_table = {
        "id": SOURCE_TABLE_ID, "schema": "artifact_source_reward_v1", "source_tag": "pickup",
        "reward_context": "authored_scenario_placement", "eligible_object_families": ["pickup"],
        "eligible_site_families": ["one_shot_pickup"], "required_object_tags": ["small_reward"], "required_reward_categories": [],
        "guard_tiers": ["unguarded", "light"], "rarity_bands": ["rare"],
        "artifact_ids": [case["artifact_id"] for case in CASES], "artifact_ids_by_faction": dict(faction_artifacts),
        "faction_constraints": list(faction_artifacts), "set_constraints": {"allowed_set_ids": [], "piece_limit_per_table": 0},
        "runtime_policy": {"metadata_only": True, "live_drop_execution": False, "save_version_bump": False, "equipment_runtime_effects": False, "ai_valuation_behavior": False, "rare_resource_activation": False},
    }
    artifact_path = CONTENT / "artifacts.json"
    base.append_source_table(artifact_path, source_table)
    artifact_payload = base.load("artifacts.json")
    for artifact_row in artifact_rows:
        base.upsert(artifact_payload["items"], artifact_row)
    artifact_path.write_text(json.dumps(artifact_payload, indent=2) + "\n", encoding="utf-8")

    heroes = {row["id"]: row for row in base.load("heroes.json")["items"]}
    groups = base.load("army_groups.json")
    scenarios = base.load("scenarios.json")
    overworld = json.loads(OVERWORLD_MANIFEST.read_text(encoding="utf-8"))
    atlas_hash = art_manifest["field_atlas_sha256"]
    for index, case in enumerate(CASES):
        base.upsert(groups["items"], {
            "id": f"army_{case['prefix']}_command_relic_company", "name": f"{case['artifact_name']} March Company",
            "faction_id": case["faction_id"], "stacks": [{"unit_id": unit_id, "count": count} for unit_id, count in FACTION_ROUTES[case["faction_id"]]["stacks"]],
            "content_status": "command_relic_march_company_live", "content_batch_id": SLICE_ID,
        })
        base.upsert(scenarios["items"], scenario_record(case, heroes[case["hero_id"]]["name"]))
        asset_id = f"artifact_field_{case['artifact_id'].removeprefix('artifact_')}"
        overworld.setdefault("artifact_field_sprites", {})[case["artifact_id"]] = asset_id
        overworld.setdefault("object_assets", {})[asset_id] = {
            "path": FIELD_ATLAS_RES, "atlas_region": [index * 48, 0, 48, 48], "atlas_size": [576, 48], "runtime_sha256": atlas_hash,
            "source_icon": f"res://art/artifacts/runtime/{case['artifact_id'].removeprefix('artifact_')}.png",
            "source_model": "built_in_imagegen_command_relic_marches_compact_field_atlas",
            "asset_policy": "exact_original_artifact_identity_shared_into_distinct_field_surface",
            "assigned_artifact_id": case["artifact_id"], "assigned_hero_id": case["hero_id"], "assigned_faction_id": case["faction_id"],
            "presentation_role": "command_relic_march_field_pickup", "accessible_description": case["non_color_identity"], "background": "transparent",
        }
    scenarios["player_facing_active_scenario_count"] = len(scenarios["items"])
    (CONTENT / "army_groups.json").write_text(base.dump_groups(groups), encoding="utf-8")
    (CONTENT / "scenarios.json").write_text(json.dumps(scenarios, separators=(",", ":")) + "\n", encoding="utf-8")
    OVERWORLD_MANIFEST.write_text(json.dumps(overworld, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({
        "slice_id": SLICE_ID, "scenario_count": len(scenarios["items"]), "army_group_count": len(groups["items"]),
        "artifact_count": len(base.load("artifacts.json")["items"]), "new_scenario_ids": [case["scenario_id"] for case in CASES],
        "new_artifact_ids": [case["artifact_id"] for case in CASES], "direct_battle_count": 36,
    }, indent=2))


if __name__ == "__main__":
    main()
