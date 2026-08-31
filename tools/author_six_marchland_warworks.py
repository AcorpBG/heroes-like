#!/usr/bin/env python3
"""Author six Marchland warworks, exclusive buildings, and third-use skirmishes."""

from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path

from PIL import Image, ImageOps


ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / "content"
SLICE_ID = "content-six-marchland-warworks-10184"
UNIT_SOURCE_ROOT = ROOT / "art" / "units" / "source" / "generated" / "marchland_warworks"
UNIT_CURATED_ROOT = ROOT / "art" / "units" / "source" / "curated"
BUILDING_SOURCE_ROOT = ROOT / "art" / "towns" / "source" / "generated" / "buildings" / "marchland_warworks"
BUILDING_CURATED_ROOT = ROOT / "art" / "towns" / "source" / "buildings" / "curated"
GENERATOR_ROOT = Path("/root/.codex/generated_images/019fe72a-30b1-76f3-b911-385c4444bd16")


CASES = [
    {
        "prefix": "amberweirworks", "scenario_id": "rainledger-amberweir-sluicebrand-works", "scenario_name": "Rainledger Amberweir Sluicebrand Works",
        "town_id": "town_amberweir_granary", "town_name": "Amberweir Granary", "hero_id": "hero_embercourt_belis_rainledger", "faction_id": "faction_embercourt",
        "enemy_faction_id": "faction_mireclaw", "enemy_town_id": "town_blackfen_gate", "rare_id": "embergrain", "rare_site_id": "site_embergrain_warm_granary",
        "unit_id": "unit_embercourt_amberweir_sluicebrand_mangonels", "unit_name": "Sluicebrand Mangonels", "role": "ranged", "hp": 44, "attack": 13, "defense": 10, "damage": [11, 16], "speed": 3, "initiative": 6, "shots": 5, "cost": {"gold": 750, "ore": 2}, "school": "beacon",
        "abilities": [
            {"id": "volley", "name": "Sluicebrand Arc", "description": "A sealed emberglass charge keeps its counterweighted arc across open lanes and breaks hardest over disrupted ranks.", "damage_multiplier": 1.08, "min_distance": 2, "status_ids": ["status_harried", "status_staggered"], "status_damage_multiplier": 1.06, "ally_defending_multiplier": 1.03},
            {"id": "readiness_writ", "name": "Counterweight Ledger", "description": "Once per battle, the crew clears a veteran line's broken timing or records the measured counterweight that steadies its next response.", "cleansed_status_ids": ["status_harried", "status_mire_harried", "status_staggered"], "preparation_status_id": "status_readiness_prepared", "preparation_status_label": "Counterweight-Readied", "preparation_target_role": "melee", "preparation_target_min_tier": 4, "preparation_duration_rounds": 99, "uses_per_battle": 1, "ai_attack_score_bonus": 1.25},
        ],
        "building_id": "building_embercourt_amberweir_counterweight_foundry", "building_name": "Amberweir Counterweight Foundry", "requires": ["building_embercourt_drake_sluice", "building_embercourt_amberweir_sluiceguard_lock"], "building_cost": {"gold": 800, "wood": 1},
        "building_description": "A water-driven civic foundry casts counterweights, sealed emberglass cradles, and shield mantlets for Amberweir's Sluicebrand Mangonels.",
        "terrain": ["grass", "dirt"], "seed": 49100, "encounters": ["encounter_briarmarshal_drum_cordon", "encounter_mudkeel_fenbell_commission", "encounter_reedscript_fenhound_lexicon"],
        "conventional": [["unit_embercourt_fordhook_cadets", 16], ["unit_embercourt_bargebow_crews", 9], ["unit_embercourt_ash_oath_bailiffs", 5], ["unit_embercourt_lockglass_writcasters", 3]],
        "unit_generated": "exec-2937b2a5-94ce-4013-859c-27b0f8a5c3ff.png", "building_generated": "exec-db177f42-1f4b-44a7-ba3b-f15aa33c9bed.png",
        "unit_prompt": "Use case: stylized-concept; Asset type: production game unit master; Primary request: one original Amberweir Sluicebrand Mangonel, a compact wheeled river-siege engine operated by two disciplined civic artillery crew; Subject: bronze counterweight arm, forked emberglass payload cradle, heavy timber wheels, rust-red shield mantlets, visible water-pressure gauges; Style/medium: polished hand-painted fantasy strategy game illustration; Composition/framing: complete full unit and both crew visible, three-quarter battle view, strong readable silhouette when reduced to 96 pixels, generous transparent padding; Lighting/mood: warm forge light with restrained ember glow; Constraints: genuinely transparent background; original design; no scenery; no text; no logo; no watermark; no franchise design; no cropped wheels, arm, crew, or weapon",
        "building_prompt": "Use case: stylized-concept; Asset type: production town-building master; Primary request: the original Amberweir Counterweight Foundry, the town-exclusive works that builds Sluicebrand Mangonels; Subject: compact fortified timber-and-bronze workshop, huge counterweight crane, water-pressure wheel, emberglass payload racks, rust-red tile roof, civic shield mantlets; Style/medium: polished hand-painted fantasy strategy town illustration; Composition/framing: complete building visible in elevated three-quarter isometric view, strong readable 256-pixel silhouette, generous transparent padding; Lighting/mood: warm forge light and restrained ember glow; Constraints: genuinely transparent background; original architecture; no surrounding scenery; no people; no text; no logo; no watermark; no franchise design; no cropped crane, wheel, roof, or foundation",
    },
    {
        "prefix": "moonbiteworks", "scenario_id": "votivejaw-moonbite-mirehorn-works", "scenario_name": "Votivejaw Moonbite Mirehorn Works",
        "town_id": "town_moonbite_reedshrine", "town_name": "Moonbite Reedshrine", "hero_id": "hero_mireclaw_nix_votivejaw", "faction_id": "faction_mireclaw",
        "enemy_faction_id": "faction_sunvault", "enemy_town_id": "town_prismhearth", "rare_id": "peatwax", "rare_site_id": "site_peatwax_reed_yard",
        "unit_id": "unit_mireclaw_moonbite_mirehorn_breakers", "unit_name": "Mirehorn Breakers", "role": "melee", "hp": 52, "attack": 14, "defense": 12, "damage": [12, 18], "speed": 5, "initiative": 7, "cost": {"gold": 790, "peatwax": 1}, "school": "mire",
        "abilities": [
            {"id": "hookline", "name": "Mirehorn Chain-Cast", "description": "Once per battle after the lines close, the breaker casts its harness chain across a broken lane and pins the surviving target beneath the crescent horn.", "distance_one_multiplier": 0.0, "uses_per_battle": 1, "available_from_round": 2, "status_id": "status_rooted", "status_label": "Mirehorn-Pinned", "duration_rounds": 1},
            {"id": "bloodrush", "name": "Votive Stampede", "description": "The first wound looses the breaker into a lantern-led stampede while the handler's cadence keeps the charge inside the line.", "wounded_threshold_ratio": 0.5, "wounded_damage_multiplier": 1.1, "status_ids": ["status_rooted", "status_harried"], "status_damage_multiplier": 1.05, "wounded_initiative_bonus": 1, "max_initiative_bonus": 2, "momentum_gain": 1, "kill_momentum_gain": 1},
        ],
        "building_id": "building_mireclaw_moonbite_mirehorn_chain_pen", "building_name": "Moonbite Mirehorn Chain-Pen", "requires": ["building_mireclaw_antler_pit", "building_mireclaw_moonbite_votive_drum_court"], "building_cost": {"gold": 800, "ore": 1},
        "building_description": "A crescent antler stockade and chain-yard trains Moonbite's broad Mirehorn Breakers to follow votive cadence through a fortified line.",
        "terrain": ["mire", "swamp"], "seed": 49200, "encounters": ["encounter_daynote_refraction_bench", "encounter_glassmarshal_counterseal_battery", "encounter_halometer_daylight_crown"],
        "conventional": [["unit_mireclaw_reedsnare_kin", 16], ["unit_mireclaw_mudglass_slingers", 9], ["unit_mireclaw_bogplate_maulers", 5], ["unit_mireclaw_mireglass_reedcasters", 3]],
        "unit_generated": "exec-d09bb9c9-2141-4dfa-81dc-bab38fd3f336.png", "building_generated": "exec-ee3f2f41-58fe-491a-8cb9-5f727c2a7e2b.png",
        "unit_prompt": "Use case: stylized-concept; Asset type: production game unit master; Primary request: one original Moonbite Mirehorn Breaker, an immense armored marsh beast trained to smash fortified lines; Subject: low broad six-limbed mire beast, crescent antler ram, reed-and-bone barding, black chain harness, amber votive lanterns, one small handler for scale; Style/medium: polished hand-painted fantasy strategy game illustration; Composition/framing: complete full creature and handler visible, three-quarter charging pose, strong readable silhouette when reduced to 96 pixels, generous transparent padding; Lighting/mood: damp moonlit highlights with warm lantern accents; Constraints: genuinely transparent background; original nonhuman design; no scenery; no text; no logo; no watermark; no franchise design; no cropped limbs, antlers, chain, or handler",
        "building_prompt": "Use case: stylized-concept; Asset type: production town-building master; Primary request: the original Moonbite Mirehorn Chain-Pen, the town-exclusive works that trains Mirehorn Breakers; Subject: compact crescent reed-and-bone stockade, immense antler gate, black chain winches, amber votive lanterns, raised plank platforms and muddy hoof gates; Style/medium: polished hand-painted fantasy strategy town illustration; Composition/framing: complete building visible in elevated three-quarter isometric view, strong readable 256-pixel silhouette, generous transparent padding; Lighting/mood: damp moonlit timber with warm lantern accents; Constraints: genuinely transparent background; original architecture; no surrounding scenery; no people or animals; no text; no logo; no watermark; no franchise design; no cropped gate, pen, winches, or foundation",
    },
    {
        "prefix": "splitprismworks", "scenario_id": "facetlane-splitprism-heliograph-works", "scenario_name": "Facetlane Splitprism Heliograph Works",
        "town_id": "town_splitprism_duelcourt", "town_name": "Splitprism Duelcourt", "hero_id": "hero_sunvault_renn_facetlane", "faction_id": "faction_sunvault",
        "enemy_faction_id": "faction_thornwake", "enemy_town_id": "town_briarwheel_enclave", "rare_id": "aetherglass", "rare_site_id": "site_aetherglass_lens_house",
        "unit_id": "unit_sunvault_splitprism_heliograph_ballistae", "unit_name": "Heliograph Ballistae", "role": "ranged", "hp": 40, "attack": 14, "defense": 9, "damage": [11, 17], "speed": 4, "initiative": 8, "shots": 5, "cost": {"gold": 800, "aetherglass": 1}, "school": "lens",
        "abilities": [
            {"id": "volley", "name": "Twin-Facet Solution", "description": "Blue and amber bow-arms resolve one measured firing solution through an open lens lane and intensify it against disrupted ranks.", "damage_multiplier": 1.08, "min_distance": 2, "status_ids": ["status_harried", "status_staggered"], "status_damage_multiplier": 1.07, "ally_defending_multiplier": 1.03},
            {"id": "resonance_relay", "name": "Heliograph Relay", "description": "The rotating lens synchronizes nearby calibrated stacks into one firing measure before the shot leaves the carriage.", "minimum_calibrated_stacks": 2, "maximum_calibrated_stacks": 3, "line_damage_per_calibrated_stack": 0.03, "line_initiative_bonus": 1, "late_round_initiative_bonus": 1, "terrain_momentum_bonus": 1, "linked_unit_ids": ["unit_sunvault_prism_adepts"], "linked_initiative_bonus": 1},
        ],
        "building_id": "building_sunvault_splitprism_heliograph_battery", "building_name": "Splitprism Heliograph Battery", "requires": ["building_sunvault_aurora_spire", "building_sunvault_splitprism_parallax_duel_hall"], "building_cost": {"gold": 800, "wood": 1},
        "building_description": "A twin-towered artillery court aligns mobile Heliograph Ballistae through Splitprism's blue and amber calibration facets.",
        "terrain": ["sand", "rough"], "seed": 49300, "encounters": ["encounter_briarwheel_witness_watch", "encounter_graftsibyl_wake_cordon", "encounter_loamchant_crystal_sump_binding"],
        "conventional": [["unit_sunvault_shard_wardens", 16], ["unit_sunvault_prism_adepts", 9], ["unit_sunvault_mirror_duelists", 5], ["unit_sunvault_resonant_choristers", 3]],
        "unit_generated": "exec-4a17c95a-48e9-4e20-ae28-78bb2bbcb662.png", "building_generated": "exec-fee4189b-b523-4b3d-afb2-f90dd8863561.png",
        "unit_prompt": "Use case: stylized-concept; Asset type: production game unit master; Primary request: one original Splitprism Heliograph Ballista, a mobile precision war engine built around refracted sunlight; Subject: white-stone and cobalt carriage, twin asymmetric blue and amber crystal bow-arms, circular rotating lens, slender articulated stabilizers, one armored lenswright operator; Style/medium: polished hand-painted fantasy strategy game illustration; Composition/framing: complete full engine and operator visible, three-quarter battle view, strong readable silhouette when reduced to 96 pixels, generous transparent padding; Lighting/mood: clean daylight with controlled blue and amber refractions; Constraints: genuinely transparent background; original design; no scenery; no text; no logo; no watermark; no franchise design; no cropped bow arms, wheels, stabilizers, or operator",
        "building_prompt": "Use case: stylized-concept; Asset type: production town-building master; Primary request: the original Splitprism Heliograph Battery, the town-exclusive works that builds Heliograph Ballistae; Subject: compact white-stone artillery court, twin asymmetric blue and amber crystal bow towers, immense rotating central lens, brass aiming rings and stabilizer racks; Style/medium: polished hand-painted fantasy strategy town illustration; Composition/framing: complete building visible in elevated three-quarter isometric view, strong readable 256-pixel silhouette, generous transparent padding; Lighting/mood: clean daylight with controlled blue and amber refractions; Constraints: genuinely transparent background; original architecture; no surrounding scenery; no people; no text; no logo; no watermark; no franchise design; no cropped lens, towers, rings, or foundation",
    },
    {
        "prefix": "woundrootworks", "scenario_id": "greenbarrow-woundroot-rootmaul-works", "scenario_name": "Greenbarrow Woundroot Rootmaul Works",
        "town_id": "town_woundroot_hearthgrove", "town_name": "Woundroot Hearthgrove", "hero_id": "hero_thornwake_merek_greenbarrow", "faction_id": "faction_thornwake",
        "enemy_faction_id": "faction_brasshollow", "enemy_town_id": "town_cindercoil_foundry", "rare_id": "verdant_grafts", "rare_site_id": "site_verdant_graft_nursery",
        "unit_id": "unit_thornwake_woundroot_rootmaul_behemoths", "unit_name": "Rootmaul Behemoths", "role": "melee", "hp": 58, "attack": 13, "defense": 14, "damage": [11, 17], "speed": 4, "initiative": 6, "cost": {"gold": 780, "wood": 3}, "school": "root",
        "abilities": [
            {"id": "bramble_ground", "name": "Rootmaul Ground", "description": "On a held breach line, the behemoth drives living roots beneath attackers and answers their impact from a planted seed-heart.", "held_objective_types": ["cover_line", "obstruction_line", "breach_point"], "defending_cohesion_bonus": 2, "retaliation_multiplier": 1.08, "rooted_damage_multiplier": 1.06, "status_id": "status_rooted", "status_label": "Rootmaul-Bound", "duration_rounds": 1, "modifiers": {"initiative": -1}, "ai_rooted_target_priority_bonus": 1.25},
            {"id": "brace", "name": "Stonewood Set", "description": "Stonewood shoulders settle behind the forked crown and return the enemy's charge through the held ground.", "retaliation_multiplier": 1.1, "defending_cohesion_bonus": 2, "status_id": "status_staggered", "status_label": "Rootmaul-Staggered", "duration_rounds": 1, "modifiers": {"initiative": -1}},
        ],
        "building_id": "building_thornwake_woundroot_rootmaul_hollow", "building_name": "Woundroot Rootmaul Hollow", "requires": ["building_thornwake_graftworks", "building_thornwake_woundroot_hearthseed_nursery"], "building_cost": {"gold": 800, "ore": 5},
        "building_description": "A monumental living hollow grows Rootmaul Behemoths around stonewood shoulders and a shared amber seed-heart.",
        "terrain": ["forest", "grass"], "seed": 49400, "encounters": ["encounter_gaugesavant_switchback_proof", "encounter_tallyspring_proving_rack", "encounter_ironclause_ninefold_assize"],
        "conventional": [["unit_thornwake_seedcutters", 22], ["unit_thornwake_bramblekite_needlers", 12], ["unit_thornwake_seedshield_wardens", 7], ["unit_thornwake_sporeglass_menders", 4]],
        "unit_generated": "exec-57248a01-3641-48dc-9caf-f4d712eed040.png", "building_generated": "exec-a8ff4877-30f0-40b4-a023-b93a03751639.png",
        "unit_prompt": "Use case: stylized-concept; Asset type: production game unit master; Primary request: one original Woundroot Rootmaul Behemoth, a towering living siege guardian grown to break enemy lines; Subject: massive four-legged root-and-bark creature, blunt forked crown, stonewood shoulder plates, glowing amber seed-heart, hanging leaf canopies, no rider; Style/medium: polished hand-painted fantasy strategy game illustration; Composition/framing: complete full creature visible, three-quarter advancing pose, strong readable silhouette when reduced to 96 pixels, generous transparent padding; Lighting/mood: warm living-wood glow and deep forest greens; Constraints: genuinely transparent background; original nonhuman design; no scenery; no text; no logo; no watermark; no franchise design; no cropped limbs, crown, or canopy",
        "building_prompt": "Use case: stylized-concept; Asset type: production town-building master; Primary request: the original Woundroot Rootmaul Hollow, the town-exclusive growth sanctuary for Rootmaul Behemoths; Subject: compact monumental living-tree hollow, blunt forked crown gateway, stonewood shoulder-shaped buttresses, glowing amber seed-heart chamber, layered leaf canopy; Style/medium: polished hand-painted fantasy strategy town illustration; Composition/framing: complete building visible in elevated three-quarter isometric view, strong readable 256-pixel silhouette, generous transparent padding; Lighting/mood: warm living-wood glow and deep forest greens; Constraints: genuinely transparent background; original architecture; no surrounding scenery; no people or creatures; no text; no logo; no watermark; no franchise design; no cropped roots, canopy, gateway, or foundation",
    },
    {
        "prefix": "whitegaugeworks", "scenario_id": "gaugesavant-whitegauge-breach-pressure-works", "scenario_name": "Gauge-Savant Whitegauge Breach-Pressure Works",
        "town_id": "town_whitegauge_calibration_yard", "town_name": "Whitegauge Calibration Yard", "hero_id": "hero_brasshollow_lina_gaugesavant", "faction_id": "faction_brasshollow",
        "enemy_faction_id": "faction_veilmourn", "enemy_town_id": "town_gloamwake_anchorage", "rare_id": "brass_scrip", "rare_site_id": "site_brass_scrip_mint",
        "unit_id": "unit_brasshollow_whitegauge_datum_breach_cannons", "unit_name": "Datum Breach-Cannons", "role": "ranged", "hp": 48, "attack": 14, "defense": 11, "damage": [13, 19], "speed": 3, "initiative": 5, "shots": 4, "cost": {"gold": 820, "ore": 3}, "school": "furnace",
        "abilities": [
            {"id": "harry", "name": "Datum Breach Mark", "description": "A calibrated breach shell strips cover from the struck line and leaves the target exposed to the measured follow-up barrage.", "status_id": "status_harried", "status_label": "Datum-Marked", "duration_rounds": 2, "modifiers": {"defense": -1, "initiative": -1}, "momentum_gain": 1},
            {"id": "volley", "name": "Plumb-Line Barrage", "description": "Beyond the first rank, the plumb gauges settle and the short rail drives a harder shell into a disrupted formation.", "damage_multiplier": 1.08, "min_distance": 2, "status_ids": ["status_harried", "status_staggered"], "status_damage_multiplier": 1.06, "ally_defending_multiplier": 1.02},
        ],
        "building_id": "building_brasshollow_whitegauge_breach_pressure_foundry", "building_name": "Whitegauge Breach-Pressure Foundry", "requires": ["building_brasshollow_crucible_dock", "building_brasshollow_whitegauge_datum_railhouse"], "building_cost": {"gold": 800, "ore": 3},
        "building_description": "A white-ceramic pressure hall proofs the short rails, six-legged carriages, and calibrated boilers of Whitegauge's Datum Breach-Cannons.",
        "terrain": ["rough", "dirt"], "seed": 49500, "encounters": ["encounter_keelwarden_dustjack_screen", "encounter_mistcorsair_foghook_boarding", "encounter_pale_sounding_memory_watch"],
        "conventional": [["unit_brasshollow_scrip_haulers", 16], ["unit_brasshollow_quenchspool_slingers", 9], ["unit_brasshollow_gaugefire_arbalists", 5], ["unit_brasshollow_gaugeplate_bailiffs", 3]],
        "unit_generated": "exec-319c87d5-a209-4716-8c5a-17487a3b80dc.png", "building_generated": "exec-34d79721-4419-4b42-be4b-075b1e3b8574.png",
        "unit_prompt": "Use case: stylized-concept; Asset type: production game unit master; Primary request: one original Whitegauge Datum Breach-Cannon, a compact self-propelled pressure artillery engine; Subject: low six-legged white-ceramic and aged-brass chassis, oversized short rail cannon, soot-black pressure boiler, calibrated plumb gauges, one armored engineer; Style/medium: polished hand-painted fantasy strategy game illustration; Composition/framing: complete full engine and engineer visible, three-quarter battle view, strong readable silhouette when reduced to 96 pixels, generous transparent padding; Lighting/mood: hot furnace highlights against cool ceramic; Constraints: genuinely transparent background; original design; no scenery; no text; no logo; no watermark; no franchise design; no cropped legs, barrel, boiler, gauges, or engineer",
        "building_prompt": "Use case: stylized-concept; Asset type: production town-building master; Primary request: the original Whitegauge Breach-Pressure Foundry, the town-exclusive works that builds Datum Breach-Cannons; Subject: compact white-ceramic and aged-brass artillery hall, short massive test barrel, soot-black pressure boiler, six calibration pylons, plumb gauges and rail cradle; Style/medium: polished hand-painted fantasy strategy town illustration; Composition/framing: complete building visible in elevated three-quarter isometric view, strong readable 256-pixel silhouette, generous transparent padding; Lighting/mood: hot furnace highlights against cool ceramic; Constraints: genuinely transparent background; original architecture; no surrounding scenery; no people; no text; no logo; no watermark; no franchise design; no cropped barrel, boiler, pylons, roof, or foundation",
    },
    {
        "prefix": "dreamwakeworks", "scenario_id": "wakeoracle-dreamwake-foganchor-works", "scenario_name": "Wakeoracle Dreamwake Foganchor Works",
        "town_id": "town_dreamwake_oracle_harbor", "town_name": "Dreamwake Oracle Harbor", "hero_id": "hero_veilmourn_morwen_wakeoracle", "faction_id": "faction_veilmourn",
        "enemy_faction_id": "faction_embercourt", "enemy_town_id": "town_cinderlock_bastion", "rare_id": "memory_salt", "rare_site_id": "site_memory_salt_pan",
        "unit_id": "unit_veilmourn_dreamwake_foganchor_colossi", "unit_name": "Foganchor Colossi", "role": "melee", "hp": 56, "attack": 14, "defense": 13, "damage": [12, 18], "speed": 5, "initiative": 7, "cost": {"gold": 810, "memory_salt": 1}, "school": "veil",
        "abilities": [
            {"id": "hookline", "name": "Foganchor Cast", "description": "Once per battle after the lines meet, the colossus casts its crescent anchor across a broken lane and chains the surviving target into contact.", "distance_one_multiplier": 0.0, "uses_per_battle": 1, "available_from_round": 2, "status_id": "status_rooted", "status_label": "Foganchor-Pinned", "duration_rounds": 1},
            {"id": "fog_screen", "name": "Drydock Sounding", "description": "Inside a natural fog bank, the colossus dissolves the edge of its armor and turns incoming force into a false harbor wake.", "required_battlefield_tags": ["fog_bank"], "incoming_damage_multiplier": 0.92},
        ],
        "building_id": "building_veilmourn_dreamwake_foganchor_slip", "building_name": "Dreamwake Foganchor Slip", "requires": ["building_veilmourn_mistgate_slip", "building_veilmourn_dreamwake_tideglass_oratory"], "building_cost": {"gold": 800, "ore": 1},
        "building_description": "A pearl-lit drydock binds crescent anchors and fog-sail mantles to Dreamwake's towering Foganchor Colossi.",
        "terrain": ["snow", "mire"], "seed": 49600, "encounters": ["encounter_beaconscribe_frostwharf_writ", "encounter_lockmaster_archive_seal", "encounter_railhead_lockward_auditors"],
        "conventional": [["unit_veilmourn_bellwake_oars", 16], ["unit_veilmourn_mourning_lanterns", 9], ["unit_veilmourn_maskglass_corsairs", 5], ["unit_veilmourn_undertow_harpooners", 3]],
        "unit_generated": "exec-8c3427ab-7d10-46e1-b9a8-c5387a93d3b2.png", "building_generated": "exec-568881b5-2e7d-4ac3-8756-cda18c6a076e.png",
        "unit_prompt": "Use case: stylized-concept; Asset type: production game unit master; Primary request: one original Dreamwake Foganchor Colossus, a spectral maritime breach guardian that drags enemies out of formation; Subject: towering armored drowned sentinel in navy, pearl and tarnished silver, immense crescent anchor on black chain, tideglass face mask, ragged fog-sail mantle, no visible gore; Style/medium: polished hand-painted fantasy strategy game illustration; Composition/framing: complete full figure, anchor and chain visible, three-quarter advancing pose, strong readable silhouette when reduced to 96 pixels, generous transparent padding; Lighting/mood: cold moonlit fog glow with restrained pearl highlights; Constraints: genuinely transparent background; original design; no scenery; no text; no logo; no watermark; no franchise design; no cropped limbs, anchor, chain, mask, or mantle",
        "building_prompt": "Use case: stylized-concept; Asset type: production town-building master; Primary request: the original Dreamwake Foganchor Slip, the town-exclusive harbor works that binds Foganchor Colossi; Subject: compact navy-roofed drydock, immense crescent anchor suspended on black chain, tideglass mask shrine, pearl-lit fog basins, silver capstan and ragged sail screens; Style/medium: polished hand-painted fantasy strategy town illustration; Composition/framing: complete building visible in elevated three-quarter isometric view, strong readable 256-pixel silhouette, generous transparent padding; Lighting/mood: cold moonlit fog glow with restrained pearl highlights; Constraints: genuinely transparent background; original architecture; no surrounding scenery; no people or creatures; no text; no logo; no watermark; no franchise design; no cropped anchor, chain, dock, roof, or foundation",
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
    path.write_text(text.replace(marker, ",\n" + ",\n".join(rendered) + marker, 1), encoding="utf-8")


def transparent_contain(source: Path, size: tuple[int, int], inset: int) -> Image.Image:
    with Image.open(source) as opened:
        image = opened.convert("RGBA")
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        raise RuntimeError(f"Source has no visible alpha: {source}")
    subject = image.crop(bbox)
    fitted = ImageOps.contain(subject, (size[0] - inset * 2, size[1] - inset * 2), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    canvas.alpha_composite(fitted, ((size[0] - fitted.width) // 2, (size[1] - fitted.height) // 2))
    return canvas


def render_sources() -> tuple[dict, dict]:
    UNIT_CURATED_ROOT.mkdir(parents=True, exist_ok=True)
    BUILDING_CURATED_ROOT.mkdir(parents=True, exist_ok=True)
    unit_manifest = {"schema_id": "generated_unit_source_provenance_v1", "generator_mode": "built_in_imagegen", "generated_at": "2026-08-31T22:18:31Z", "content_batch_id": SLICE_ID, "curation": "Each transparent master was visually reviewed as one twelve-asset contact sheet before deterministic 512x512 curation.", "items": []}
    building_manifest = {"schema_id": "generated_building_source_provenance_v1", "generator_mode": "built_in_imagegen", "generated_at": "2026-08-31T22:18:31Z", "content_batch_id": SLICE_ID, "curation": "Each transparent isometric master was visually reviewed as one twelve-asset contact sheet before deterministic 1254x1254 curation.", "items": []}
    for case in CASES:
        unit_source = UNIT_SOURCE_ROOT / f"{case['unit_id']}_source.png"
        unit_curated = UNIT_CURATED_ROOT / f"{case['unit_id']}.png"
        transparent_contain(unit_source, (512, 512), 12).save(unit_curated, optimize=True, compress_level=9)
        unit_manifest["items"].append({"unit_id": case["unit_id"], "source_path": f"res://{unit_source.relative_to(ROOT)}", "source_sha256": sha256(unit_source), "curated_path": f"res://{unit_curated.relative_to(ROOT)}", "curated_sha256": sha256(unit_curated), "original_generated_path": str(GENERATOR_ROOT / case["unit_generated"]), "prompt": case["unit_prompt"]})
        building_source = BUILDING_SOURCE_ROOT / f"{case['building_id']}_source.png"
        building_curated = BUILDING_CURATED_ROOT / f"{case['building_id']}.png"
        transparent_contain(building_source, (1254, 1254), 24).save(building_curated, optimize=True, compress_level=9)
        building_manifest["items"].append({"building_id": case["building_id"], "source_path": f"res://{building_source.relative_to(ROOT)}", "source_sha256": sha256(building_source), "curated_path": f"res://{building_curated.relative_to(ROOT)}", "curated_sha256": sha256(building_curated), "original_generated_path": str(GENERATOR_ROOT / case["building_generated"]), "prompt": case["building_prompt"]})
    (UNIT_SOURCE_ROOT / "manifest.json").write_text(json.dumps(unit_manifest, indent=2) + "\n", encoding="utf-8")
    (BUILDING_SOURCE_ROOT / "manifest.json").write_text(json.dumps(building_manifest, indent=2) + "\n", encoding="utf-8")
    return unit_manifest, building_manifest


def terrain_map(primary: str, secondary: str, seed: int) -> list[list[str]]:
    return [[secondary if ((x * 7 + y * 11 + seed) % 13) in (0, 1) else primary for x in range(14)] for y in range(9)]


def scenario_record(case: dict, building: dict) -> dict:
    prefix = case["prefix"]
    encounters = []
    for index, (encounter_id, coords) in enumerate(zip(case["encounters"], [(4, 1), (6, 6), (10, 2)]), start=1):
        encounters.append({"placement_id": f"{prefix}_front_{index}", "encounter_id": encounter_id, "x": coords[0], "y": coords[1], "difficulty": "medium" if index < 3 else "high", "combat_seed": case["seed"] + index, "prefer_identity_landmark": True})
    victories = [
        {"id": f"{prefix}_build_warworks", "label": f"Build {case['building_name']}", "type": "building_built_in_player_town", "placement_id": f"{prefix}_home", "building_id": case["building_id"]},
        {"id": f"{prefix}_reinforce_warwork", "label": f"Field at least two {case['unit_name']}", "type": "hero_army_meets_requirements", "hero_id": case["hero_id"], "requirements": [{"unit_id": case["unit_id"], "minimum_count": 2}]},
    ]
    victories.extend({"id": f"{prefix}_clear_front_{index}", "label": f"Break warworks proving front {index}", "type": "encounter_resolved", "placement_id": f"{prefix}_front_{index}"} for index in range(1, 4))
    return {
        "id": case["scenario_id"], "name": case["scenario_name"],
        "selection": {"summary": f"Commission {case['town_name']}'s heavy warwork, reinforce its exact company, and prove the production line across three hostile fronts.", "recommended_difficulty": "normal", "map_size_label": "Warworks Road (14x9)", "player_summary": f"The Marchland commander begins with four conventional stacks and one {case['unit_name']}, then must establish the town-exclusive production line.", "enemy_summary": "Three authored fronts, an enemy town, and a late counterstroke contest the warworks road.", "availability": {"campaign": False, "skirmish": True}},
        "map_size": {"width": 14, "height": 9}, "player_faction_id": case["faction_id"], "player_army_id": f"army_{prefix}_warworks_company", "hero_id": case["hero_id"],
        "starting_resources": {"gold": 6500, "wood": 10, "ore": 10, case["rare_id"]: 4}, "map": terrain_map(*case["terrain"], case["seed"]), "start": {"x": 1, "y": 4}, "hero_starts": [case["hero_id"]],
        "objectives": {"victory_text": f"{case['town_name']} has commissioned and field-proved {case['unit_name']}.", "defeat_text": "The home seat falls, hostile pressure closes the warworks road, or Day 18 ends the commission.", "victory": victories, "defeat": [
            {"id": f"{prefix}_lose_home", "label": f"Keep {case['town_name']} under player control", "type": "town_not_owned_by_player", "placement_id": f"{prefix}_home"},
            {"id": f"{prefix}_pressure", "label": "Keep hostile pressure below 24", "type": "enemy_pressure_at_least", "faction_id": case["enemy_faction_id"], "threshold": 24},
            {"id": f"{prefix}_deadline", "label": "Complete the warworks proving road before Day 18", "type": "day_at_least", "day": 18},
        ]},
        "script_hooks": [
            {"id": f"{prefix}_day_two_relief", "priority": 130, "conditions": [{"type": "day_at_least", "day": 2}, {"type": "town_owned_by_player", "placement_id": f"{prefix}_home"}], "effects": [{"type": "add_resources", "resources": {"gold": 500, "wood": 2, "ore": 2}}, {"type": "message", "text": f"{case['town_name']} sends foundry hands and proofing stores onto the warworks road."}]},
            {"id": f"{prefix}_front_one_recruits", "priority": 120, "conditions": [{"type": "encounter_resolved", "placement_id": f"{prefix}_front_1"}], "effects": [{"type": "town_add_recruits", "placement_id": f"{prefix}_home", "recruits": {case["unit_id"]: 1}}, {"type": "message", "text": f"Freed specialists add one {case['unit_name']} to the town muster."}]},
            {"id": f"{prefix}_warworks_commission", "priority": 110, "conditions": [{"type": "objective_met", "objective_id": f"{prefix}_build_warworks"}], "effects": [{"type": "add_resources", "resources": {case["rare_id"]: 1}}, {"type": "award_experience", "hero_id": case["hero_id"], "amount": 100}, {"type": "message", "text": f"The commissioned {case['building_name']} releases its first proofing reserve."}]},
            {"id": f"{prefix}_day_six_pressure", "priority": 100, "conditions": [{"type": "day_at_least", "day": 6}, {"type": "objective_not_met", "objective_id": f"{prefix}_reinforce_warwork"}], "effects": [{"type": "add_enemy_pressure", "faction_id": case["enemy_faction_id"], "amount": 2}, {"type": "message", "text": "Rival warwrights tighten the road while the heavy company remains understrength."}]},
            {"id": f"{prefix}_day_nine_counterstroke", "priority": 80, "conditions": [{"type": "day_at_least", "day": 9}, {"type": "town_owned_by_player", "placement_id": f"{prefix}_home"}, {"type": "objective_not_met", "objective_id": f"{prefix}_reinforce_warwork"}], "effects": [{"type": "spawn_encounter", "placement": {"placement_id": f"{prefix}_counterstroke", "encounter_id": case["encounters"][1], "x": 12, "y": 7, "difficulty": "scripted", "spawned_by_faction_id": case["enemy_faction_id"], "days_active": 0, "arrived": False, "goal_distance": 9999}}, {"type": "message", "text": "A rival proofing column crosses the outer road before the new warwork can be reinforced."}]},
        ],
        "towns": [
            {"placement_id": f"{prefix}_home", "town_id": case["town_id"], "x": 0, "y": 4, "owner": "player", "built_buildings": ["building_market_square"] + list(building.get("requires", []))},
            {"placement_id": f"{prefix}_enemy_town", "town_id": case["enemy_town_id"], "x": 13, "y": 4, "owner": "enemy"},
        ],
        "enemy_factions": [{"faction_id": case["enemy_faction_id"], "label": "Rival Warwrights", "pressure_per_day": 1, "pressure_per_enemy_town": 1, "raid_threshold": 9, "max_active_raids": 1, "raid_pillage_delay": 2, "raid_pillage": {"gold": 180}, "raid_encounter_ids": case["encounters"][:2], "spawn_points": [{"x": 13, "y": 1}, {"x": 13, "y": 7}], "siege_target_placement_id": f"{prefix}_home", "priority_target_placement_ids": [f"{prefix}_home", f"{prefix}_rare_1"]}],
        "resource_nodes": [
            {"placement_id": f"{prefix}_wood_1", "site_id": "site_wood_wagon", "x": 1, "y": 0}, {"placement_id": f"{prefix}_ore_1", "site_id": "site_ore_crates", "x": 3, "y": 0},
            {"placement_id": f"{prefix}_rare_1", "site_id": case["rare_site_id"], "x": 7, "y": 0}, {"placement_id": f"{prefix}_exchange", "site_id": "site_frontier_rare_exchange", "x": 11, "y": 0},
            {"placement_id": f"{prefix}_wood_2", "site_id": "site_wood_wagon", "x": 2, "y": 8}, {"placement_id": f"{prefix}_ore_2", "site_id": "site_ore_crates", "x": 7, "y": 8},
            {"placement_id": f"{prefix}_rare_2", "site_id": case["rare_site_id"], "x": 10, "y": 8}, {"placement_id": f"{prefix}_sanctum", "site_id": "site_roadside_sanctum", "x": 12, "y": 8},
        ],
        "artifact_nodes": [], "encounters": encounters,
        "content_status": "marchland_warworks_road_live", "content_batch_id": SLICE_ID, "scenario_family": "marchland_warworks_road", "deterministic_seed": case["seed"],
        "marchland_warworks": {"town_id": case["town_id"], "unit_id": case["unit_id"], "building_id": case["building_id"]},
    }


def main() -> None:
    render_sources()
    units = load("units.json")
    buildings = load("buildings.json")
    towns = load("towns.json")
    groups = load("army_groups.json")
    scenarios = load("scenarios.json")
    town_by_id = {row["id"]: row for row in towns["items"]}
    authored_buildings = []
    for case in CASES:
        unit = {"id": case["unit_id"], "name": case["unit_name"], "faction_id": case["faction_id"], "role": case["role"], "tier": 6, "hp": case["hp"], "attack": case["attack"], "defense": case["defense"], "min_damage": case["damage"][0], "max_damage": case["damage"][1], "speed": case["speed"], "initiative": case["initiative"], "retaliations": 1, "ranged": case["role"] == "ranged", "growth": 1, "cost": case["cost"], "content_status": "marchland_warwork_live", "content_batch_id": SLICE_ID, "abilities": case["abilities"], "spell_resistance_pct": 10, "control_resistance_pct": 8, "spell_school_resistance_pct": {case["school"]: 15}, "status_immunity_ids": []}
        if unit["ranged"]:
            unit["shots"] = case["shots"]
        upsert(units["items"], unit)
        building = {"id": case["building_id"], "name": case["building_name"], "category": "dwelling", "description": case["building_description"], "cost": case["building_cost"], "content_status": "marchland_warwork_live", "content_batch_id": SLICE_ID, "faction_id": case["faction_id"], "requires": case["requires"], "unlock_unit_id": case["unit_id"], "growth_bonus": {case["unit_id"]: 1}, "recruitment_discount_percent": {case["unit_id"]: 4}, "readiness_bonus": 3, "pressure_bonus": 1}
        upsert(buildings["items"], building)
        authored_buildings.append(building)
        for town in towns["items"]:
            town["buildable_building_ids"] = [value for value in town.get("buildable_building_ids", []) if value != case["building_id"]]
        town = town_by_id[case["town_id"]]
        if case["town_id"] == "town_woundroot_hearthgrove":
            insertion_index = town["buildable_building_ids"].index("building_thornwake_mycorrhizal_store")
            town["buildable_building_ids"].insert(insertion_index, case["building_id"])
        else:
            town["buildable_building_ids"].append(case["building_id"])
        seat = town.setdefault("marchland_seat", {})
        seat["warwork_unit_id"] = case["unit_id"]
        seat["warworks_building_id"] = case["building_id"]
        stacks = [{"unit_id": unit_id, "count": count} for unit_id, count in case["conventional"]]
        stacks.append({"unit_id": case["unit_id"], "count": 1})
        upsert(groups["items"], {"id": f"army_{case['prefix']}_warworks_company", "name": f"{case['town_name']} Warworks Company", "faction_id": case["faction_id"], "stacks": stacks, "content_status": "marchland_warworks_company_live", "content_batch_id": SLICE_ID})
        upsert(scenarios["items"], scenario_record(case, building))
    (CONTENT / "units.json").write_text(json.dumps(units, separators=(",", ":")) + "\n", encoding="utf-8")
    (CONTENT / "buildings.json").write_text(json.dumps(buildings, indent=2) + "\n", encoding="utf-8")
    (CONTENT / "towns.json").write_text(json.dumps(towns, indent=2) + "\n", encoding="utf-8")
    (CONTENT / "army_groups.json").write_text(dump_groups(groups), encoding="utf-8")
    scenarios["player_facing_active_scenario_count"] = len(scenarios["items"])
    (CONTENT / "scenarios.json").write_text(json.dumps(scenarios, separators=(",", ":")) + "\n", encoding="utf-8")
    print(json.dumps({"slice_id": SLICE_ID, "new_unit_count": 6, "new_building_count": 6, "new_scenario_count": 6, "direct_battle_count": 18, "unit_count": len(units["items"]), "building_count": len(buildings["items"]), "scenario_count": len(scenarios["items"]), "army_group_count": len(groups["items"])}, indent=2))


if __name__ == "__main__":
    main()
