#!/usr/bin/env python3
"""Author twelve Marchland warband musters and their original rally art."""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image

import author_eight_commanders_proving_roads as base


ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / "content"
SOURCE_ROOT = ROOT / "art/overworld/source/generated/resource_sites/marchland_warband_musters_wave1"
ATLAS_PATH = ROOT / "art/overworld/runtime/objects/resource_sites/marchland_warband_musters_atlas.png"
ATLAS_RES = "res://art/overworld/runtime/objects/resource_sites/marchland_warband_musters_atlas.png"
SOURCE_RES = "res://art/overworld/source/generated/resource_sites/marchland_warband_musters_wave1"
ART_MANIFEST = ROOT / "art/overworld/manifest.json"
SLICE_ID = "content-twelve-marchland-warband-musters-10184"
GENERATOR_ROOT = Path("/root/.codex/generated_images/019fe72a-30b1-76f3-b911-385c4444bd16")


FACTIONS = {
    "ember": {
        "faction_id": "faction_embercourt", "home_town_id": "town_amberweir_granary",
        "enemy_town_id": "town_blackfen_gate", "enemy_faction_id": "faction_mireclaw",
        "enemy_label": "Blackfen Moon-Tollers", "rare_site_id": "site_embergrain_warm_granary",
        "rare_resource": "embergrain", "terrain": ("grass", "rough"),
        "stacks": [("unit_embercourt_fordhook_cadets", 60), ("unit_embercourt_lantern_sappers", 40), ("unit_embercourt_bargebow_crews", 24), ("unit_embercourt_amberweir_lockpike_wardens", 14), ("unit_embercourt_amberweir_sluicebrand_mangonels", 8)],
        "encounters": ["encounter_ashcrown_cinderfold_watch", "encounter_obsidian_scar_watch", "encounter_flaremast_pilotage_watch", "encounter_scarshield_breakyard_watch"],
    },
    "mire": {
        "faction_id": "faction_mireclaw", "home_town_id": "town_moonbite_reedshrine",
        "enemy_town_id": "town_dawnmirror_observatory", "enemy_faction_id": "faction_sunvault",
        "enemy_label": "Dawnmirror Levee-Surveyors", "rare_site_id": "site_peatwax_reed_yard",
        "rare_resource": "peatwax", "terrain": ("mire", "swamp"),
        "stacks": [("unit_mireclaw_reedsnare_kin", 60), ("unit_mireclaw_mudglass_slingers", 40), ("unit_mireclaw_bogplate_maulers", 24), ("unit_mireclaw_moonbite_votive_drummers", 14), ("unit_mireclaw_moonbite_mirehorn_breakers", 8)],
        "encounters": ["encounter_mireglass_bellbasin_watch", "encounter_miremoon_crownmere_watch", "encounter_fenhound_kennel_watch", "encounter_willow_mill_pack"],
    },
    "sun": {
        "faction_id": "faction_sunvault", "home_town_id": "town_splitprism_duelcourt",
        "enemy_town_id": "town_crownroot_refuge", "enemy_faction_id": "faction_thornwake",
        "enemy_label": "Crownroot Shade-Jurors", "rare_site_id": "site_aetherglass_lens_house",
        "rare_resource": "aetherglass", "terrain": ("sand", "grass"),
        "stacks": [("unit_sunvault_shard_wardens", 60), ("unit_sunvault_prism_adepts", 40), ("unit_sunvault_mirror_duelists", 24), ("unit_sunvault_splitprism_parallax_fencers", 14), ("unit_sunvault_splitprism_heliograph_ballistae", 8)],
        "encounters": ["encounter_noonshard_prism_aviary_watch", "encounter_sunscale_lantern_drift_watch", "encounter_galehorn_breakline_watch", "encounter_milestone_arsenal_watch"],
    },
    "thorn": {
        "faction_id": "faction_thornwake", "home_town_id": "town_woundroot_hearthgrove",
        "enemy_town_id": "town_brasshollow_orevein_gantry", "enemy_faction_id": "faction_brasshollow",
        "enemy_label": "Orevein Root-Assayers", "rare_site_id": "site_verdant_graft_nursery",
        "rare_resource": "verdant_grafts", "terrain": ("forest", "grass"),
        "stacks": [("unit_thornwake_seedcutters", 60), ("unit_thornwake_bramblekite_needlers", 40), ("unit_thornwake_seedshield_wardens", 24), ("unit_thornwake_woundroot_hearthseed_slingers", 14), ("unit_thornwake_woundroot_rootmaul_behemoths", 8)],
        "encounters": ["encounter_brambleback_hedgecourt_watch", "encounter_rootvault_heartwood_watch", "encounter_sapwhistle_greenward_watch", "encounter_glowcap_croft_watch"],
    },
    "brass": {
        "faction_id": "faction_brasshollow", "home_town_id": "town_whitegauge_calibration_yard",
        "enemy_town_id": "town_gloamwake_anchorage", "enemy_faction_id": "faction_veilmourn",
        "enemy_label": "Gloamwake Gauge-Saboteurs", "rare_site_id": "site_brass_scrip_mint",
        "rare_resource": "brass_scrip", "terrain": ("rough", "lava"),
        "stacks": [("unit_brasshollow_scrip_haulers", 60), ("unit_brasshollow_quenchspool_slingers", 40), ("unit_brasshollow_gaugefire_arbalists", 24), ("unit_brasshollow_whitegauge_datum_lancers", 14), ("unit_brasshollow_whitegauge_datum_breach_cannons", 8)],
        "encounters": ["encounter_deepforge_seventh_seal_watch", "encounter_quenchbell_pressure_den_watch", "encounter_windcairn_wayhouse_watch", "encounter_switchback_hostel_watch"],
    },
    "veil": {
        "faction_id": "faction_veilmourn", "home_town_id": "town_dreamwake_oracle_harbor",
        "enemy_town_id": "town_highwater_keep", "enemy_faction_id": "faction_embercourt",
        "enemy_label": "Highwater Fog-Breakers", "rare_site_id": "site_memory_salt_pan",
        "rare_resource": "memory_salt", "terrain": ("snow", "mire"),
        "stacks": [("unit_veilmourn_bellwake_oars", 60), ("unit_veilmourn_mourning_lanterns", 40), ("unit_veilmourn_maskglass_corsairs", 24), ("unit_veilmourn_dreamwake_tideglass_oracles", 14), ("unit_veilmourn_dreamwake_foganchor_colossi", 8)],
        "encounters": ["encounter_rimebell_whitewake_watch", "encounter_saltwake_belldeep_watch", "encounter_icehook_trapper_lodge_watch", "encounter_mireglass_bellfen_watch"],
    },
}


