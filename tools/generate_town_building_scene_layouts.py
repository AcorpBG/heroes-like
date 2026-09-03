#!/usr/bin/env python3
"""Build the checked-in explicit Town building scene-layout manifest.

The slot coordinates below are authored against the six 1600x900 village
panoramas. Runtime code consumes only the emitted manifest and never invents a
plot when content is missing.
"""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BUILDINGS_PATH = ROOT / "content" / "buildings.json"
TOWNS_PATH = ROOT / "content" / "towns.json"
OUTPUT_PATH = ROOT / "content" / "town_building_scene_layouts.json"


# [anchor_x, anchor_y, height_ratio]. Anchor is the painted structure's
# bottom-center in the 1600x900 source scene. Nonuniform terraces deliberately
# follow each faction scene instead of forming a generic grid or icon row.
FACTION_LAYOUTS = {
    "faction_embercourt": {
        "main_anchor": [0.695, 0.660, 0.245],
        "modulate": [0.88, 0.82, 0.76, 0.96],
        "slots": [
            [0.170, 0.640, 0.180], [0.840, 0.700, 0.170], [0.280, 0.610, 0.130],
            [0.910, 0.590, 0.120], [0.600, 0.560, 0.120], [0.720, 0.680, 0.140],
            [0.080, 0.700, 0.150], [0.240, 0.740, 0.150], [0.920, 0.470, 0.100],
            [0.910, 0.750, 0.150], [0.470, 0.720, 0.150], [0.590, 0.800, 0.160],
            [0.370, 0.820, 0.170], [0.800, 0.820, 0.170], [0.690, 0.880, 0.180],
            [0.200, 0.850, 0.180], [0.070, 0.880, 0.180], [0.480, 0.900, 0.190],
            [0.920, 0.890, 0.180], [0.310, 0.930, 0.190], [0.800, 0.940, 0.190],
            [0.120, 0.520, 0.110], [0.400, 0.570, 0.120], [0.520, 0.640, 0.130],
            [0.640, 0.930, 0.190], [0.940, 0.960, 0.180], [0.760, 0.560, 0.120],
        ],
    },
    "faction_mireclaw": {
        "main_anchor": [0.550, 0.660, 0.245],
        "modulate": [0.72, 0.75, 0.58, 0.94],
        "slots": [
            [0.330, 0.600, 0.160], [0.740, 0.600, 0.160], [0.200, 0.550, 0.120],
            [0.420, 0.520, 0.130], [0.670, 0.510, 0.120], [0.860, 0.540, 0.130],
            [0.120, 0.630, 0.140], [0.280, 0.690, 0.150], [0.480, 0.660, 0.150],
            [0.710, 0.700, 0.150], [0.890, 0.680, 0.150], [0.100, 0.780, 0.170],
            [0.260, 0.820, 0.180], [0.430, 0.780, 0.170], [0.600, 0.840, 0.180],
            [0.770, 0.800, 0.170], [0.910, 0.840, 0.180], [0.080, 0.930, 0.190],
            [0.240, 0.910, 0.190], [0.400, 0.950, 0.200], [0.580, 0.920, 0.190],
            [0.750, 0.960, 0.200], [0.900, 0.930, 0.190], [0.560, 0.570, 0.130],
            [0.330, 0.880, 0.180], [0.690, 0.890, 0.180], [0.790, 0.540, 0.120],
            [0.500, 0.880, 0.180],
        ],
    },
    "faction_sunvault": {
        "main_anchor": [0.360, 0.660, 0.245],
        "modulate": [0.92, 0.92, 0.86, 0.94],
        "slots": [
            [0.540, 0.640, 0.140], [0.790, 0.675, 0.140], [0.460, 0.560, 0.110],
            [0.580, 0.540, 0.110], [0.700, 0.550, 0.110], [0.820, 0.570, 0.110],
            [0.910, 0.540, 0.100], [0.180, 0.620, 0.130], [0.310, 0.670, 0.140],
            [0.500, 0.710, 0.140], [0.630, 0.690, 0.140], [0.760, 0.720, 0.140],
            [0.890, 0.690, 0.140], [0.140, 0.780, 0.150], [0.280, 0.820, 0.160],
            [0.430, 0.790, 0.150], [0.580, 0.840, 0.160], [0.730, 0.800, 0.150],
            [0.880, 0.840, 0.160], [0.120, 0.920, 0.170], [0.270, 0.940, 0.180],
            [0.430, 0.910, 0.170], [0.600, 0.950, 0.180], [0.770, 0.920, 0.170],
			[0.910, 0.940, 0.180], [0.400, 0.620, 0.130], [0.690, 0.890, 0.170],
            [0.530, 0.880, 0.170],
        ],
    },
    "faction_thornwake": {
        "main_anchor": [0.545, 0.660, 0.255],
        "modulate": [0.72, 0.82, 0.62, 0.94],
        "slots": [
            [0.310, 0.650, 0.160], [0.760, 0.660, 0.160], [0.260, 0.540, 0.110],
            [0.720, 0.540, 0.110], [0.840, 0.570, 0.120], [0.920, 0.540, 0.110],
            [0.120, 0.650, 0.140], [0.230, 0.700, 0.150], [0.400, 0.680, 0.150],
            [0.700, 0.700, 0.150], [0.840, 0.720, 0.150], [0.930, 0.680, 0.140],
            [0.110, 0.790, 0.160], [0.260, 0.830, 0.170], [0.410, 0.790, 0.160],
            [0.570, 0.850, 0.180], [0.720, 0.800, 0.160], [0.860, 0.840, 0.170],
			[0.940, 0.790, 0.160], [0.090, 0.930, 0.180], [0.240, 0.950, 0.190],
            [0.400, 0.920, 0.180], [0.560, 0.960, 0.190], [0.720, 0.920, 0.180],
            [0.880, 0.950, 0.190], [0.460, 0.570, 0.120], [0.630, 0.580, 0.120],
            [0.480, 0.880, 0.180], [0.650, 0.880, 0.180], [0.320, 0.880, 0.180],
        ],
    },
    "faction_brasshollow": {
        "main_anchor": [0.185, 0.750, 0.260],
        "modulate": [0.68, 0.62, 0.58, 0.94],
        "slots": [
            [0.390, 0.630, 0.160], [0.670, 0.650, 0.160], [0.500, 0.510, 0.110],
            [0.650, 0.540, 0.120], [0.790, 0.510, 0.110], [0.900, 0.550, 0.120],
            [0.280, 0.650, 0.140], [0.440, 0.690, 0.150], [0.580, 0.660, 0.140],
            [0.720, 0.700, 0.150], [0.850, 0.660, 0.140], [0.940, 0.710, 0.150],
            [0.300, 0.790, 0.160], [0.460, 0.830, 0.170], [0.620, 0.790, 0.160],
            [0.770, 0.850, 0.180], [0.900, 0.800, 0.160], [0.090, 0.890, 0.180],
            [0.250, 0.920, 0.180], [0.420, 0.950, 0.190], [0.590, 0.920, 0.180],
            [0.760, 0.960, 0.190], [0.920, 0.920, 0.180], [0.520, 0.590, 0.130],
            [0.750, 0.590, 0.130], [0.530, 0.880, 0.180], [0.850, 0.880, 0.180],
            [0.680, 0.880, 0.180],
        ],
    },
    "faction_veilmourn": {
        "main_anchor": [0.385, 0.670, 0.255],
        "modulate": [0.62, 0.70, 0.78, 0.92],
        "slots": [
            [0.580, 0.630, 0.160], [0.790, 0.660, 0.160], [0.500, 0.530, 0.110],
            [0.640, 0.560, 0.120], [0.760, 0.530, 0.110], [0.880, 0.570, 0.120],
            [0.120, 0.620, 0.140], [0.260, 0.670, 0.150], [0.500, 0.680, 0.140],
            [0.660, 0.700, 0.150], [0.800, 0.680, 0.140], [0.930, 0.710, 0.150],
            [0.120, 0.780, 0.160], [0.270, 0.820, 0.170], [0.440, 0.790, 0.160],
            [0.600, 0.840, 0.180], [0.760, 0.800, 0.160], [0.900, 0.840, 0.170],
            [0.100, 0.910, 0.180], [0.250, 0.950, 0.190], [0.420, 0.910, 0.180],
            [0.590, 0.960, 0.190], [0.760, 0.920, 0.180], [0.910, 0.950, 0.190],
            [0.460, 0.590, 0.130], [0.700, 0.590, 0.130], [0.680, 0.880, 0.180],
            [0.520, 0.880, 0.180],
        ],
    },
}


