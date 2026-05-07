#!/usr/bin/env python3
"""Fast RMG evidence/package audit without starting Godot.

This tool parses HoMM3 `.h3m` owner evidence and native `.amap` JSON packages
directly. It is intended for the tight RMG audit loop; Godot report scenes
should remain integration smokes for generation, package adoption, and editor
loading.
"""

from __future__ import annotations

import argparse
import gzip
import json
from collections import Counter, deque
from pathlib import Path
from typing import Any


HOMM3_RE_OBJECT_METADATA = Path(
    "/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/object-metadata-by-type.json"
)
OBJECT_TEMPLATE_RECORD_BYTES_AFTER_NAME = 42
H3M_TILE_BYTES_PER_CELL = 7
OBJECT_INSTANCE_TAIL_PARSE_MISSING_COUNT_TOLERANCE = 32
OBJECT_INSTANCE_TAIL_PARSE_BYTE_TOLERANCE = 64
H3M_BLOCKING_TERRAIN_TYPE_IDS = {8, 9}
DECORATION_TYPE_IDS = {118, 119, 120, 134, 135, 136, 137, 147, 150, 155, 199, 207, 210}
GUARD_TYPE_IDS = {54, 71}
TOWN_TYPE_IDS = {98}
RESOURCE_REWARD_TYPE_IDS = {5, 53, 79, 83, 88, 89, 90, 93, 101}
REWARD_KINDS = {"mine", "neutral_dwelling", "resource_site", "reward_reference"}


def u32(data: bytes, offset: int) -> int:
    if offset < 0 or offset + 4 > len(data):
        return 0
    return int.from_bytes(data[offset : offset + 4], "little", signed=False)


def point_key(x: int, y: int) -> str:
    return f"{x},{y}"


def point_from_key(key: str) -> tuple[int, int]:
    left, right = key.split(",", 1)
    return int(left), int(right)


def load_bytes(path: Path) -> bytes:
    data = path.read_bytes()
    if data.startswith(b"\x1f\x8b"):
        return gzip.decompress(data)
    return data


def load_object_metadata() -> dict[int, str]:
    if not HOMM3_RE_OBJECT_METADATA.exists():
        return {}
    parsed = json.loads(HOMM3_RE_OBJECT_METADATA.read_text())
    return {int(entry.get("type_id", -1)): str(entry.get("type_name", "")) for entry in parsed.get("entries", [])}


def h3m_category(record: dict[str, Any]) -> str:
    type_id = int(record.get("type_id", -1))
    type_name = str(record.get("type_name", "")).lower()
    if type_id in DECORATION_TYPE_IDS:
        return "decoration"
    if type_id in GUARD_TYPE_IDS or "monster" in type_name:
        return "guard"
    if type_id in TOWN_TYPE_IDS:
        return "town"
    if (
        type_id in RESOURCE_REWARD_TYPE_IDS
        or "resource" in type_name
        or "mine" in type_name
        or "artifact" in type_name
        or "shrine" in type_name
    ):
        return "reward"
    return "object"


def find_object_definition_offsets(data: bytes) -> list[int]:
    result: list[int] = []
    for offset in range(max(0, len(data) - 32)):
        count = u32(data, offset)
        if count < 10 or count > 2000:
            continue
        name_len = u32(data, offset + 4)
        if name_len < 4 or name_len > 32:
            continue
        name = data[offset + 8 : offset + 8 + name_len].decode("ascii", "ignore")
        if name.lower().endswith(".def"):
            result.append(offset)
    return result


def parse_h3m_object_templates(data: bytes, offset: int, metadata: dict[int, str]) -> dict[str, Any]:
    count = u32(data, offset)
    if count <= 0 or count > 2000:
        return {"status": "not_attempted", "error": "invalid_object_definition_count", "count": count}
    pos = offset + 4
    templates: list[dict[str, Any]] = []
    for index in range(count):
        name_len = u32(data, pos)
        pos += 4
        if name_len <= 0 or name_len > 128 or pos + name_len + OBJECT_TEMPLATE_RECORD_BYTES_AFTER_NAME > len(data):
            return {"status": "not_attempted", "error": "invalid_object_definition_name_length", "index": index}
        def_name = data[pos : pos + name_len].decode("ascii", "ignore")
        pos += name_len
        rest_offset = pos
        pos += OBJECT_TEMPLATE_RECORD_BYTES_AFTER_NAME
        type_id = u32(data, rest_offset + 16)
        templates.append(
            {
                "template_index": index,
                "def_name": def_name,
                "passability_mask": data[rest_offset : rest_offset + 6],
                "action_mask": data[rest_offset + 6 : rest_offset + 12],
                "type_id": type_id,
                "type_name": metadata.get(type_id, f"type_{type_id}"),
                "subtype": u32(data, rest_offset + 20),
            }
        )
    return {"status": "parsed", "template_count": count, "templates": templates, "next_offset": pos}