CASES = [
    {"key": "ember", "prefix": "tollchain", "scenario_id": "tollbrand-toll-chain-muster", "scenario_name": "Tollbrand Toll-Chain Muster", "hero_id": "hero_embercourt_helva_tollbrand", "site_id": "site_tollbrand_toll_chain_standard", "site_name": "Tollbrand Toll-Chain Standard", "asset_id": "resource_site_muster_tollbrand_toll_chain_standard", "source_name": "tollbrand_toll_chain_standard_source.png", "generation_original": "exec-faa5bffb-48c3-4597-a754-4aa1f385eb10.png", "action_label": "Ring the Toll-Chain Muster", "seed": 53100, "width": 16, "height": 10, "subject": "a broad river-toll rally arch on two stone feet, crossed by a heavy chain, with an oversized hooked brass tally bell, three unequal lock plates, and a small ember lantern", "description": "A broad stone-footed toll arch carries a heavy chain, hooked tally bell, unequal lock plates, and one ember lantern."},
    {"key": "ember", "prefix": "beaconledger", "scenario_id": "beaconscribe-beacon-ledger-muster", "scenario_name": "Beaconscribe Beacon-Ledger Muster", "hero_id": "hero_embercourt_jorun_beaconscribe", "site_id": "site_beaconscribe_beacon_ledger_post", "site_name": "Beaconscribe Beacon-Ledger Muster Post", "asset_id": "resource_site_muster_beaconscribe_beacon_ledger_post", "source_name": "beaconscribe_beacon_ledger_post_source.png", "generation_original": "exec-4e6424df-f1ee-4516-8206-42ea3466a09b.png", "action_label": "Open the Beacon Ledger", "seed": 53200, "width": 20, "height": 12, "subject": "a tall asymmetrical timber muster post with a hooded beacon brazier, blank hinged brass ledger plate, two offset sluice paddles, three hanging seal weights, and forked signal crown", "description": "An asymmetric timber post raises a hooded beacon above a blank ledger plate, offset paddles, hanging weights, and forked crown."},
    {"key": "mire", "prefix": "keeldrum", "scenario_id": "mudkeel-keel-drum-muster", "scenario_name": "Mudkeel Keel-Drum Muster", "hero_id": "hero_mireclaw_brakka_mudkeel", "site_id": "site_mudkeel_keel_drum_rally", "site_name": "Mudkeel Keel-Drum Rally", "asset_id": "resource_site_muster_mudkeel_keel_drum_rally", "source_name": "mudkeel_keel_drum_rally_source.png", "generation_original": "exec-8190417a-17bb-4d3a-a90f-89ad34594d6c.png", "action_label": "Beat the Keel-Drum", "seed": 53300, "width": 16, "height": 10, "subject": "a low half-moon skiff rib carrying a huge hide muster drum, crooked mud-coated keel, two chained beaters, three reed pennant fins, and hooked ferry weight", "description": "A half-moon skiff rib carries a huge hide drum, crooked keel, chained beaters, reed fins, and hooked ferry weight."},
    {"key": "mire", "prefix": "rotlamp", "scenario_id": "rotlamp-muster-cage", "scenario_name": "Rotlamp Muster-Cage", "hero_id": "hero_mireclaw_edda_rotlamp", "site_id": "site_rotlamp_muster_cage", "site_name": "Rotlamp Muster Cage", "asset_id": "resource_site_muster_rotlamp_muster_cage", "source_name": "rotlamp_muster_cage_source.png", "generation_original": "exec-3014ce54-e31f-4645-83e9-3e393012363c.png", "action_label": "Light the Rotlamp Muster", "seed": 53400, "width": 20, "height": 12, "subject": "a leaning wicker lantern cage with three oversized layered marsh fungi, crescent reed hood, two uneven bone handles, hanging clay drum, and long root hook", "description": "A leaning wicker cage shelters three luminous marsh fungi beneath a crescent hood, uneven handles, clay drum, and root hook."},
    {"key": "sun", "prefix": "sunthread", "scenario_id": "sunvein-sun-thread-muster", "scenario_name": "Sunvein Sun-Thread Muster", "hero_id": "hero_sunvault_calis_sunvein", "site_id": "site_sunvein_sun_thread_standard", "site_name": "Sunvein Sun-Thread Standard", "asset_id": "resource_site_muster_sunvein_sun_thread_standard", "source_name": "sunvein_sun_thread_standard_source.png", "generation_original": "exec-4a4e3e3d-3baa-4779-9137-0806dd4cb9af.png", "action_label": "Draw the Sun Thread", "seed": 53500, "width": 16, "height": 10, "subject": "a compact faceted prism obelisk wrapped by three broad ribbon-like light rails, an offset seven-ray sunwheel, two hanging crystal plumbs, and split fork base", "description": "A faceted prism obelisk twists inside three broad light rails beneath an offset sunwheel and two crystal plumbs."},
    {"key": "sun", "prefix": "rangelens", "scenario_id": "lenscaptain-range-lens-muster", "scenario_name": "Lens-Captain Range-Lens Muster", "hero_id": "hero_sunvault_dovan_lenscaptain", "site_id": "site_lenscaptain_range_lens_rally", "site_name": "Lens-Captain Range-Lens Rally", "asset_id": "resource_site_muster_lenscaptain_range_lens_rally", "source_name": "lenscaptain_range_lens_rally_source.png", "generation_original": "exec-65b2d034-0ec8-4dc9-91c8-de9a6b557ae6.png", "action_label": "Align the Range Lens", "seed": 53600, "width": 20, "height": 12, "subject": "an enormous oval survey lens on a forked ivory tripod with a long sighting needle, three unequal calibration vanes, hinged mirror flap, and suspended prism weight", "description": "A huge oval survey lens rests on a forked tripod with a sighting needle, calibration vanes, mirror flap, and prism weight."},
    {"key": "thorn", "prefix": "chorusbough", "scenario_id": "loamchant-chorus-bough-muster", "scenario_name": "Loamchant Chorus-Bough Muster", "hero_id": "hero_thornwake_elian_loamchant", "site_id": "site_loamchant_chorus_bough", "site_name": "Loamchant Chorus Bough", "asset_id": "resource_site_muster_loamchant_chorus_bough", "source_name": "loamchant_chorus_bough_source.png", "generation_original": "exec-84fab9ca-ae30-4df1-9d23-6b2c7305a884.png", "action_label": "Sound the Chorus Bough", "seed": 53700, "width": 16, "height": 10, "subject": "an arching living root bough with three large hollow seed-pod resonators, a spiral loam horn, two uneven leaf chimes, and braided root feet", "description": "A living root arch carries three hollow seed-pod resonators, a spiral loam horn, leaf chimes, and braided feet."},
    {"key": "thorn", "prefix": "cartcrown", "scenario_id": "thorncart-cart-crown-muster", "scenario_name": "Thorncart Cart-Crown Muster", "hero_id": "hero_thornwake_halen_thorncart", "site_id": "site_thorncart_cart_crown_rally", "site_name": "Thorncart Cart-Crown Rally", "asset_id": "resource_site_muster_thorncart_cart_crown_rally", "source_name": "thorncart_cart_crown_rally_source.png", "generation_original": "exec-403c738f-a1da-4b57-b0e9-0c1a59f023c4.png", "action_label": "Turn the Cart Crown", "seed": 53800, "width": 20, "height": 12, "subject": "an oversized broken cartwheel grown through a thorn-root crown, with short axle drum, three hanging bark tally discs, hooked tow branch, and two leaf pennants", "description": "A broken cartwheel grows through a thorn crown beside an axle drum, hanging bark tallies, hooked tow branch, and leaf pennants."},
    {"key": "brass", "prefix": "debtseal", "scenario_id": "debtrune-debt-seal-muster", "scenario_name": "Debt-Rune Debt-Seal Muster", "hero_id": "hero_brasshollow_harro_debtrune", "site_id": "site_debtrune_debt_seal_gantry", "site_name": "Debt-Rune Debt-Seal Gantry", "asset_id": "resource_site_muster_debtrune_debt_seal_gantry", "source_name": "debtrune_debt_seal_gantry_source.png", "generation_original": "exec-b7cf9878-b506-4a52-90fc-b3c717c94ab5.png", "action_label": "Balance the Debt Seal", "seed": 53900, "width": 16, "height": 10, "subject": "a squat black-iron assay gantry carrying a blank hexagonal seal plate, large toothed balance wheel, three uneven counterweights, broken measuring arm, and two pressure feet", "description": "A squat assay gantry balances a blank seal plate against a toothed wheel, uneven weights, broken measuring arm, and pressure feet."},
    {"key": "brass", "prefix": "pitbell", "scenario_id": "pitmarshal-pit-bell-muster", "scenario_name": "Pit-Marshal Pit-Bell Muster", "hero_id": "hero_brasshollow_selka_pitmarshal", "site_id": "site_pitmarshal_pit_bell_rally", "site_name": "Pit-Marshal Pit-Bell Rally", "asset_id": "resource_site_muster_pitmarshal_pit_bell_rally", "source_name": "pitmarshal_pit_bell_rally_source.png", "generation_original": "exec-4764040e-8eb6-4408-9343-8993012b58f2.png", "action_label": "Strike the Pit Bell", "seed": 54000, "width": 20, "height": 12, "subject": "a compact mine-cage headframe holding an oversized pressure bell, hooked lift chain, three descending gauge pipes, square ore skip, and crooked warning hammer", "description": "A compact mine headframe holds a huge pressure bell, lift chain, descending gauge pipes, ore skip, and warning hammer."},
    {"key": "veil", "prefix": "fogsail", "scenario_id": "mistcorsair-fog-sail-muster", "scenario_name": "Mist-Corsair Fog-Sail Muster", "hero_id": "hero_veilmourn_cela_mistcorsair", "site_id": "site_mistcorsair_fog_sail_muster", "site_name": "Mist-Corsair Fog-Sail Muster", "asset_id": "resource_site_muster_mistcorsair_fog_sail", "source_name": "mistcorsair_fog_sail_muster_source.png", "generation_original": "exec-86d5b59b-f1af-4a3b-9487-9d306f9670cb.png", "action_label": "Raise the Fog Sail", "seed": 54100, "width": 16, "height": 10, "subject": "a sharply folded crescent fog sail on a crooked mast with a broad boarding hook, three uneven mistglass signal discs, hanging lantern cage, and coiled deck rope", "description": "A sharply folded crescent fog sail rises beside a boarding hook, mistglass signals, lantern cage, and coiled deck rope."},
    {"key": "veil", "prefix": "keelsounding", "scenario_id": "keelwarden-keel-sounding-muster", "scenario_name": "Keel-Warden Keel-Sounding Muster", "hero_id": "hero_veilmourn_jessa_keelwarden", "site_id": "site_keelwarden_keel_sounding_frame", "site_name": "Keel-Warden Keel-Sounding Frame", "asset_id": "resource_site_muster_keelwarden_keel_sounding_frame", "source_name": "keelwarden_keel_sounding_frame_source.png", "generation_original": "exec-61464478-fd27-4151-af66-7473dafbe1ae.png", "action_label": "Sound the Keel Frame", "seed": 54200, "width": 20, "height": 12, "subject": "a tall inverted ship-keel rib on two narrow feet with a cracked sounding bell, long plumb hook, two offset tideglass floats, three rope knots, and forked bone finial", "description": "An inverted ship-keel rib carries a cracked sounding bell, long plumb hook, tideglass floats, rope knots, and forked finial."},
]