def load_items(path: Path) -> list[dict]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    items = payload.get("items", [])
    if not isinstance(items, list):
        raise ValueError(f"{path} does not contain an items array")
    return items


def plot_root(building_id: str, catalog: set[str], buildings: dict[str, dict]) -> str:
    current = building_id
    visited: set[str] = set()
    while current and current not in visited:
        visited.add(current)
        predecessor = str(buildings.get(current, {}).get("upgrade_from", "")).strip()
        if not predecessor or predecessor not in catalog:
            break
        current = predecessor
    return current or building_id


def main() -> None:
    buildings = {item["id"]: item for item in load_items(BUILDINGS_PATH)}
    towns = load_items(TOWNS_PATH)
    faction_catalogs: dict[str, list[str]] = {faction_id: [] for faction_id in FACTION_LAYOUTS}
    for town in towns:
        faction_id = str(town.get("faction_id", ""))
        if faction_id not in faction_catalogs:
            continue
        for key in ("starting_building_ids", "buildable_building_ids"):
            for building_id in town.get(key, []):
                if building_id not in faction_catalogs[faction_id]:
                    faction_catalogs[faction_id].append(building_id)

    factions: dict[str, dict] = {}
    for faction_id, layout in FACTION_LAYOUTS.items():
        catalog_ids = faction_catalogs[faction_id]
        catalog_set = set(catalog_ids)
        groups: dict[str, list[str]] = {}
        root_order: list[str] = []
        for building_id in catalog_ids:
            if building_id not in buildings:
                raise ValueError(f"Unknown building {building_id} in {faction_id}")
            root_id = plot_root(building_id, catalog_set, buildings)
            if root_id not in groups:
                groups[root_id] = []
                root_order.append(root_id)
            groups[root_id].append(building_id)

        non_main_roots = [root_id for root_id in root_order if root_id != "building_town_hall"]
        slots = layout["slots"]
        if len(non_main_roots) > len(slots):
            raise ValueError(f"{faction_id} needs {len(non_main_roots)} slots, has {len(slots)}")

        plots = [{
            "plot_id": "building_town_hall",
            "building_ids": groups.get("building_town_hall", ["building_town_hall"]),
            "anchor": layout["main_anchor"][:2],
            "height_ratio": layout["main_anchor"][2],
            "embedded_in_base": True,
        }]
        for index, root_id in enumerate(non_main_roots):
            x, y, height_ratio = slots[index]
            plots.append({
                "plot_id": root_id,
                "building_ids": groups[root_id],
                "anchor": [x, y],
                "height_ratio": height_ratio,
                "embedded_in_base": False,
            })
        factions[faction_id] = {
            "base_stage": "village",
            "source_size": [1600, 900],
            "modulate": layout["modulate"],
            "plots": plots,
        }

    payload = {
        "schema_id": "town_integrated_building_scene_layout_v1",
        "source_art_manifest": "res://content/building_art_manifest.json",
        "development_scene_manifest": "res://content/town_development_scene_manifest.json",
        "placement_model": "explicit_faction_ground_anchor_depth_and_perspective",
        "missing_mapping_policy": "validation_failure_no_runtime_generated_plot",
        "factions": factions,
    }
    OUTPUT_PATH.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