def is_h3m_object_instance_start(data: bytes, pos: int, template_count: int, width: int, level_count: int) -> bool:
    if pos < 0 or pos + 12 > len(data):
        return False
    x, y, z = data[pos], data[pos + 1], data[pos + 2]
    template_index = u32(data, pos + 3)
    if x >= width or y >= width or z >= level_count or template_index >= template_count:
        return False
    return all(data[pos + 7 + index] == 0 for index in range(5))


def parse_h3m_object_instances(data: bytes, offset: int, templates: list[dict[str, Any]], width: int, level_count: int) -> dict[str, Any]:
    count = u32(data, offset)
    if count <= 0 or count > 12000:
        return {"status": "not_attempted", "error": "invalid_object_instance_count", "count": count}
    pos = offset + 4
    records: list[dict[str, Any]] = []
    for index in range(count):
        if not is_h3m_object_instance_start(data, pos, len(templates), width, level_count):
            return {"status": "not_attempted", "error": "object_instance_parse_failed", "index": index, "offset": pos}
        template_index = u32(data, pos + 3)
        record = dict(templates[template_index])
        record.update({"object_index": index, "x": data[pos], "y": data[pos + 1], "level": data[pos + 2]})
        records.append(record)
        next_min = pos + 12
        if index == count - 1:
            pos = next_min
            break
        found = -1
        for extra in range(4096):
            candidate = next_min + extra
            if is_h3m_object_instance_start(data, candidate, len(templates), width, level_count):
                found = candidate
                break
        if found < 0:
            missing_count = count - len(records)
            tail_bytes = len(data) - next_min
            if (
                missing_count > 0
                and missing_count <= OBJECT_INSTANCE_TAIL_PARSE_MISSING_COUNT_TOLERANCE
                and 0 <= tail_bytes <= OBJECT_INSTANCE_TAIL_PARSE_BYTE_TOLERANCE
            ):
                return {
                    "status": "parsed",
                    "records": records,
                    "declared_object_count": count,
                    "parsed_object_count": len(records),
                    "missing_object_instance_count": missing_count,
                    "tail_bytes": tail_bytes,
                    "parse_quality": "tail_count_mismatch",
                }
            return {"status": "not_attempted", "error": "next_object_instance_not_found", "index": index, "offset": pos}
        pos = found
    return {
        "status": "parsed",
        "records": records,
        "declared_object_count": count,
        "parsed_object_count": len(records),
        "missing_object_instance_count": 0,
        "tail_bytes": len(data) - pos,
        "parse_quality": "complete",
    }


def mask_points(record: dict[str, Any], action_mask: bool, width: int, height: int) -> list[dict[str, int]]:
    mask = record.get("action_mask" if action_mask else "passability_mask", b"")
    if len(mask) < 6:
        return []
    points: list[dict[str, int]] = []
    for row in range(6):
        byte = mask[row]
        for col in range(8):
            bit_set = ((byte >> col) & 1) == 1
            include = bit_set if action_mask else not bit_set
            if not include:
                continue
            x = int(record.get("x", 0)) - (7 - col)
            y = int(record.get("y", 0)) - (5 - row)
            if 0 <= x < width and 0 <= y < height:
                points.append({"x": x, "y": y})
    return points


def guard_control_points(record: dict[str, Any], width: int, height: int) -> list[dict[str, int]]:
    action_points = mask_points(record, True, width, height) or [{"x": int(record.get("x", 0)), "y": int(record.get("y", 0))}]
    seen: set[str] = set()
    points: list[dict[str, int]] = []
    for point in action_points:
        for dy in range(-1, 2):
            for dx in range(-1, 2):
                x = int(point["x"]) + dx
                y = int(point["y"]) + dy
                key = point_key(x, y)
                if 0 <= x < width and 0 <= y < height and key not in seen:
                    seen.add(key)
                    points.append({"x": x, "y": y})
    return points