def terrain_map(primary: str, secondary: str, seed: int, width: int, height: int) -> list[list[str]]:
    return [[secondary if (x * 7 + y * 11 + seed) % 19 in (0, 1, 2, 3) else primary for x in range(width)] for y in range(height)]


def render_art() -> tuple[str, list[dict]]:
    ATLAS_PATH.parent.mkdir(parents=True, exist_ok=True)
    atlas = Image.new("RGBA", (576, 48), (0, 0, 0, 0))
    rows: list[dict] = []
    for index, case in enumerate(CASES):
        source = SOURCE_ROOT / case["source_name"]
        atlas.alpha_composite(base.transparent_frame(source), (index * 48, 0))
        prompt = (
            "Use case: stylized-concept; Asset type: production 2D fantasy strategy-game overworld rally landmark source; "
            f"Primary request: Create {case['site_name']} for the original Aurelion Reach setting; Scene/backdrop: genuinely transparent background; Subject: {case['subject']}; "
            "Style/medium: polished hand-painted 2D original fantasy game landmark art with crisp material separation; Composition/framing: isolated high three-quarter view, centered with generous padding, strong non-color silhouette readable at 48x48; "
            "Constraints: one landmark only; preserved alpha; no ground, scenery, characters, text, letters, numbers, logos, watermark, border, frame, cast shadow, or copied franchise design."
        )
        rows.append({"site_id": case["site_id"], "hero_id": case["hero_id"], "asset_id": case["asset_id"], "source_path": f"{SOURCE_RES}/{case['source_name']}", "source_sha256": base.sha256(source), "generation_original": str(GENERATOR_ROOT / case["generation_original"]), "atlas_region": [index * 48, 0, 48, 48], "prompt": prompt, "accessible_description": case["description"]})
    atlas.save(ATLAS_PATH, optimize=True, compress_level=9)
    atlas_sha = base.sha256(ATLAS_PATH)
    base.write_pretty(SOURCE_ROOT / "manifest.json", {"schema_id": "twelve_marchland_warband_musters_art_v1", "content_batch_id": SLICE_ID, "generation_mode": "built_in_imagegen", "source_model": "built_in_imagegen_original_marchland_warband_musters_atlas", "prompt_set_summary": "Twelve original transparent rally landmarks for twelve underused live heroes, with faction-readable non-color silhouettes at 48px and no packaged source-master dependency.", "runtime_atlas": ATLAS_RES, "runtime_atlas_size": [576, 48], "runtime_atlas_sha256": atlas_sha, "source_package_policy": "retained_for_provenance_excluded_from_linux_and_windows_exports", "items": rows})
    return atlas_sha, rows


