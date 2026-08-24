#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE_ROOT = ROOT / "art" / "magic" / "source" / "spells" / "curated"
RUNTIME_ROOT = ROOT / "art" / "magic" / "runtime" / "spells"
MANIFEST_PATH = ROOT / "content" / "spell_icons.json"
SOURCE_SIZE = (1254, 1254)
ICON_SIZE = (128, 128)
SPELLS = (
    ("spell_bulwark_litany", "beacon"),
    ("spell_coal_rain", "mire"),
    ("spell_sunlance_arc", "lens"),
    ("spell_briar_bind", "root"),
    ("spell_cinder_burst", "furnace"),
    ("spell_fogwake_step", "veil"),
    ("spell_old_measure_compass_boundary_06", "old_measure"),
    ("spell_stone_veil", "furnace"),
    ("spell_quickmarch_hymn", "beacon"),
    ("spell_relay_drum", "mire"),
    ("spell_resonant_chorus", "lens"),
    ("spell_bloodwake_drum", "mire"),
    ("spell_trailglyph", "beacon"),
    ("spell_prism_bastion", "lens"),
    ("spell_lantern_phalanx", "beacon"),
    ("spell_survey_chain", "old_measure"),
    ("spell_graft_mend", "root"),
    ("spell_heat_rite", "furnace"),
    ("spell_obituary_mark", "veil"),
    ("spell_pressure_clause", "furnace"),
    ("spell_beacon_path", "beacon"),
    ("spell_waystride", "beacon"),
    ("spell_fogline_drift", "veil"),
    ("spell_rootway_tangle", "root"),
    ("spell_beacon_column_charge_11", "beacon"),
    ("spell_beacon_lantern_oath_17", "beacon"),
    ("spell_beacon_roadward_charge_23", "beacon"),
    ("spell_beacon_bell_ward_09", "beacon"),
    ("spell_beacon_bell_lance_25", "beacon"),
    ("spell_mire_bog_drum_18", "mire"),
    ("spell_mire_brine_fenlight_24", "mire"),
    ("spell_mire_leech_snare_10", "mire"),
    ("spell_furnace_foundry_bellows_11", "furnace"),
    ("spell_furnace_brass_bellows_23", "furnace"),
    ("spell_furnace_ash_mantle_09", "furnace"),
    ("spell_furnace_ash_rail_25", "furnace"),
    ("spell_root_canopy_thorn_22", "root"),
    ("spell_root_bark_bark_08", "root"),
    ("spell_root_bark_rootway_24", "root"),
    ("spell_root_bloom_bark_20", "root"),
    ("spell_veil_mourning_mark_04", "veil"),
    ("spell_veil_mist_shroud_10", "veil"),
    ("spell_veil_moon_drift_12", "veil"),
    ("spell_veil_moon_mark_28", "veil"),
    ("spell_old_measure_marker_tally_08", "old_measure"),
    ("spell_old_measure_count_survey_14", "old_measure"),
    ("spell_old_measure_compass_correction_22", "old_measure"),
    ("spell_old_measure_count_boundary_30", "old_measure"),
    ("spell_lens_array_ray_06", "lens"),
    ("spell_lens_array_chorus_22", "lens"),
    ("spell_lens_glass_facet_08", "lens"),
    ("spell_lens_focus_array_14", "lens"),
    ("spell_lens_aurora_chorus_10", "lens"),
    ("spell_lens_mirror_prism_04", "lens"),
    ("spell_lens_starlens_survey_12", "lens"),
    ("spell_lens_crown_prism_16", "lens"),
    ("spell_lens_halo_ray_18", "lens"),
    ("spell_lens_mirror_facet_20", "lens"),
    ("spell_lens_glass_survey_24", "lens"),
    ("spell_lens_aurora_array_26", "lens"),
    ("spell_lens_starlens_prism_28", "lens"),
)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def render_icon(source_path: Path, runtime_path: Path) -> None:
    with Image.open(source_path) as opened:
        source = opened.convert("RGBA")
    if source.size != SOURCE_SIZE:
        raise ValueError(f"{source_path} must be {SOURCE_SIZE}, got {source.size}")
    icon = source.resize(ICON_SIZE, Image.Resampling.LANCZOS)
    runtime_path.parent.mkdir(parents=True, exist_ok=True)
    icon.save(runtime_path, format="PNG", optimize=False, compress_level=9)


def main() -> int:
    items = []
    for spell_id, school_id in SPELLS:
        source_path = SOURCE_ROOT / f"{spell_id}.png"
        runtime_path = RUNTIME_ROOT / f"{spell_id}.png"
        if not source_path.is_file():
            raise FileNotFoundError(f"missing curated spell source: {source_path}")
        render_icon(source_path, runtime_path)
        items.append({
            "id": spell_id,
            "spell_id": spell_id,
            "school_id": school_id,
            "icon_id": f"spell_signature_icon_{spell_id.removeprefix('spell_')}",
            "source_kind": "curated_original_spell",
            "source_path": "res://" + source_path.relative_to(ROOT).as_posix(),
            "source_sha256": sha256(source_path),
            "icon_path": "res://" + runtime_path.relative_to(ROOT).as_posix(),
            "icon_sha256": sha256(runtime_path),
        })
    manifest = {
        "schema_version": 1,
        "generator": "deterministic_signature_spell_icon_assets_v1",
        "source_size": {"width": SOURCE_SIZE[0], "height": SOURCE_SIZE[1]},
        "icon_size": {"width": ICON_SIZE[0], "height": ICON_SIZE[1]},
        "items": items,
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"generated {len(items)} signature spell icons into {RUNTIME_ROOT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