def component_sizes(lookup: set[str], width: int) -> list[int]:
    remaining = set(lookup)
    result: list[int] = []
    dirs = [(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, 1), (1, -1), (-1, -1)]
    while remaining:
        start = remaining.pop()
        queue = deque([point_from_key(start)])
        size = 0
        while queue:
            x, y = queue.popleft()
            size += 1
            for dx, dy in dirs:
                nx, ny = x + dx, y + dy
                key = point_key(nx, ny)
                if 0 <= nx < width and 0 <= ny < width and key in remaining:
                    remaining.remove(key)
                    queue.append((nx, ny))
        result.append(size)
    return sorted(result, reverse=True)


def h3m_road_lookup(data: bytes, tile_offset: int, width: int, level: int) -> set[str]:
    lookup: set[str] = set()
    level_offset = tile_offset + level * width * width * H3M_TILE_BYTES_PER_CELL
    for y in range(width):
        for x in range(width):
            offset = level_offset + (y * width + x) * H3M_TILE_BYTES_PER_CELL
            if offset + 5 <= len(data) and data[offset + 4] != 0:
                lookup.add(point_key(x, y))
    return lookup


def parse_h3m(path: Path) -> dict[str, Any]:
    data = load_bytes(path)
    version = u32(data, 0)
    width = u32(data, 5)
    level_count = 2 if len(data) > 9 and data[9] != 0 else 1
    metadata = load_object_metadata()
    first_error: dict[str, Any] = {}
    for def_offset in find_object_definition_offsets(data):
        tile_offset = def_offset - width * width * level_count * H3M_TILE_BYTES_PER_CELL
        if tile_offset <= 0:
            continue
        templates = parse_h3m_object_templates(data, def_offset, metadata)
        if templates.get("status") != "parsed":
            first_error = first_error or templates
            continue
        objects = parse_h3m_object_instances(data, int(templates["next_offset"]), templates["templates"], width, level_count)
        if objects.get("status") != "parsed":
            first_error = first_error or objects
            continue
        records = objects["records"]
        return h3m_metrics(path, data, records, tile_offset, width, level_count, version, objects)
    return {"status": "not_attempted", "path": str(path), "error": first_error or "object_definition_offset_not_found"}


def terrain_blocked_from_h3m(data: bytes, tile_offset: int, width: int, level: int) -> set[str]:
    blocked: set[str] = set()
    level_offset = tile_offset + level * width * width * H3M_TILE_BYTES_PER_CELL
    for y in range(width):
        for x in range(width):
            offset = level_offset + (y * width + x) * H3M_TILE_BYTES_PER_CELL
            if offset < len(data) and data[offset] in H3M_BLOCKING_TERRAIN_TYPE_IDS:
                blocked.add(point_key(x, y))
    return blocked


def semantic_from_h3m(data: bytes, tile_offset: int, records: list[dict[str, Any]], width: int, level_count: int) -> dict[str, Any]:
    states = {
        str(level): {"terrain_blocked": terrain_blocked_from_h3m(data, tile_offset, width, level), "object_blocked": set(), "guarded_blocked": set(), "guard_controlled": set(), "towns": []}
        for level in range(level_count)
    }
    for record in records:
        level_key = str(int(record.get("level", 0)))
        state = states.setdefault(level_key, {"terrain_blocked": set(), "object_blocked": set(), "guarded_blocked": set(), "guard_controlled": set(), "towns": []})
        category = h3m_category(record)
        for point in mask_points(record, False, width, width):
            state["object_blocked"].add(point_key(point["x"], point["y"]))
            state["guarded_blocked"].add(point_key(point["x"], point["y"]))
        if category == "guard":
            for point in guard_control_points(record, width, width):
                state["guard_controlled"].add(point_key(point["x"], point["y"]))
                state["guarded_blocked"].add(point_key(point["x"], point["y"]))
        if category == "town":
            visit_points = mask_points(record, True, width, width) or [{"x": int(record.get("x", 0)), "y": int(record.get("y", 0))}]
            state["towns"].append({"id": f"owner_town_{level_key}_{len(state['towns']) + 1:02d}", "x": int(record.get("x", 0)), "y": int(record.get("y", 0)), "visit_points": visit_points})
    return semantic_summary(states, width, width)


