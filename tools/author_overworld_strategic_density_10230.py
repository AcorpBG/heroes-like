#!/usr/bin/env python3
"""Author explicit route rewards and raster-backed scenery for sparse maps."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCENARIOS_PATH = ROOT / "content" / "scenarios.json"
MAP_OBJECTS_PATH = ROOT / "content" / "map_objects.json"
TERRAIN_LAYERS_PATH = ROOT / "content" / "terrain_layers.json"


PATCHES = {
    "ninefold-confluence": {
        "pickups": [
            ("northwest_writ", "site_road_writ_purse", 4, 10),
            ("frostwood_bundle", "site_split_wood_pile", 4, 24),
            ("snowline_cache", "site_waystone_cache", 4, 38),
            ("ice_road_hod", "site_quarry_chip_hod", 4, 50),
            ("ridge_writ", "site_road_writ_purse", 10, 22),
            ("ridge_planks", "site_millroad_plank_stack", 10, 34),
            ("switchback_cache", "site_waystone_cache", 10, 44),
            ("southern_scree_hod", "site_quarry_chip_hod", 10, 58),
            ("orchard_writ", "site_road_writ_purse", 18, 10),
            ("greenway_wood", "site_split_wood_pile", 20, 20),
            ("survey_payroll", "site_payroll_casket", 18, 30),
            ("rootroad_planks", "site_millroad_plank_stack", 20, 46),
            ("southern_grove_cache", "site_waystone_cache", 20, 58),
            ("west_survey_wood", "site_split_wood_pile", 14, 22),
            ("survey_lane_writ", "site_road_writ_purse", 19, 24),
            ("east_greenway_cache", "site_waystone_cache", 26, 20),
            ("south_greenway_planks", "site_millroad_plank_stack", 26, 29),
            ("north_measure_hod", "site_quarry_chip_hod", 34, 8),
            ("north_badland_writ", "site_road_writ_purse", 33, 20),
            ("dirtroad_writ", "site_road_writ_purse", 38, 16),
            ("central_payroll", "site_payroll_casket", 34, 30),
            ("south_badland_hod", "site_quarry_chip_hod", 40, 32),
            ("badland_planks", "site_millroad_plank_stack", 40, 38),
            ("foundry_hod", "site_quarry_chip_hod", 34, 54),
            ("southern_writ", "site_road_writ_purse", 40, 60),
            ("ashroad_cache", "site_waystone_cache", 46, 6),
            ("cinder_hod", "site_quarry_chip_hod", 46, 22),
            ("furnace_payroll", "site_payroll_casket", 46, 32),
            ("slagroad_writ", "site_road_writ_purse", 46, 44),
            ("southern_ash_cache", "site_waystone_cache", 44, 60),
            ("underway_payroll", "site_payroll_casket", 61, 3),
            ("chalkroad_writ", "site_road_writ_purse", 60, 16),
            ("deep_ore_hod", "site_quarry_chip_hod", 58, 28),
            ("underrail_cache", "site_waystone_cache", 60, 38),
            ("deep_plank_stack", "site_millroad_plank_stack", 58, 46),
            ("southern_underway_payroll", "site_payroll_casket", 60, 60),
        ],
        "blockers": [
            ("north_ice_wall", "object_whitewood_trunk_wall", 4, 16),
            ("frost_pool_wall", "object_frost_frozen_pool_lip", 4, 32),
            ("south_ice_wall", "object_snow_buried_stone_bar", 4, 46),
            ("north_ridge_wall", "object_slate_switchback_teeth", 10, 10),
            ("ridge_scree_wall", "object_highland_ridge_teeth_line", 10, 31),
            ("south_ridge_wall", "object_switchback_rockfall", 10, 50),
            ("north_orchard_wall", "object_orchard_root_wall", 19, 6),
            ("green_breach_wall", "object_grass_millstone_breach_field", 19, 16),
            ("west_survey_fence", "object_low_fence_splinters", 16, 25),
            ("north_survey_root_wall", "object_orchard_root_wall", 27, 22),
            ("south_survey_cutbank", "object_floodplain_cut_bank", 26, 32),
            ("survey_root_wall", "object_grass_old_weir_shadow", 18, 36),
            ("southern_green_wall", "object_floodplain_cut_bank", 20, 54),
            ("north_badland_wall", "object_badland_redstone_escarpment", 34, 6),
            ("measure_gully_wall", "object_badland_dry_gully_fan", 35, 22),
            ("survey_badland_gully", "object_badland_dry_gully_fan", 34, 26),
            ("central_badland_wall", "object_highland_badland_ravine_lip", 35, 34),
            ("southern_badland_wall", "object_redstone_fin_wall", 34, 58),
            ("north_ash_wall", "object_ash_lava_slag_wall", 46, 14),
            ("furnace_scree_wall", "object_ash_furnace_scree_shelf", 46, 28),
            ("slag_breach_wall", "object_smoke_black_ruin_wall", 46, 41),
            ("south_ash_wall", "object_cooling_lava_rope_wall", 44, 56),
            ("north_underway_wall", "object_underway_brasspipe_cavern_wall", 60, 10),
            ("deep_quarry_wall", "object_underway_quarry_spoil_curtain", 60, 24),
            ("rail_wall", "object_underway_pressure_rail_embankment", 60, 34),
            ("south_underway_wall", "object_undergate_stone_plug", 58, 57),
        ],
    },
    "third-hearths-confluence": {
        "pickups": [
            ("west_wood", "site_split_wood_pile", 4, 4),
            ("west_writ", "site_road_writ_purse", 4, 16),
            ("forest_cache", "site_waystone_cache", 10, 7),
            ("forest_planks", "site_millroad_plank_stack", 10, 12),
            ("ridge_hod", "site_quarry_chip_hod", 16, 9),
            ("ridge_payroll", "site_payroll_casket", 16, 16),
            ("east_writ", "site_road_writ_purse", 22, 7),
            ("east_planks", "site_millroad_plank_stack", 22, 12),
            ("mire_cache", "site_waystone_cache", 30, 4),
            ("mire_wood", "site_split_wood_pile", 30, 14),
        ],
        "blockers": [
            ("west_orchard_wall", "object_orchard_root_wall", 4, 6),
            ("west_cutbank", "object_floodplain_cut_bank", 4, 14),
            ("north_forest_wall", "object_forest_elder_root_overhang", 10, 5),
            ("south_forest_wall", "object_forest_great_bough_deadfall", 10, 16),
            ("north_ridge_wall", "object_highland_ridge_teeth_line", 16, 5),
            ("south_ridge_wall", "object_switchback_rockfall", 16, 14),
            ("north_badland_wall", "object_badland_redstone_escarpment", 22, 5),
            ("south_badland_wall", "object_badland_dry_gully_fan", 22, 16),
            ("north_mire_wall", "object_mire_drowned_cypress_knee_wall", 30, 8),
            ("south_mire_wall", "object_reed_island_choke", 31, 19),
        ],
    },
}


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def write_compact(path: Path, payload: dict) -> None:
    path.write_text(json.dumps(payload, separators=(",", ":")) + "\n", encoding="utf-8")


def item_index(payload: dict) -> dict[str, dict]:
    return {str(item["id"]): item for item in payload.get("items", [])}


def footprint_origin(definition: dict, x: int, y: int) -> tuple[int, int]:
    footprint = definition.get("footprint", {})
    width = max(1, int(footprint.get("width", 1)))
    height = max(1, int(footprint.get("height", 1)))
    anchor = str(footprint.get("anchor", "bottom_center"))
    if anchor == "top_left":
        return x, y
    if anchor == "center":
        return x - width // 2, y - height // 2
    if anchor == "bottom_left":
        return x, y - height + 1
    if anchor == "bottom_right":
        return x - width + 1, y - height + 1
    return x - width // 2, y - height + 1


def main() -> None:
    scenarios_payload = load(SCENARIOS_PATH)
    object_defs = item_index(load(MAP_OBJECTS_PATH))
    layer_defs = item_index(load(TERRAIN_LAYERS_PATH))
    scenarios = item_index(scenarios_payload)

    for scenario_id, patch in PATCHES.items():
        scenario = scenarios[scenario_id]
        width = int(scenario["map_size"]["width"])
        height = int(scenario["map_size"]["height"])
        roads = {
            (int(tile["x"]), int(tile["y"]))
            for road in layer_defs.get(scenario_id, {}).get("roads", [])
            for tile in road.get("tiles", [])
        }
        occupied = {
            (int(record["x"]), int(record["y"]))
            for collection in ("towns", "resource_nodes", "artifact_nodes", "encounters")
            for record in scenario.get(collection, [])
            if record.get("content_batch_id") != "overworld-strategic-density-and-route-occupancy-10230"
        }

        authored_objects = []
        blocked = set()
        for local_id, object_id, x, y in patch["blockers"]:
            definition = object_defs[object_id]
            origin_x, origin_y = footprint_origin(definition, x, y)
            body_tiles = [
                {
                    "x": origin_x + int(tile["x"]),
                    "y": origin_y + int(tile["y"]),
                }
                for tile in definition.get("body_tiles", [])
            ]
            body = {(tile["x"], tile["y"]) for tile in body_tiles}
            if not body or any(px < 0 or py < 0 or px >= width or py >= height for px, py in body):
                raise ValueError(f"{scenario_id}:{local_id} has invalid body {sorted(body)}")
            conflicts = body & (occupied | roads | blocked)
            if conflicts:
                raise ValueError(f"{scenario_id}:{local_id} conflicts at {sorted(conflicts)}")
            authored_objects.append(
                {
                    "placement_id": f"density_10230_{local_id}",
                    "object_id": object_id,
                    "kind": "decorative_obstacle",
                    "object_family_id": "decorative_obstacle",
                    "x": x,
                    "y": y,
                    "blocking_body": True,
                    "body_tiles": body_tiles,
                    "content_batch_id": "overworld-strategic-density-and-route-occupancy-10230",
                }
            )
            blocked.update(body)

        authored_pickups = []
        pickup_cells = set()
        for local_id, site_id, x, y in patch["pickups"]:
            cell = (x, y)
            if cell in occupied or cell in blocked or cell in pickup_cells:
                raise ValueError(f"{scenario_id}:{local_id} conflicts at {cell}")
            if x < 0 or y < 0 or x >= width or y >= height:
                raise ValueError(f"{scenario_id}:{local_id} is out of bounds")
            authored_pickups.append(
                {
                    "placement_id": f"density_10230_{local_id}",
                    "site_id": site_id,
                    "x": x,
                    "y": y,
                    "content_batch_id": "overworld-strategic-density-and-route-occupancy-10230",
                }
            )
            pickup_cells.add(cell)

        scenario["map_objects"] = [
            record
            for record in scenario.get("map_objects", [])
            if record.get("content_batch_id") != "overworld-strategic-density-and-route-occupancy-10230"
        ] + authored_objects
        scenario["resource_nodes"] = [
            record
            for record in scenario.get("resource_nodes", [])
            if record.get("content_batch_id") != "overworld-strategic-density-and-route-occupancy-10230"
        ] + authored_pickups
        scenario["strategic_density_support"] = {
            "model": "explicit_biome_scenery_and_low_value_route_rewards_v1",
            "content_batch_id": "overworld-strategic-density-and-route-occupancy-10230",
            "authored_blocker_count": len(authored_objects),
            "authored_pickup_count": len(authored_pickups),
            "native_rmg_unchanged": True,
        }

    write_compact(SCENARIOS_PATH, scenarios_payload)


if __name__ == "__main__":
    main()
