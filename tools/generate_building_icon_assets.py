#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageOps


ROOT = Path(__file__).resolve().parents[1]
SOURCE_ROOT = ROOT / "art" / "towns" / "source" / "buildings" / "curated"
RUNTIME_ROOT = ROOT / "art" / "towns" / "runtime" / "buildings"
MANIFEST_PATH = ROOT / "content" / "building_art_manifest.json"
ICON_SIZE = (256, 256)
SOURCE_SIZE = (1254, 1254)
BUILDING_IDS = (
    "building_muster_yard",
    "building_bowyer_lodge",
    "building_embercourt_bargebow_slip",
    "building_embercourt_oath_pikehall",
    "building_embercourt_beacon_court",
    "building_embercourt_drake_sluice",
    "building_embercourt_charter_bastion",
    "building_mireclaw_blackbranch_den",
    "building_mireclaw_war_drum_circle",
    "building_mireclaw_floodtide_forge",
    "building_mireclaw_chainboom_ferry",
    "building_mireclaw_sporewake_shrine",
    "building_mireclaw_nightglass_dominion",
    "building_mireclaw_antler_pit",
    "building_sunvault_shard_yard",
    "building_sunvault_lens_gallery",
    "building_sunvault_mirror_forge",
    "building_sunvault_harmonic_cloister",
    "building_sunvault_zenith_observatory",
    "building_sunvault_aurora_spire",
    "building_sunvault_daybreak_matrix",
    "building_thornwake_seed_vault",
    "building_thornwake_bramble_toll",
    "building_thornwake_sporeglass_hothouse",
    "building_thornwake_barkmantle_run",
    "building_thornwake_pilgrim_orchard",
    "building_thornwake_graftworks",
    "building_thornwake_worldroot_gate",
    "building_brasshollow_ore_tithe_office",
    "building_brasshollow_rivet_kennels",
    "building_brasshollow_pavis_foundry",
    "building_brasshollow_boiler_cathedral",
    "building_brasshollow_pressure_rail",
    "building_brasshollow_crucible_dock",
    "building_brasshollow_titan_charter_hall",
    "building_veilmourn_bell_harbor",
    "building_veilmourn_ransom_exchange",
    "building_veilmourn_mirror_drydock",
    "building_veilmourn_harpoon_gantry",
    "building_veilmourn_obituary_vault",
    "building_veilmourn_mistgate_slip",
    "building_veilmourn_leviathan_sounding",
    "building_embercourt_lockhouse_tally",
    "building_mireclaw_reed_toll",
    "building_sunvault_lens_tithe",
    "building_thornwake_loam_ledger",
    "building_brasshollow_scalehouse",
    "building_veilmourn_salvage_ledger",
    "building_town_hall",
    "building_market_square",
    "building_wayfarers_hall",
    "building_stone_store",
    "building_lantern_archive",
    "building_starseer_annex",
    "building_mireclaw_silt_watch",
    "building_mireclaw_bog_oracle_nest",
    "building_mireclaw_boneboom_palisade",
    "building_mireclaw_oathmire_court",
    "building_blackbranch_den",
    "building_mire_pens",
    "building_reed_warren",
    "building_slingers_post",
    "building_rot_warren",
    "building_fenscale_pens",
    "building_gorefen_ring",
    "building_war_drum_circle",
    "building_floodtide_forge",
    "building_smugglers_flotilla",
    "building_nightglass_dominion",
    "building_watch_barracks",
    "building_beacon_range",
    "building_river_granary_exchange",
    "building_quartermasters_depot",
    "building_citadel_pikehall",
    "building_embercourt_granary_lock_exchange",
    "building_embercourt_tollstone_weir",
    "building_embercourt_beacon_writs",
    "building_embercourt_lantern_court",
    "building_embercourt_relief_quay",
    "building_embercourt_charter_flame",
    "building_signal_citadel",
    "building_charter_bastion",
    "building_shard_yard",
    "building_sunvault_relay_scribes",
    "building_prism_range",
    "building_mirror_forge",
    "building_lens_gallery",
    "building_duel_circle",
    "building_resonant_exchange",
    "building_harmonic_cloister",
    "building_aurora_spire",
    "building_daybreak_matrix",
    "building_sunvault_prism_oratory",
    "building_sunvault_halo_battery_yard",
    "building_sunvault_zenith_court",
    "building_brasshollow_clause_court",
    "building_brasshollow_heatwright_vestry",
    "building_brasshollow_gauge_arsenal",
    "building_brasshollow_debtworks_vault",
    "building_brasshollow_ledger_mint",
    "building_brasshollow_foreman_clausehouse",
    "building_brasshollow_caliper_sanctum",
    "building_brasshollow_redline_assembly_yard",
    "building_brasshollow_brassbound_directorate",
    "building_brasshollow_quenchwright_bay",
    "building_brasshollow_rail_tax_office",
    "building_brasshollow_warrant_engine_house",
    "building_thornwake_rootlaw_moot",
    "building_thornwake_pollen_litany",
    "building_thornwake_root_cairn_watch",
    "building_thornwake_mycorrhizal_store",
    "building_thornwake_sap_chandler_grove",
    "building_thornwake_rootroad_markers",
    "building_thornwake_rootweave_tithe",
    "building_thornwake_bramblewall_coppice",
    "building_thornwake_bastion_seed_conclave",
    "building_thornwake_bramble_marshal_moot",
    "building_thornwake_spore_oath_chantry",
    "building_thornwake_thornwarden_husk_yard",
    "building_thornwake_old_grove_accord",
    "building_thornwake_verdant_concord_seat",
    "building_veilmourn_bell_chain_watch",
    "building_veilmourn_black_sail_loft",
    "building_veilmourn_drowned_admiralty",
    "building_veilmourn_drowned_map_room",
    "building_veilmourn_fog_signal_buoys",
    "building_veilmourn_memory_anchor",
    "building_veilmourn_memory_rite_court",
    "building_veilmourn_mourner_pilot_guild",
    "building_veilmourn_salt_counting_house",
    "building_veilmourn_saltwake_factor",
    "building_veilmourn_tideglass_chapel",
    "building_veilmourn_wake_oratory",
    "building_embercourt_beaconline_charter_house",
    "building_mireclaw_fenbell_hunt_lodge",
    "building_sunvault_zenith_relay_hall",
    "building_thornwake_canopy_breach_grove",
    "building_brasshollow_redline_charter_bay",
    "building_veilmourn_wakeglass_chart_house",
    "building_thornwake_seedglass_cantory",
    "building_brasshollow_quenchbell_mortar_bay",
    "building_veilmourn_saltwake_eulogy_house",
    "building_embercourt_rainwrit_stormseal_treasury",
    "building_mireclaw_hollowreed_moonwax_ossuary",
    "building_sunvault_meridian_seven_facet_orrery",
    "building_thornwake_crownroot_heartseed_parliament",
    "building_brasshollow_blackbell_grand_assay_bell",
    "building_veilmourn_pale_sounding_last_memory_beacon",
    "building_embercourt_amberweir_sluiceguard_lock",
    "building_mireclaw_moonbite_votive_drum_court",
    "building_sunvault_splitprism_parallax_duel_hall",
    "building_thornwake_woundroot_hearthseed_nursery",
    "building_brasshollow_whitegauge_datum_railhouse",
    "building_veilmourn_dreamwake_tideglass_oratory",
    "building_embercourt_amberweir_counterweight_foundry",
    "building_mireclaw_moonbite_mirehorn_chain_pen",
    "building_sunvault_splitprism_heliograph_battery",
    "building_thornwake_woundroot_rootmaul_hollow",
    "building_brasshollow_whitegauge_breach_pressure_foundry",
    "building_veilmourn_dreamwake_foganchor_slip",
)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def render_icon(source_path: Path, runtime_path: Path) -> None:
    with Image.open(source_path) as opened:
        source = opened.convert("RGBA")
    if source.size != SOURCE_SIZE:
        raise ValueError(f"{source_path} must be {SOURCE_SIZE}, got {source.size}")
    alpha_bbox = source.getchannel("A").getbbox()
    if alpha_bbox is None:
        raise ValueError(f"{source_path} contains no visible pixels")
    subject = source.crop(alpha_bbox)
    fitted = ImageOps.contain(subject, (236, 236), Image.Resampling.LANCZOS)
    icon = Image.new("RGBA", ICON_SIZE, (0, 0, 0, 0))
    icon.alpha_composite(fitted, ((ICON_SIZE[0] - fitted.width) // 2, (ICON_SIZE[1] - fitted.height) // 2))
    runtime_path.parent.mkdir(parents=True, exist_ok=True)
    icon.save(runtime_path, format="PNG", optimize=False, compress_level=9)


def main() -> int:
    items = []
    for building_id in BUILDING_IDS:
        source_path = SOURCE_ROOT / f"{building_id}.png"
        runtime_path = RUNTIME_ROOT / f"{building_id}.png"
        if not source_path.is_file():
            raise FileNotFoundError(f"missing curated building source: {source_path}")
        render_icon(source_path, runtime_path)
        items.append({
            "id": building_id,
            "building_id": building_id,
            "source_kind": "curated_original_building",
            "source_path": "res://" + source_path.relative_to(ROOT).as_posix(),
            "source_sha256": sha256(source_path),
            "icon_path": "res://" + runtime_path.relative_to(ROOT).as_posix(),
            "icon_sha256": sha256(runtime_path),
        })
    manifest = {
        "schema_version": 1,
        "generator": "deterministic_building_icon_assets_v1",
        "source_size": {"width": SOURCE_SIZE[0], "height": SOURCE_SIZE[1]},
        "icon_size": {"width": ICON_SIZE[0], "height": ICON_SIZE[1]},
        "items": items,
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"generated {len(items)} building icons into {RUNTIME_ROOT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