def h3m_metrics(path: Path, data: bytes, records: list[dict[str, Any]], tile_offset: int, width: int, level_count: int, version: int, objects: dict[str, Any]) -> dict[str, Any]:
    counts_by_category = Counter(h3m_category(record) for record in records)
    counts_by_level: dict[str, Counter[str]] = {}
    for record in records:
        level_key = str(int(record.get("level", 0)))
        counts_by_level.setdefault(level_key, Counter())[h3m_category(record)] += 1
    road_counts: dict[str, int] = {}
    road_components: dict[str, list[int]] = {}
    for level in range(level_count):
        road = h3m_road_lookup(data, tile_offset, width, level)
        road_counts[str(level)] = len(road)
        road_components[str(level)] = component_sizes(road, width)
    return {
        "status": "parsed",
        "format": "h3m",
        "path": str(path),
        "version": version,
        "width": width,
        "height": width,
        "level_count": level_count,
        "object_count": len(records),
        "declared_object_count": objects.get("declared_object_count", len(records)),
        "parsed_object_count": objects.get("parsed_object_count", len(records)),
        "missing_object_instance_count": objects.get("missing_object_instance_count", 0),
        "counts_by_category": dict(sorted(counts_by_category.items())),
        "counts_by_level": {key: dict(sorted(value.items())) for key, value in sorted(counts_by_level.items())},
        "road_cell_count_by_level": road_counts,
        "road_cell_count_total": sum(road_counts.values()),
        "road_component_sizes_by_level": road_components,
        "semantic_layout": semantic_from_h3m(data, tile_offset, records, width, level_count),
    }


def native_category(kind: str) -> str:
    if kind == "decorative_obstacle":
        return "decoration"
    if kind in {"guard", "route_guard"}:
        return "guard"
    if kind in {"connection_gate", "special_guard_gate"}:
        return "guard"
    if kind == "scenic_object":
        return "object"
    if kind in REWARD_KINDS:
        return "reward"
    if kind == "town":
        return "town"
    return "object"


def load_amap(path: Path) -> dict[str, Any]:
    package = json.loads(path.read_text())
    doc = package.get("document", package)
    objects = doc.get("objects", [])
    counts_by_kind = Counter(str(obj.get("kind", obj.get("native_record_kind", obj.get("category_id", "object")))) for obj in objects)
    counts_by_category = Counter(native_category(kind) for kind in counts_by_kind.elements())
    counts_by_level: dict[str, Counter[str]] = {}
    for obj in objects:
        level_key = str(int(obj.get("level", 0)))
        counts_by_level.setdefault(level_key, Counter())[native_category(str(obj.get("kind", "")))] += 1
    road_counts, road_components = native_roads(doc)
    return {
        "status": "parsed",
        "format": "amap",
        "path": str(path),
        "width": int(doc.get("width", 0)),
        "height": int(doc.get("height", 0)),
        "level_count": int(doc.get("level_count", 1)),
        "object_count": len(objects),
        "counts_by_kind": dict(sorted(counts_by_kind.items())),
        "counts_by_category": dict(sorted(counts_by_category.items())),
        "counts_by_level": {key: dict(sorted(value.items())) for key, value in sorted(counts_by_level.items())},
        "road_cell_count_by_level": road_counts,
        "road_cell_count_total": sum(road_counts.values()),
        "road_component_sizes_by_level": road_components,
        "semantic_layout": semantic_from_amap(doc),
    }


def native_roads(doc: dict[str, Any]) -> tuple[dict[str, int], dict[str, list[int]]]:
    width = int(doc.get("width", 0))
    level_count = int(doc.get("level_count", 1))
    by_level = {str(level): set() for level in range(level_count)}
    layers = doc.get("terrain_layers", {})
    for road in layers.get("roads", []):
        for cell in road.get("cells", []):
            level = str(int(cell.get("level", 0)))
            by_level.setdefault(level, set()).add(point_key(int(cell.get("x", 0)), int(cell.get("y", 0))))
    return (
        {key: len(value) for key, value in sorted(by_level.items())},
        {key: component_sizes(value, width) for key, value in sorted(by_level.items())},
    )