def scenario_record(case: dict, hero_name: str, army_id: str) -> dict:
    faction = FACTIONS[case["key"]]
    prefix, width, height = case["prefix"], case["width"], case["height"]
    stacks = faction["stacks"]
    coords = [(4, 2), (width // 2 - 2, height - 3), (width // 2 + 2, 3), (width - 4, height - 3)]
    encounters = [{"placement_id": f"{prefix}_front_{index}", "encounter_id": encounter_id, "x": xy[0], "y": xy[1], "difficulty": "medium", "combat_seed": case["seed"] + index, "prefer_identity_landmark": True, "guardian_role": "marchland_warband_front"} for index, (encounter_id, xy) in enumerate(zip(faction["encounters"], coords), start=1)]
    victories = [
        {"id": f"{prefix}_hold_retinue", "label": f"Keep both {hero_name} Marchland companies in the warband", "type": "hero_army_meets_requirements", "hero_id": case["hero_id"], "requirements": [{"unit_id": stacks[3][0], "minimum_count": 1}, {"unit_id": stacks[4][0], "minimum_count": 1}]},
        {"id": f"{prefix}_claim_rally", "label": f"Claim {case['site_name']}", "type": "flag_true", "flag": f"{prefix}_rally_landmark_claimed"},
    ]
    victories.extend({"id": f"{prefix}_clear_front_{index}", "label": f"Resolve Marchland front {index}", "type": "encounter_resolved", "placement_id": f"{prefix}_front_{index}"} for index in range(1, 5))
    deadline = 21 if width == 16 else 24
    north_y, south_y, middle_y = 0, height - 1, height // 2
    node_specs = [
        ("wood_north", "site_wood_wagon", 1, north_y), ("ore_north", "site_ore_crates", 4, north_y),
        ("rare_north", faction["rare_site_id"], width // 2, north_y), ("exchange", "site_frontier_rare_exchange", width - 3, north_y),
        ("wood_south", "site_wood_wagon", 2, south_y), ("ore_south", "site_ore_crates", 5, south_y),
        ("rare_south", faction["rare_site_id"], width // 2 + 1, south_y), ("waystone", "site_waystone_cache", width - 3, south_y),
        ("mid_cache", "site_waystone_cache", width // 2, middle_y), ("landmark", case["site_id"], width - 4, middle_y),
    ]
    if width == 20:
        node_specs.extend([("west_stores", "site_wood_wagon", 3, middle_y - 2), ("east_stores", "site_ore_crates", width - 6, middle_y + 2)])
    resource_nodes = [{"placement_id": f"{prefix}_{name}", "site_id": site_id, "x": x, "y": y, **({"guard_front_id": f"{prefix}_front_4"} if name == "landmark" else {})} for name, site_id, x, y in node_specs]
    return {
        "id": case["scenario_id"], "name": case["scenario_name"],
        "selection": {"summary": f"Lead {hero_name}'s exact five-stack warband through four regional fronts, then claim {case['site_name']} before Day {deadline}.", "recommended_difficulty": "normal", "map_size_label": f"Marchland Warband Muster ({width}x{height})", "player_summary": f"{hero_name} leads both local Marchland companies in a visible five-stack field bar.", "enemy_summary": f"{faction['enemy_label']} hold an enemy town, four distinct fronts, and a late reserve.", "availability": {"campaign": False, "skirmish": True}},
        "map_size": {"width": width, "height": height}, "player_faction_id": faction["faction_id"], "player_army_id": army_id, "hero_id": case["hero_id"],
        "starting_resources": {"gold": 10000, "wood": 12, "ore": 12, "embergrain": 4, "aetherglass": 4, "peatwax": 4, "verdant_grafts": 4, "brass_scrip": 4, "memory_salt": 4},
        "map": terrain_map(*faction["terrain"], case["seed"], width, height), "start": {"x": 1, "y": middle_y}, "hero_starts": [case["hero_id"]],
        "objectives": {"victory_text": f"{hero_name} has assembled the Marchland warband and opened every contested route.", "defeat_text": f"The home town falls, enemy pressure closes the march, or Day {deadline} arrives before the rally is secured.", "victory": victories, "defeat": [{"id": f"{prefix}_lose_home", "label": "Keep the Marchland home town", "type": "town_not_owned_by_player", "placement_id": f"{prefix}_home"}, {"id": f"{prefix}_pressure", "label": "Keep Marchland pressure below 30", "type": "enemy_pressure_at_least", "faction_id": faction["enemy_faction_id"], "threshold": 30}, {"id": f"{prefix}_deadline", "label": f"Complete the muster before Day {deadline}", "type": "day_at_least", "day": deadline}]},
        "script_hooks": [
            {"id": f"{prefix}_day_two_muster", "priority": 130, "conditions": [{"type": "day_at_least", "day": 2}, {"type": "town_owned_by_player", "placement_id": f"{prefix}_home"}], "effects": [{"type": "add_resources", "resources": {"gold": 3000, "wood": 2, "ore": 2}}, {"type": "town_add_recruits", "placement_id": f"{prefix}_home", "recruits": {stacks[0][0]: 5, stacks[1][0]: 3}}, {"type": "message", "text": "The Marchland council opens its two-company muster and field stores."}]},
            {"id": f"{prefix}_first_front_relief", "priority": 120, "conditions": [{"type": "encounter_resolved", "placement_id": f"{prefix}_front_1"}], "effects": [{"type": "add_army_units", "units": {stacks[3][0]: 2, stacks[0][0]: 4}}, {"type": "message", "text": "Freed Marchland hands reinforce the local retinue."}]},
            {"id": f"{prefix}_second_front_stores", "priority": 110, "conditions": [{"type": "encounter_resolved", "placement_id": f"{prefix}_front_2"}], "effects": [{"type": "add_resources", "resources": {"gold": 900, "wood": 2, "ore": 2}}, {"type": "message", "text": "The second front yields stores for the exposed march."}]},
            {"id": f"{prefix}_rally_recorded", "priority": 100, "conditions": [{"type": "objective_met", "objective_id": f"{prefix}_claim_rally"}], "effects": [{"type": "add_resources", "resources": {"gold": 700}}, {"type": "message", "text": "The rally landmark records the assembled warband."}]},
            {"id": f"{prefix}_day_twelve_reserve", "priority": 80, "conditions": [{"type": "day_at_least", "day": 12}, {"type": "objective_not_met", "objective_id": f"{prefix}_claim_rally"}], "effects": [{"type": "add_enemy_pressure", "faction_id": faction["enemy_faction_id"], "amount": 3}, {"type": "town_add_recruits", "placement_id": f"{prefix}_home", "recruits": {stacks[2][0]: 2, stacks[3][0]: 1}}, {"type": "spawn_encounter", "placement": {"placement_id": f"{prefix}_late_reserve", "encounter_id": faction["encounters"][3], "x": width - 2, "y": height - 2, "difficulty": "scripted", "spawned_by_faction_id": faction["enemy_faction_id"], "days_active": 0, "arrived": False, "goal_distance": 9999}}, {"type": "message", "text": "The enemy town commits a reserve while the Marchland rally remains unclaimed."}]},
        ],
        "towns": [{"placement_id": f"{prefix}_home", "town_id": faction["home_town_id"], "x": 0, "y": middle_y, "owner": "player", "built_buildings": ["building_market_square"]}, {"placement_id": f"{prefix}_enemy_town", "town_id": faction["enemy_town_id"], "x": width - 1, "y": middle_y, "owner": "enemy"}],
        "enemy_factions": [{"faction_id": faction["enemy_faction_id"], "label": faction["enemy_label"], "pressure_per_day": 1, "pressure_per_enemy_town": 1, "raid_threshold": 9, "max_active_raids": 1, "raid_pillage_delay": 2, "raid_pillage": {"gold": 200}, "raid_encounter_ids": faction["encounters"], "spawn_points": [{"x": width - 1, "y": 1}, {"x": width - 1, "y": height - 2}], "siege_target_placement_id": f"{prefix}_home", "siege_active_raid_threshold": 2, "siege_capture_progress": 2, "priority_target_placement_ids": [f"{prefix}_home", f"{prefix}_landmark"]}],
        "resource_nodes": resource_nodes, "artifact_nodes": [], "encounters": encounters,
        "content_status": "marchland_warband_muster_live", "content_batch_id": SLICE_ID, "scenario_family": "marchland_warband_muster", "deterministic_seed": case["seed"],
        "marchland_warband_muster": {"hero_id": case["hero_id"], "landmark_site_id": case["site_id"], "home_town_id": faction["home_town_id"], "enemy_town_id": faction["enemy_town_id"], "front_count": 4, "local_unit_ids": [stacks[3][0], stacks[4][0]]},
    }


def main() -> None:
    scenarios = base.load(CONTENT / "scenarios.json")
    groups = base.load(CONTENT / "army_groups.json")
    sites = base.load(CONTENT / "resource_sites.json")
    heroes = {row["id"]: row for row in base.load(CONTENT / "heroes.json")["items"]}
    art = base.load(ART_MANIFEST)
    atlas_sha, source_rows = render_art()
    for index, case in enumerate(CASES):
        faction = FACTIONS[case["key"]]
        hero = heroes[case["hero_id"]]
        army_id = f"army_{case['prefix']}_marchland_warband"
        base.upsert(groups["items"], {"id": army_id, "name": f"{hero['name']} Marchland Warband", "faction_id": faction["faction_id"], "stacks": [{"unit_id": unit_id, "count": count} for unit_id, count in faction["stacks"]], "content_status": "marchland_warband_company_live", "content_batch_id": SLICE_ID})
        base.upsert(sites["items"], {"id": case["site_id"], "name": case["site_name"], "family": "scenario_objective", "action_label": case["action_label"], "summary": f"{case['site_name']} assembles {hero['name']}'s two local Marchland companies after its four-front route is opened.", "claim_rewards": {"gold": 600, faction["rare_resource"]: 1, "experience": 150}, "claim_recruits": {faction["stacks"][3][0]: 3, faction["stacks"][4][0]: 1}, "claim_flags": {f"{case['prefix']}_rally_landmark_claimed": True}, "runtime_boundary": {"status": "marchland_warband_muster_live", "live_reward_grants": True, "save_payload_required": True, "renderer_sprite_required": True, "pathing_runtime_adopted": True, "route_effect_runtime_adopted": False, "hero_progression_activation": True, "scenario_placement_migration": True}, "content_batch_id": SLICE_ID, "public_text": {"public_summary": case["description"], "no_internal_debug_score_fields": True, "large_text_panel_required": False}})
        base.upsert(scenarios["items"], scenario_record(case, hero["name"], army_id))
        art["object_assets"][case["asset_id"]] = {"path": ATLAS_RES, "atlas_region": [index * 48, 0, 48, 48], "atlas_size": [576, 48], "runtime_sha256": atlas_sha, "source_trimmed": source_rows[index]["source_path"], "source_generated": source_rows[index]["source_path"], "source_model": "built_in_imagegen_original_marchland_warband_musters_atlas", "asset_policy": "original_generated_runtime_sprite_no_homm3_art_import", "distinct_sprite_assignment": True, "assigned_resource_site_id": case["site_id"], "assigned_hero_id": case["hero_id"], "presentation_role": case["site_id"].removeprefix("site_"), "accessible_description": case["description"]}
        art["resource_site_sprites"][case["site_id"]] = {"asset_id": case["asset_id"], "unclaimed_asset_id": case["asset_id"], "fit": f"Exact original {case['site_name']} remains visible before and after its one-time warband claim."}
    scenarios["player_facing_active_scenario_count"] = len(scenarios["items"])
    base.write_compact(CONTENT / "scenarios.json", scenarios)
    base.write_groups(CONTENT / "army_groups.json", groups)
    base.write_pretty(CONTENT / "resource_sites.json", sites)
    base.write_pretty(ART_MANIFEST, art)
    print(json.dumps({"slice_id": SLICE_ID, "scenario_count": len(scenarios["items"]), "army_group_count": len(groups["items"]), "resource_site_count": len(sites["items"]), "atlas_sha256": atlas_sha}, sort_keys=True))


if __name__ == "__main__":
    main()
