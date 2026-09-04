#!/usr/bin/env python3
"""Author the bounded Ninefold Riverwatch settlement-edge blocker composition."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCENARIOS_PATH = ROOT / "content" / "scenarios.json"
MAP_OBJECTS_PATH = ROOT / "content" / "map_objects.json"
TERRAIN_LAYERS_PATH = ROOT / "content" / "terrain_layers.json"
SCENARIO_ID = "ninefold-confluence"
BATCH_ID = "ux-overworld-town-proportion-and-environs-10236"
TOWN_PLACEMENT_ID = "ninefold_embercourt_survey_camp"
VISION_RADIUS = 5

# The cross-shaped authored road remains open. These three original grassland
# blockers occupy the west, north-east, and south-east edges of the initial
# town reveal instead of being hidden immediately behind fog.
PLACEMENTS = [
    ("west_settlement_fence", "object_low_fence_splinters", 19, 27),
    ("northeast_orchard_roots", "object_orchard_root_wall", 26, 24),
    ("southeast_fence", "object_low_fence_splinters", 26, 28),
]


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
    scenarios = item_index(scenarios_payload)
    object_defs = item_index(load(MAP_OBJECTS_PATH))
    layer_defs = item_index(load(TERRAIN_LAYERS_PATH))
    scenario = scenarios[SCENARIO_ID]
    width = int(scenario["map_size"]["width"])
    height = int(scenario["map_size"]["height"])
    town = next(
        record
        for record in scenario.get("towns", [])
        if record.get("placement_id") == TOWN_PLACEMENT_ID
    )
    town_x = int(town["x"])
    town_y = int(town["y"])
    roads = {
        (int(tile["x"]), int(tile["y"]))
        for road in layer_defs[SCENARIO_ID].get("roads", [])
        for tile in road.get("tiles", [])
    }
    occupied = {
        (int(record["x"]), int(record["y"]))
        for collection in ("towns", "resource_nodes", "artifact_nodes", "encounters")
        for record in scenario.get(collection, [])
    }
    retained_objects = [
        record
        for record in scenario.get("map_objects", [])
        if record.get("content_batch_id") != BATCH_ID
    ]
    blocked = {
        (int(tile["x"]), int(tile["y"]))
        for record in retained_objects
        for tile in record.get("body_tiles", [])
    }
    authored = []
    for local_id, object_id, x, y in PLACEMENTS:
        definition = object_defs[object_id]
        if str(definition.get("family", "")) != "blocker" or bool(definition.get("passable", True)):
            raise ValueError(f"{object_id} is not an authoritative blocker")
        origin_x, origin_y = footprint_origin(definition, x, y)
        body_tiles = [
            {"x": origin_x + int(tile["x"]), "y": origin_y + int(tile["y"])}
            for tile in definition.get("body_tiles", [])
        ]
        body = {(tile["x"], tile["y"]) for tile in body_tiles}
        if not body or any(px < 0 or py < 0 or px >= width or py >= height for px, py in body):
            raise ValueError(f"{local_id} has invalid body {sorted(body)}")
        conflicts = body & (roads | occupied | blocked)
        if conflicts:
            raise ValueError(f"{local_id} conflicts at {sorted(conflicts)}")
        if abs(x - town_x) + abs(y - town_y) > VISION_RADIUS:
            raise ValueError(f"{local_id} anchor is outside the normal town reveal")
        if min(abs(px - town_x) + abs(py - town_y) for px, py in body) > VISION_RADIUS:
            raise ValueError(f"{local_id} is outside the normal town reveal")
        terrain = {scenario["map"][py][px] for px, py in body}
        if not terrain <= {"grass", "dirt"}:
            raise ValueError(f"{local_id} has non-grassland terrain {sorted(terrain)}")
        authored.append(
            {
                "placement_id": f"town_environs_10236_{local_id}",
                "object_id": object_id,
                "kind": "decorative_obstacle",
                "object_family_id": "decorative_obstacle",
                "x": x,
                "y": y,
                "blocking_body": True,
                "body_tiles": body_tiles,
                "content_batch_id": BATCH_ID,
                "composition_role": "riverwatch_settlement_edge",
            }
        )
        blocked.update(body)
    scenario["map_objects"] = retained_objects + authored
    scenario["town_environs_support"] = {
        "model": "explicit_biome_settlement_edge_v1",
        "content_batch_id": BATCH_ID,
        "town_placement_id": TOWN_PLACEMENT_ID,
        "vision_radius": VISION_RADIUS,
        "authored_blocker_count": len(authored),
        "roads_preserved": True,
        "native_rmg_unchanged": True,
    }
    write_compact(SCENARIOS_PATH, scenarios_payload)


if __name__ == "__main__":
    main()