def native_terrain_blocked(doc: dict[str, Any], level: int) -> set[str]:
    width = int(doc.get("width", 0))
    height = int(doc.get("height", 0))
    layers = doc.get("terrain_layers", {})
    terrain = layers.get("terrain", {})
    levels = terrain.get("levels", [])
    ids_by_code = layers.get("terrain_id_by_code", [])
    if level >= len(levels):
        return set()
    codes = levels[level].get("terrain_code_u16", []) if isinstance(levels[level], dict) else levels[level]
    blocked: set[str] = set()
    for y in range(height):
        for x in range(width):
            index = y * width + x
            code = int(codes[index]) if index < len(codes) else 0
            terrain_id = str(ids_by_code[code]) if 0 <= code < len(ids_by_code) else "grass"
            if terrain_id in {"rock", "water"}:
                blocked.add(point_key(x, y))
    return blocked


def semantic_from_amap(doc: dict[str, Any]) -> dict[str, Any]:
    width = int(doc.get("width", 0))
    height = int(doc.get("height", 0))
    level_count = int(doc.get("level_count", 1))
    states = {
        str(level): {"terrain_blocked": native_terrain_blocked(doc, level), "object_blocked": set(), "guarded_blocked": set(), "guard_controlled": set(), "towns": []}
        for level in range(level_count)
    }
    for obj in doc.get("objects", []):
        level_key = str(int(obj.get("level", 0)))
        state = states.setdefault(level_key, {"terrain_blocked": set(), "object_blocked": set(), "guarded_blocked": set(), "guard_controlled": set(), "towns": []})
        kind = str(obj.get("kind", obj.get("native_record_kind", obj.get("category_id", "object"))))
        block_tiles = obj.get("package_block_tiles", obj.get("body_tiles", []))
        object_block_tiles = obj.get("package_body_tiles", obj.get("body_tiles", [])) if kind == "guard" else block_tiles
        for tile in object_block_tiles:
            key = point_key(int(tile.get("x", 0)), int(tile.get("y", 0)))
            state["object_blocked"].add(key)
        for tile in block_tiles:
            key = point_key(int(tile.get("x", 0)), int(tile.get("y", 0)))
            state["guarded_blocked"].add(key)
            if kind == "guard":
                state["guard_controlled"].add(key)
        if kind == "town":
            visit_points = obj.get("package_visit_tiles") or obj.get("approach_tiles") or [{"x": int(obj.get("x", 0)), "y": int(obj.get("y", 0))}]
            state["towns"].append({"id": str(obj.get("placement_id", "")), "x": int(obj.get("x", 0)), "y": int(obj.get("y", 0)), "visit_points": visit_points})
    return semantic_summary(states, width, height)


def nearest_manhattan(points: list[tuple[int, int]]) -> int:
    best = 0
    for left_index, left in enumerate(points):
        for right in points[left_index + 1 :]:
            distance = abs(left[0] - right[0]) + abs(left[1] - right[1])
            best = distance if best == 0 else min(best, distance)
    return best


def find_any_path(blocked: set[str], width: int, height: int, starts: list[dict[str, int]], goals: list[dict[str, int]]) -> list[tuple[int, int]]:
    goal_lookup = {point_key(int(goal.get("x", 0)), int(goal.get("y", 0))) for goal in goals}
    blocked = set(blocked) - goal_lookup
    queue: deque[tuple[int, int]] = deque()
    seen: set[str] = set()
    previous: dict[str, tuple[int, int]] = {}
    for start in starts:
        item = (int(start.get("x", 0)), int(start.get("y", 0)))
        key = point_key(*item)
        blocked.discard(key)
        seen.add(key)
        queue.append(item)
    dirs = [(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, 1), (1, -1), (-1, -1)]
    while queue:
        current = queue.popleft()
        current_key = point_key(*current)
        if current_key in goal_lookup:
            path = [current]
            guard = 0
            while current_key in previous and guard < 4096:
                guard += 1
                current = previous[current_key]
                current_key = point_key(*current)
                path.insert(0, current)
            return path
        for dx, dy in dirs:
            nxt = (current[0] + dx, current[1] + dy)
            key = point_key(*nxt)
            if 0 <= nxt[0] < width and 0 <= nxt[1] < height and key not in seen and key not in blocked:
                seen.add(key)
                previous[key] = current
                queue.append(nxt)
    return []


def town_pair_topology(blocked: set[str], width: int, height: int, towns: list[dict[str, Any]]) -> dict[str, Any]:
    reachable = []
    checked = 0
    for left_index, left in enumerate(towns):
        for right in towns[left_index + 1 :]:
            checked += 1
            path = find_any_path(blocked, width, height, left.get("visit_points", []), right.get("visit_points", []))
            if path:
                reachable.append({"left": {"id": left.get("id", ""), "x": left.get("x", 0), "y": left.get("y", 0)}, "right": {"id": right.get("id", ""), "x": right.get("x", 0), "y": right.get("y", 0)}, "path_length": len(path)})
    return {"checked_pair_count": checked, "reachable_pair_count": len(reachable), "reachable_pairs": reachable[:8]}


def semantic_summary(states: dict[str, dict[str, Any]], width: int, height: int) -> dict[str, Any]:
    by_level: dict[str, Any] = {}
    nearest_values: list[int] = []
    object_route_total = guarded_route_total = guard_controlled_total = 0
    for level_key, state in sorted(states.items()):
        towns = state["towns"]
        nearest = nearest_manhattan([(int(t["x"]), int(t["y"])) for t in towns])
        if nearest > 0:
            nearest_values.append(nearest)
        object_blocked = set(state["terrain_blocked"]) | set(state["object_blocked"])
        guarded_blocked = set(state["terrain_blocked"]) | set(state["guarded_blocked"])
        object_topology = town_pair_topology(object_blocked, width, height, towns)
        guarded_topology = town_pair_topology(guarded_blocked, width, height, towns)
        object_route_total += int(object_topology["reachable_pair_count"])
        guarded_route_total += int(guarded_topology["reachable_pair_count"])
        guard_controlled_total += len(state["guard_controlled"])
        by_level[level_key] = {
            "town_count": len(towns),
            "nearest_town_manhattan": nearest,
            "terrain_blocked_tile_count": len(state["terrain_blocked"]),
            "object_blocked_tile_count": len(state["object_blocked"]),
            "guarded_blocked_tile_count": len(state["guarded_blocked"]),
            "guard_controlled_tile_count": len(state["guard_controlled"]),
            "object_route_topology": object_topology,
            "guarded_route_topology": guarded_topology,
        }
    return {
        "by_level": by_level,
        "nearest_town_manhattan_min": min(nearest_values) if nearest_values else 0,
        "object_route_reachable_pair_count_total": object_route_total,
        "guarded_route_reachable_pair_count_total": guarded_route_total,
        "guard_controlled_tile_count_total": guard_controlled_total,
    }


def density_per_1000(metrics: dict[str, Any], value: int) -> float:
    area = max(1, int(metrics.get("width", 0)) * int(metrics.get("height", 0)) * int(metrics.get("level_count", 1)))
    return round((float(value) * 1000.0) / float(area), 3)


def compact_metrics(metrics: dict[str, Any]) -> dict[str, Any]:
    semantic = metrics.get("semantic_layout", {}) if isinstance(metrics.get("semantic_layout", {}), dict) else {}
    category_counts = metrics.get("counts_by_category", {}) if isinstance(metrics.get("counts_by_category", {}), dict) else {}
    object_count = int(metrics.get("object_count", 0))
    road_count = int(metrics.get("road_cell_count_total", 0))
    result: dict[str, Any] = {
        "status": metrics.get("status", ""),
        "format": metrics.get("format", ""),
        "path": metrics.get("path", ""),
        "width": int(metrics.get("width", 0)),
        "height": int(metrics.get("height", 0)),
        "level_count": int(metrics.get("level_count", 1)),
        "object_count": object_count,
        "counts_by_category": category_counts,
        "counts_by_level": metrics.get("counts_by_level", {}),
        "road_cell_count_total": road_count,
        "road_component_sizes_by_level": metrics.get("road_component_sizes_by_level", {}),
        "object_density_per_1000_tiles": density_per_1000(metrics, object_count),
        "road_density_per_1000_tiles": density_per_1000(metrics, road_count),
        "guarded_route_reachable_pair_count_total": int(semantic.get("guarded_route_reachable_pair_count_total", 0)),
        "object_route_reachable_pair_count_total": int(semantic.get("object_route_reachable_pair_count_total", 0)),
        "nearest_town_manhattan_min": int(semantic.get("nearest_town_manhattan_min", 0)),
    }
    reward_count = int(category_counts.get("reward", 0))
    guard_count = int(category_counts.get("guard", 0))
    town_count = int(category_counts.get("town", 0))
    result["guard_to_reward_ratio"] = round(float(guard_count) / float(max(1, reward_count)), 3)
    result["town_density_per_1000_tiles"] = density_per_1000(metrics, town_count)
    return result


def corpus_group_key(metrics: dict[str, Any]) -> str:
    return "%s_%sx%s_l%s" % (
        metrics.get("format", "unknown"),
        int(metrics.get("width", 0)),
        int(metrics.get("height", 0)),
        int(metrics.get("level_count", 1)),
    )


def average(values: list[float]) -> float:
    if not values:
        return 0.0
    return round(sum(values) / float(len(values)), 3)


def summarize_compact_samples(samples: list[dict[str, Any]]) -> dict[str, Any]:
    parsed = [sample for sample in samples if sample.get("status") == "parsed"]
    failed = [sample for sample in samples if sample.get("status") != "parsed"]
    groups: dict[str, list[dict[str, Any]]] = {}
    for sample in parsed:
        groups.setdefault(corpus_group_key(sample), []).append(sample)
    by_group: dict[str, Any] = {}
    for key, group_samples in sorted(groups.items()):
        compact = [compact_metrics(sample) for sample in group_samples]
        category_totals: Counter[str] = Counter()
        for sample in group_samples:
            category_totals.update(sample.get("counts_by_category", {}))
        by_group[key] = {
            "sample_count": len(group_samples),
            "object_density_per_1000_tiles_avg": average([float(item["object_density_per_1000_tiles"]) for item in compact]),
            "road_density_per_1000_tiles_avg": average([float(item["road_density_per_1000_tiles"]) for item in compact]),
            "town_density_per_1000_tiles_avg": average([float(item["town_density_per_1000_tiles"]) for item in compact]),
            "guard_to_reward_ratio_avg": average([float(item["guard_to_reward_ratio"]) for item in compact]),
            "guarded_route_reachable_pair_count_total": sum(int(item["guarded_route_reachable_pair_count_total"]) for item in compact),
            "object_route_reachable_pair_count_total": sum(int(item["object_route_reachable_pair_count_total"]) for item in compact),
            "category_totals": dict(sorted(category_totals.items())),
            "sample_paths": [str(item.get("path", "")) for item in compact],
        }
    return {
        "sample_count": len(samples),
        "parsed_count": len(parsed),
        "failed_count": len(failed),
        "by_group": by_group,
        "failed_samples": [
            {"path": sample.get("path", ""), "status": sample.get("status", ""), "error": sample.get("error", "")}
            for sample in failed
        ],
    }


def parse_many(paths: list[Path], parser_fn: Any) -> list[dict[str, Any]]:
    samples: list[dict[str, Any]] = []
    for path in sorted(paths, key=lambda value: str(value)):
        try:
            samples.append(parser_fn(path))
        except Exception as exc:  # pragma: no cover - CLI resilience path
            samples.append({"status": "error", "path": str(path), "error": f"{type(exc).__name__}: {exc}"})
    return samples


def batch_report(h3m_dir: Path | None, amap_dir: Path | None, full: bool) -> dict[str, Any]:
    samples: list[dict[str, Any]] = []
    inputs: dict[str, str] = {}
    if h3m_dir:
        inputs["h3m_dir"] = str(h3m_dir)
        samples.extend(parse_many(list(h3m_dir.rglob("*.h3m")), parse_h3m))
    if amap_dir:
        inputs["amap_dir"] = str(amap_dir)
        samples.extend(parse_many(list(amap_dir.rglob("*.amap")), load_amap))
    summary = summarize_compact_samples(samples)
    status = "parsed" if summary["parsed_count"] > 0 and summary["failed_count"] == 0 else ("partial" if summary["parsed_count"] > 0 else "fail")
    return {
        "schema_id": "rmg_fast_audit_batch_v1",
        "status": status,
        "inputs": inputs,
        "summary": summary,
        "samples": samples if full else [compact_metrics(sample) if sample.get("status") == "parsed" else sample for sample in samples],
    }


def compare(owner: dict[str, Any], native: dict[str, Any]) -> dict[str, Any]:
    categories = sorted(set(owner.get("counts_by_category", {})) | set(native.get("counts_by_category", {})))
    category_delta = {
        category: {
            "owner_count": int(owner.get("counts_by_category", {}).get(category, 0)),
            "native_count": int(native.get("counts_by_category", {}).get(category, 0)),
            "delta": int(native.get("counts_by_category", {}).get(category, 0)) - int(owner.get("counts_by_category", {}).get(category, 0)),
        }
        for category in categories
    }
    owner_sem = owner.get("semantic_layout", {})
    native_sem = native.get("semantic_layout", {})
    owner_terrain_blocked = sum(
        int(level.get("terrain_blocked_tile_count", 0))
        for level in owner_sem.get("by_level", {}).values()
        if isinstance(level, dict)
    ) if isinstance(owner_sem.get("by_level", {}), dict) else 0
    native_terrain_blocked = sum(
        int(level.get("terrain_blocked_tile_count", 0))
        for level in native_sem.get("by_level", {}).values()
        if isinstance(level, dict)
    ) if isinstance(native_sem.get("by_level", {}), dict) else 0
    return {
        "status": "pass"
        if int(native.get("object_count", 0)) == int(owner.get("object_count", 0))
        and all(row["delta"] == 0 for row in category_delta.values())
        and native.get("road_component_sizes_by_level", {}) == owner.get("road_component_sizes_by_level", {})
        and int(native_sem.get("guarded_route_reachable_pair_count_total", 0)) <= int(owner_sem.get("guarded_route_reachable_pair_count_total", 0))
        else "fail",
        "deltas_vs_owner": {
            "object_count_delta": int(native.get("object_count", 0)) - int(owner.get("object_count", 0)),
            "road_cell_count_delta": int(native.get("road_cell_count_total", 0)) - int(owner.get("road_cell_count_total", 0)),
            "terrain_blocked_tile_count_delta": native_terrain_blocked - owner_terrain_blocked,
            "guarded_route_reachable_pair_delta": int(native_sem.get("guarded_route_reachable_pair_count_total", 0)) - int(owner_sem.get("guarded_route_reachable_pair_count_total", 0)),
            "object_route_reachable_pair_delta": int(native_sem.get("object_route_reachable_pair_count_total", 0)) - int(owner_sem.get("object_route_reachable_pair_count_total", 0)),
        },
        "category_delta": category_delta,
        "road_component_sizes_match": native.get("road_component_sizes_by_level", {}) == owner.get("road_component_sizes_by_level", {}),
        "owner": owner,
        "native": native,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--h3m", type=Path, help="Owner H3M evidence file to parse")
    parser.add_argument("--amap", type=Path, help="Native .amap package to parse")
    parser.add_argument("--h3m-dir", type=Path, help="Recursively parse owner H3M evidence files")
    parser.add_argument("--amap-dir", type=Path, help="Recursively parse native .amap package files")
    parser.add_argument("--compare", action="store_true", help="Compare --h3m and --amap metrics")
    parser.add_argument("--full", action="store_true", help="Include full per-file metrics in batch mode")
    parser.add_argument("--allow-failures", action="store_true", help="Return success for partial batch scans with parse failures")
    parser.add_argument("--pretty", action="store_true", help="Pretty-print JSON")
    args = parser.parse_args()

    if args.compare and (not args.h3m or not args.amap):
        parser.error("--compare requires --h3m and --amap")
    if args.compare:
        result = compare(parse_h3m(args.h3m), load_amap(args.amap))
    elif args.h3m_dir or args.amap_dir:
        result = batch_report(args.h3m_dir, args.amap_dir, args.full)
    elif args.h3m:
        result = parse_h3m(args.h3m)
    elif args.amap:
        result = load_amap(args.amap)
    else:
        parser.error("provide --h3m, --amap, --h3m-dir, --amap-dir, or --compare")
    print(json.dumps(result, indent=2 if args.pretty else None, sort_keys=True))
    if result.get("status") in {"parsed", "pass"}:
        return 0
    if args.allow_failures and result.get("status") == "partial":
        return 0
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
