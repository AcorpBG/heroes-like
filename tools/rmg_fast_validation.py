#!/usr/bin/env python3
"""Fast RMG validation/comparison loop without starting Godot.

Use this after a native batch export has produced `.amap` packages. The script
parses owner `.h3m` evidence and native `.amap` packages directly, then applies
structural RMG rules and owner-baseline diagnostics. Godot should only be needed
for fresh native generation/export and engine/editor integration smokes.
"""

from __future__ import annotations

import argparse
import json
import re
import time
from collections import Counter
from pathlib import Path
from typing import Any

import rmg_fast_audit


DEFAULT_OWNER_DIR = Path("maps/h3m-maps")
DEFAULT_NATIVE_DIR = Path(".artifacts/rmg_native_batch_export_current")
DEFAULT_ARTIFACT_ROOT = Path(".artifacts")
DEFAULT_DENSITY_FLOOR_RATIO = 0.70
DEFAULT_ROAD_FLOOR_RATIO = 0.65
DEFAULT_GUARD_REWARD_RATIO_FLOOR_RATIO = 0.60
DEFAULT_POLICY_DENSITY_EPSILON = 0.05
DEFAULT_ROAD_LARGEST_SHARE_MULTIPLIER = 1.25
DEFAULT_ROAD_LARGEST_SHARE_ABSOLUTE_CAP = 0.92
DEFAULT_ROAD_LARGEST_SHARE_EPSILON = 0.05
DEFAULT_ROAD_COMPONENT_COUNT_FLOOR_RATIO = 0.50
DEFAULT_GUARD_CLOSURE_MIN_OWNER_OPEN_PAIR_COUNT = 1
DEFAULT_CATEGORY_FLOOR_RATIOS = {
    "guard": 0.55,
    "object": 0.60,
    "reward": 0.55,
    "town": 0.65,
}
CASE_ID_PATTERN = re.compile(r"[^a-z0-9]+")
NATIVE_EXPORT_DIR_PREFIX = "rmg_native_batch_export"


def case_id_from_path(path: Path) -> str:
    value = CASE_ID_PATTERN.sub("_", path.stem.lower()).strip("_")
    while "__" in value:
        value = value.replace("__", "_")
    return value


def parse_paths(paths: list[Path], parser_fn: Any) -> tuple[list[dict[str, Any]], float]:
    start = time.perf_counter()
    parsed = rmg_fast_audit.parse_many(paths, parser_fn)
    return parsed, round(time.perf_counter() - start, 3)


def latest_native_export_dir(artifact_root: Path) -> Path | None:
    if not artifact_root.exists() or not artifact_root.is_dir():
        return None
    candidates: list[Path] = []
    for path in artifact_root.iterdir():
        if not path.is_dir() or not path.name.startswith(NATIVE_EXPORT_DIR_PREFIX):
            continue
        if any(path.glob("*.amap")):
            candidates.append(path)
    if not candidates:
        return None
    return max(candidates, key=lambda path: path.stat().st_mtime)


def group_key(metrics: dict[str, Any]) -> str:
    return "%sx%s_l%s" % (
        int(metrics.get("width", 0)),
        int(metrics.get("height", 0)),
        int(metrics.get("level_count", 1)),
    )


def category_count(metrics: dict[str, Any], category: str) -> int:
    counts = metrics.get("counts_by_category", {})
    return int(counts.get(category, 0)) if isinstance(counts, dict) else 0


def level_category_count(metrics: dict[str, Any], level: int, category: str | None = None) -> int:
    counts_by_level = metrics.get("counts_by_level", {})
    level_counts = counts_by_level.get(str(level), {}) if isinstance(counts_by_level, dict) else {}
    if not isinstance(level_counts, dict):
        return 0
    if category is not None:
        return int(level_counts.get(category, 0))
    return sum(int(value) for value in level_counts.values())


def object_density(metrics: dict[str, Any]) -> float:
    return rmg_fast_audit.density_per_1000(metrics, int(metrics.get("object_count", 0)))


def category_density(metrics: dict[str, Any], category: str) -> float:
    return rmg_fast_audit.density_per_1000(metrics, category_count(metrics, category))


def road_density(metrics: dict[str, Any]) -> float:
    return rmg_fast_audit.density_per_1000(metrics, int(metrics.get("road_cell_count_total", 0)))


def road_component_sizes(metrics: dict[str, Any]) -> list[int]:
    by_level = metrics.get("road_component_sizes_by_level", {})
    if not isinstance(by_level, dict):
        return []
    sizes: list[int] = []
    for values in by_level.values():
        if not isinstance(values, list):
            continue
        sizes.extend(int(value) for value in values)
    return [size for size in sizes if size > 0]


def road_topology(metrics: dict[str, Any]) -> dict[str, Any]:
    sizes = road_component_sizes(metrics)
    total = sum(sizes)
    largest = max(sizes) if sizes else 0
    return {
        "road_component_count": len(sizes),
        "road_component_size_avg": round(float(total) / float(max(1, len(sizes))), 3),
        "road_largest_component_size": largest,
        "road_largest_component_share": round(float(largest) / float(total), 3) if total > 0 else 0.0,
        "road_cell_count_total": total,
    }


def guard_reward_ratio(metrics: dict[str, Any]) -> float:
    return round(float(category_count(metrics, "guard")) / float(max(1, category_count(metrics, "reward"))), 3)


def average(values: list[float]) -> float:
    if not values:
        return 0.0
    return round(sum(values) / float(len(values)), 3)


def town_spacing_floor(width: int) -> int:
    if width <= 36:
        return 12
    if width <= 72:
        return 20
    if width <= 108:
        return 28
    return 34


def semantic(metrics: dict[str, Any]) -> dict[str, Any]:
    value = metrics.get("semantic_layout", {})
    return value if isinstance(value, dict) else {}


def native_rule_failures(metrics: dict[str, Any], owner: dict[str, Any] | None) -> list[dict[str, Any]]:
    failures: list[dict[str, Any]] = []
    path = str(metrics.get("path", ""))
    width = int(metrics.get("width", 0))
    height = int(metrics.get("height", 0))
    level_count = int(metrics.get("level_count", 1))
    object_count = int(metrics.get("object_count", 0))
    road_count = int(metrics.get("road_cell_count_total", 0))
    town_count = category_count(metrics, "town")
    guard_count = category_count(metrics, "guard")
    reward_count = category_count(metrics, "reward")
    sem = semantic(metrics)

    def add(rule: str, detail: dict[str, Any]) -> None:
        failures.append({"path": path, "rule": rule, **detail})

    if width <= 0 or height <= 0 or level_count <= 0:
        add("invalid_dimensions", {"width": width, "height": height, "level_count": level_count})
        return failures
    if object_count <= 0:
        add("missing_objects", {"object_count": object_count})
    if town_count <= 0:
        add("missing_towns", {"town_count": town_count})
    if road_count <= 0:
        add("missing_roads", {"road_cell_count_total": road_count})
    if reward_count > 0 and guard_count <= 0:
        add("unguarded_reward_distribution", {"reward_count": reward_count, "guard_count": guard_count})

    nearest = int(sem.get("nearest_town_manhattan_min", 0))
    spacing_floor = town_spacing_floor(width)
    if town_count > 1 and 0 < nearest < spacing_floor:
        add("near_stacked_towns", {"nearest_town_manhattan_min": nearest, "floor": spacing_floor})

    guarded_pairs = int(sem.get("guarded_route_reachable_pair_count_total", 0))
    owner_guarded_pairs = int(semantic(owner or {}).get("guarded_route_reachable_pair_count_total", 0))
    if guarded_pairs > owner_guarded_pairs:
        add(
            "unguarded_town_route_regression",
            {"native_guarded_route_pairs": guarded_pairs, "owner_guarded_route_pairs": owner_guarded_pairs},
        )

    if level_count > 1:
        road_counts = metrics.get("road_cell_count_by_level", {})
        for level in range(level_count):
            level_objects = level_category_count(metrics, level)
            level_roads = int(road_counts.get(str(level), 0)) if isinstance(road_counts, dict) else 0
            if level_objects <= 0:
                add("empty_generated_level", {"level": level, "level_object_count": level_objects})
            if level_roads <= 0:
                add("level_without_roads", {"level": level, "level_road_cell_count": level_roads})

    return failures


def density_failures(
    owner_samples: list[dict[str, Any]],
    native_samples: list[dict[str, Any]],
    ratio: float,
) -> list[dict[str, Any]]:
    owner_by_group: dict[str, list[dict[str, Any]]] = {}
    native_by_group: dict[str, list[dict[str, Any]]] = {}
    for sample in owner_samples:
        if sample.get("status") == "parsed":
            owner_by_group.setdefault(group_key(sample), []).append(sample)
    for sample in native_samples:
        if sample.get("status") == "parsed":
            native_by_group.setdefault(group_key(sample), []).append(sample)

    failures: list[dict[str, Any]] = []
    for key in sorted(set(owner_by_group) & set(native_by_group)):
        owner_density = average([object_density(sample) for sample in owner_by_group[key]])
        native_density = average([object_density(sample) for sample in native_by_group[key]])
        floor = round(owner_density * ratio, 3)
        if native_density < floor:
            failures.append(
                {
                    "group": key,
                    "rule": "object_density_under_owner_baseline",
                    "owner_object_density_per_1000_tiles_avg": owner_density,
                    "native_object_density_per_1000_tiles_avg": native_density,
                    "floor_ratio": ratio,
                    "floor_density_per_1000_tiles": floor,
                    "owner_sample_count": len(owner_by_group[key]),
                    "native_sample_count": len(native_by_group[key]),
                }
            )
    return failures


def policy_failures(
    owner_samples: list[dict[str, Any]],
    native_samples: list[dict[str, Any]],
    category_floor_ratios: dict[str, float],
    road_floor_ratio: float,
    guard_reward_ratio_floor_ratio: float,
) -> list[dict[str, Any]]:
    owner_by_group: dict[str, list[dict[str, Any]]] = {}
    native_by_group: dict[str, list[dict[str, Any]]] = {}
    for sample in owner_samples:
        if sample.get("status") == "parsed":
            owner_by_group.setdefault(group_key(sample), []).append(sample)
    for sample in native_samples:
        if sample.get("status") == "parsed":
            native_by_group.setdefault(group_key(sample), []).append(sample)

    failures: list[dict[str, Any]] = []
    for key in sorted(set(owner_by_group) & set(native_by_group)):
        owners = owner_by_group[key]
        natives = native_by_group[key]
        for category, ratio in sorted(category_floor_ratios.items()):
            owner_density = average([category_density(sample, category) for sample in owners])
            if owner_density <= 0.0:
                continue
            native_density = average([category_density(sample, category) for sample in natives])
            floor = round(owner_density * ratio, 3)
            if native_density + DEFAULT_POLICY_DENSITY_EPSILON < floor:
                failures.append(
                    {
                        "group": key,
                        "rule": "category_density_under_owner_baseline",
                        "category": category,
                        "owner_category_density_per_1000_tiles_avg": owner_density,
                        "native_category_density_per_1000_tiles_avg": native_density,
                        "floor_ratio": ratio,
                        "floor_density_per_1000_tiles": floor,
                        "owner_sample_count": len(owners),
                        "native_sample_count": len(natives),
                    }
                )

        owner_road_density = average([road_density(sample) for sample in owners])
        native_road_density = average([road_density(sample) for sample in natives])
        road_floor = round(owner_road_density * road_floor_ratio, 3)
        if owner_road_density > 0.0 and native_road_density + DEFAULT_POLICY_DENSITY_EPSILON < road_floor:
            failures.append(
                {
                    "group": key,
                    "rule": "road_density_under_owner_baseline",
                    "owner_road_density_per_1000_tiles_avg": owner_road_density,
                    "native_road_density_per_1000_tiles_avg": native_road_density,
                    "floor_ratio": road_floor_ratio,
                    "floor_density_per_1000_tiles": road_floor,
                    "owner_sample_count": len(owners),
                    "native_sample_count": len(natives),
                }
            )

        owner_guard_reward_ratio = average([guard_reward_ratio(sample) for sample in owners])
        native_guard_reward_ratio = average([guard_reward_ratio(sample) for sample in natives])
        ratio_floor = round(owner_guard_reward_ratio * guard_reward_ratio_floor_ratio, 3)
        if owner_guard_reward_ratio > 0.0 and native_guard_reward_ratio < ratio_floor:
            failures.append(
                {
                    "group": key,
                    "rule": "guard_reward_ratio_under_owner_baseline",
                    "owner_guard_reward_ratio_avg": owner_guard_reward_ratio,
                    "native_guard_reward_ratio_avg": native_guard_reward_ratio,
                    "floor_ratio": guard_reward_ratio_floor_ratio,
                    "floor_guard_reward_ratio": ratio_floor,
                    "owner_sample_count": len(owners),
                    "native_sample_count": len(natives),
                }
            )
    return failures


def topology_failures(
    owner_samples: list[dict[str, Any]],
    native_samples: list[dict[str, Any]],
    largest_share_multiplier: float,
    largest_share_absolute_cap: float,
    component_count_floor_ratio: float,
) -> list[dict[str, Any]]:
    owners = {
        case_id_from_path(Path(str(sample.get("path", "")))): sample
        for sample in owner_samples
        if sample.get("status") == "parsed"
    }
    natives = {
        case_id_from_path(Path(str(sample.get("path", "")))): sample
        for sample in native_samples
        if sample.get("status") == "parsed"
    }
    failures: list[dict[str, Any]] = []
    for case_id in sorted(set(owners) & set(natives)):
        owner_topology = road_topology(owners[case_id])
        native_topology = road_topology(natives[case_id])
        owner_total = int(owner_topology["road_cell_count_total"])
        native_total = int(native_topology["road_cell_count_total"])
        if owner_total <= 0 or native_total <= 0:
            continue

        owner_largest_share = float(owner_topology["road_largest_component_share"])
        native_largest_share = float(native_topology["road_largest_component_share"])
        largest_share_ceiling = round(
            min(
                largest_share_absolute_cap,
                owner_largest_share * largest_share_multiplier + DEFAULT_ROAD_LARGEST_SHARE_EPSILON,
            ),
            3,
        )
        if native_largest_share > largest_share_ceiling:
            failures.append(
                {
                    "case_id": case_id,
                    "path": natives[case_id].get("path", ""),
                    "owner_path": owners[case_id].get("path", ""),
                    "rule": "road_largest_component_dominance_over_owner_baseline",
                    "owner_road_largest_component_share": owner_largest_share,
                    "native_road_largest_component_share": native_largest_share,
                    "ceiling": largest_share_ceiling,
                    "owner_road_component_count": int(owner_topology["road_component_count"]),
                    "native_road_component_count": int(native_topology["road_component_count"]),
                }
            )

        owner_component_count = int(owner_topology["road_component_count"])
        native_component_count = int(native_topology["road_component_count"])
        component_floor = max(1, int(owner_component_count * component_count_floor_ratio))
        if owner_component_count >= 3 and native_component_count < component_floor:
            failures.append(
                {
                    "case_id": case_id,
                    "path": natives[case_id].get("path", ""),
                    "owner_path": owners[case_id].get("path", ""),
                    "rule": "road_component_count_under_owner_topology_floor",
                    "owner_road_component_count": owner_component_count,
                    "native_road_component_count": native_component_count,
                    "floor_ratio": component_count_floor_ratio,
                    "component_count_floor": component_floor,
                    "owner_road_largest_component_share": owner_largest_share,
                    "native_road_largest_component_share": native_largest_share,
                }
            )
    return failures


def guard_closure_shape_failures(
    owner_samples: list[dict[str, Any]],
    native_samples: list[dict[str, Any]],
    min_owner_open_pair_count: int,
) -> list[dict[str, Any]]:
    owners = {
        case_id_from_path(Path(str(sample.get("path", "")))): sample
        for sample in owner_samples
        if sample.get("status") == "parsed"
    }
    natives = {
        case_id_from_path(Path(str(sample.get("path", "")))): sample
        for sample in native_samples
        if sample.get("status") == "parsed"
    }
    failures: list[dict[str, Any]] = []
    for case_id in sorted(set(owners) & set(natives)):
        owner_sem = semantic(owners[case_id])
        native_sem = semantic(natives[case_id])
        owner_object_routes = int(owner_sem.get("object_route_reachable_pair_count_total", 0))
        owner_guarded_routes = int(owner_sem.get("guarded_route_reachable_pair_count_total", 0))
        native_object_routes = int(native_sem.get("object_route_reachable_pair_count_total", 0))
        native_guarded_routes = int(native_sem.get("guarded_route_reachable_pair_count_total", 0))
        owner_guard_closed_routes = max(0, owner_object_routes - owner_guarded_routes)
        native_guard_closed_routes = max(0, native_object_routes - native_guarded_routes)
        if owner_guard_closed_routes < min_owner_open_pair_count:
            continue
        if native_guard_closed_routes <= 0:
            failures.append(
                {
                    "case_id": case_id,
                    "path": natives[case_id].get("path", ""),
                    "owner_path": owners[case_id].get("path", ""),
                    "rule": "missing_guard_mediated_town_route_closure",
                    "owner_object_route_reachable_pair_count": owner_object_routes,
                    "owner_guarded_route_reachable_pair_count": owner_guarded_routes,
                    "owner_guard_closed_pair_count": owner_guard_closed_routes,
                    "native_object_route_reachable_pair_count": native_object_routes,
                    "native_guarded_route_reachable_pair_count": native_guarded_routes,
                    "native_guard_closed_pair_count": native_guard_closed_routes,
                    "minimum_owner_guard_closed_pair_count": min_owner_open_pair_count,
                }
            )
    return failures


def compact_parse_failures(samples: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [
        {
            "path": str(sample.get("path", "")),
            "status": str(sample.get("status", "")),
            "error": sample.get("error", ""),
        }
        for sample in samples
        if sample.get("status") != "parsed"
    ]


def matched_comparisons(owner_samples: list[dict[str, Any]], native_samples: list[dict[str, Any]]) -> list[dict[str, Any]]:
    owners = {case_id_from_path(Path(str(sample.get("path", "")))): sample for sample in owner_samples if sample.get("status") == "parsed"}
    natives = {case_id_from_path(Path(str(sample.get("path", "")))): sample for sample in native_samples if sample.get("status") == "parsed"}
    comparisons: list[dict[str, Any]] = []
    for case_id in sorted(set(owners) & set(natives)):
        comparison = rmg_fast_audit.compare(owners[case_id], natives[case_id])
        deltas = comparison.get("deltas_vs_owner", {})
        category_delta = comparison.get("category_delta", {})
        comparisons.append(
            {
                "case_id": case_id,
                "status": comparison.get("status", ""),
                "owner_path": owners[case_id].get("path", ""),
                "native_path": natives[case_id].get("path", ""),
                "deltas_vs_owner": deltas,
                "category_delta": category_delta,
                "road_component_sizes_match": comparison.get("road_component_sizes_match", False),
            }
        )
    return comparisons


def sample_group_summary(samples: list[dict[str, Any]]) -> dict[str, Any]:
    parsed = [sample for sample in samples if sample.get("status") == "parsed"]
    by_group: dict[str, list[dict[str, Any]]] = {}
    for sample in parsed:
        by_group.setdefault(group_key(sample), []).append(sample)
    result: dict[str, Any] = {}
    for key, group_samples in sorted(by_group.items()):
        categories: Counter[str] = Counter()
        for sample in group_samples:
            categories.update(sample.get("counts_by_category", {}))
        result[key] = {
            "sample_count": len(group_samples),
            "object_density_per_1000_tiles_avg": average([object_density(sample) for sample in group_samples]),
            "road_density_per_1000_tiles_avg": average(
                [road_density(sample) for sample in group_samples]
            ),
            "road_largest_component_share_avg": average(
                [float(road_topology(sample)["road_largest_component_share"]) for sample in group_samples]
            ),
            "road_component_count_avg": average(
                [float(road_topology(sample)["road_component_count"]) for sample in group_samples]
            ),
            "guard_reward_ratio_avg": average([guard_reward_ratio(sample) for sample in group_samples]),
            "category_totals": dict(sorted(categories.items())),
        }
    return result


def coverage_failures(owner_samples: list[dict[str, Any]], native_samples: list[dict[str, Any]]) -> list[dict[str, Any]]:
    owner_cases = {
        case_id_from_path(Path(str(sample.get("path", "")))): sample
        for sample in owner_samples
        if sample.get("status") == "parsed"
    }
    native_cases = {
        case_id_from_path(Path(str(sample.get("path", "")))): sample
        for sample in native_samples
        if sample.get("status") == "parsed"
    }
    missing = sorted(case_id for case_id in owner_cases if case_id not in native_cases)
    if not missing:
        return []
    return [
        {
            "rule": "missing_native_owner_match",
            "owner_parsed_count": len(owner_cases),
            "native_parsed_count": len(native_cases),
            "missing_count": len(missing),
            "missing_case_ids": missing,
        }
    ]


def build_report(args: argparse.Namespace) -> dict[str, Any]:
    requested_native_dir = args.amap_dir
    native_dir = args.amap_dir
    native_artifact_autodiscovered = False
    native_artifact_discovery_error = ""
    if args.latest_amap_artifact:
        latest_dir = latest_native_export_dir(args.artifact_root)
        if latest_dir is None:
            native_artifact_discovery_error = "no_native_batch_export_with_amap_files"
            native_dir = None
        else:
            native_dir = latest_dir
            native_artifact_autodiscovered = True
    owner_paths = list(args.h3m_dir.rglob("*.h3m")) if args.h3m_dir and args.h3m_dir.exists() else []
    native_paths = list(native_dir.rglob("*.amap")) if native_dir and native_dir.exists() else []
    owner_samples, owner_seconds = parse_paths(owner_paths, rmg_fast_audit.parse_h3m)
    native_samples, native_seconds = parse_paths(native_paths, rmg_fast_audit.load_amap)

    parse_failures = compact_parse_failures(owner_samples) + compact_parse_failures(native_samples)
    if native_artifact_discovery_error:
        parse_failures.append(
            {
                "path": str(args.artifact_root),
                "status": "missing_native_artifact",
                "error": native_artifact_discovery_error,
            }
        )
    owners_by_case = {
        case_id_from_path(Path(str(sample.get("path", "")))): sample
        for sample in owner_samples
        if sample.get("status") == "parsed"
    }
    native_failures: list[dict[str, Any]] = []
    for sample in native_samples:
        if sample.get("status") != "parsed":
            continue
        owner = owners_by_case.get(case_id_from_path(Path(str(sample.get("path", "")))))
        native_failures.extend(native_rule_failures(sample, owner))
    density_gaps = [] if args.no_density_gate else density_failures(owner_samples, native_samples, args.density_floor_ratio)
    policy_gaps = [] if args.no_policy_gate else policy_failures(
        owner_samples,
        native_samples,
        DEFAULT_CATEGORY_FLOOR_RATIOS,
        args.road_floor_ratio,
        args.guard_reward_ratio_floor_ratio,
    )
    topology_gaps = [] if args.no_topology_gate else topology_failures(
        owner_samples,
        native_samples,
        args.road_largest_share_multiplier,
        args.road_largest_share_absolute_cap,
        args.road_component_count_floor_ratio,
    )
    closure_shape_gaps = guard_closure_shape_failures(
        owner_samples,
        native_samples,
        args.guard_closure_min_owner_open_pair_count,
    ) if args.closure_shape_gate else []
    comparisons = matched_comparisons(owner_samples, native_samples)
    coverage_gaps = coverage_failures(owner_samples, native_samples) if bool(getattr(args, "require_all_owner_matches", False)) else []

    status = "pass" if not parse_failures and not native_failures and not density_gaps and not policy_gaps and not topology_gaps and not closure_shape_gaps and not coverage_gaps else "fail"
    return {
        "schema_id": "rmg_fast_validation_v1",
        "status": status,
        "inputs": {
            "h3m_dir": str(args.h3m_dir) if args.h3m_dir else "",
            "amap_dir": str(native_dir) if native_dir else "",
            "requested_amap_dir": str(requested_native_dir) if requested_native_dir else "",
            "latest_amap_artifact": bool(args.latest_amap_artifact),
            "artifact_root": str(args.artifact_root),
            "native_artifact_autodiscovered": native_artifact_autodiscovered,
            "native_artifact_discovery_error": native_artifact_discovery_error,
            "density_floor_ratio": args.density_floor_ratio,
            "density_gate_enabled": not args.no_density_gate,
            "policy_gate_enabled": not args.no_policy_gate,
            "category_floor_ratios": DEFAULT_CATEGORY_FLOOR_RATIOS,
            "road_floor_ratio": args.road_floor_ratio,
            "guard_reward_ratio_floor_ratio": args.guard_reward_ratio_floor_ratio,
            "policy_density_epsilon_per_1000_tiles": DEFAULT_POLICY_DENSITY_EPSILON,
            "topology_gate_enabled": not args.no_topology_gate,
            "road_largest_share_multiplier": args.road_largest_share_multiplier,
            "road_largest_share_absolute_cap": args.road_largest_share_absolute_cap,
            "road_largest_share_epsilon": DEFAULT_ROAD_LARGEST_SHARE_EPSILON,
            "road_component_count_floor_ratio": args.road_component_count_floor_ratio,
            "closure_shape_gate_enabled": args.closure_shape_gate,
            "guard_closure_min_owner_open_pair_count": args.guard_closure_min_owner_open_pair_count,
            "require_all_owner_matches": bool(getattr(args, "require_all_owner_matches", False)),
        },
        "timings_seconds": {
            "owner_h3m_parse": owner_seconds,
            "native_amap_parse": native_seconds,
            "total_parse": round(owner_seconds + native_seconds, 3),
        },
        "summary": {
            "owner_sample_count": len(owner_samples),
            "native_sample_count": len(native_samples),
            "owner_parsed_count": len([sample for sample in owner_samples if sample.get("status") == "parsed"]),
            "native_parsed_count": len([sample for sample in native_samples if sample.get("status") == "parsed"]),
            "parse_failure_count": len(parse_failures),
            "native_rule_failure_count": len(native_failures),
            "density_gap_count": len(density_gaps),
            "policy_gap_count": len(policy_gaps),
            "topology_gap_count": len(topology_gaps),
            "closure_shape_gap_count": len(closure_shape_gaps),
            "coverage_gap_count": len(coverage_gaps),
            "matched_comparison_count": len(comparisons),
        },
        "failures": {
            "parse": parse_failures,
            "native_rules": native_failures,
            "density_gaps": density_gaps,
            "policy_gaps": policy_gaps,
            "topology_gaps": topology_gaps,
            "closure_shape_gaps": closure_shape_gaps,
            "coverage_gaps": coverage_gaps,
        },
        "groups": {
            "owner": sample_group_summary(owner_samples),
            "native": sample_group_summary(native_samples),
        },
        "matched_comparisons": comparisons,
    }


def compact_summary(report: dict[str, Any], failure_limit: int) -> str:
    summary = report.get("summary", {})
    timings = report.get("timings_seconds", {})
    inputs = report.get("inputs", {})
    failures = report.get("failures", {})
    lines = [
        "RMG_FAST_VALIDATION status=%s" % report.get("status", "unknown"),
        "inputs owner=%s native=%s" % (inputs.get("h3m_dir", ""), inputs.get("amap_dir", "")),
        "samples owner=%s/%s native=%s/%s matched=%s" % (
            summary.get("owner_parsed_count", 0),
            summary.get("owner_sample_count", 0),
            summary.get("native_parsed_count", 0),
            summary.get("native_sample_count", 0),
            summary.get("matched_comparison_count", 0),
        ),
        "timings owner_h3m=%ss native_amap=%ss total_parse=%ss" % (
            timings.get("owner_h3m_parse", 0),
            timings.get("native_amap_parse", 0),
            timings.get("total_parse", 0),
        ),
        "gaps parse=%s native_rules=%s density=%s policy=%s topology=%s coverage=%s" % (
            summary.get("parse_failure_count", 0),
            summary.get("native_rule_failure_count", 0),
            summary.get("density_gap_count", 0),
            summary.get("policy_gap_count", 0),
            summary.get("topology_gap_count", 0),
            summary.get("coverage_gap_count", 0),
        ),
        "closure_shape_gaps=%s" % summary.get("closure_shape_gap_count", 0),
    ]
    if inputs.get("native_artifact_autodiscovered", False):
        lines.append("artifact autodiscovered=true root=%s" % inputs.get("artifact_root", ""))
    elif inputs.get("latest_amap_artifact", False):
        lines.append("artifact autodiscovered=false error=%s" % inputs.get("native_artifact_discovery_error", ""))

    remaining = max(0, failure_limit)
    for bucket_id in ["parse", "native_rules", "density_gaps", "policy_gaps", "topology_gaps", "closure_shape_gaps", "coverage_gaps"]:
        bucket = failures.get(bucket_id, [])
        if not isinstance(bucket, list) or not bucket or remaining <= 0:
            continue
        lines.append("%s:" % bucket_id)
        for failure in bucket[:remaining]:
            lines.append("  %s" % json.dumps(failure, sort_keys=True))
        remaining -= min(remaining, len(bucket))
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--h3m-dir", "--owner-dir", dest="h3m_dir", type=Path, default=DEFAULT_OWNER_DIR, help="Owner H3M evidence directory")
    parser.add_argument("--amap-dir", "--native-dir", dest="amap_dir", type=Path, default=DEFAULT_NATIVE_DIR, help="Native .amap package directory")
    parser.add_argument("--density-floor-ratio", type=float, default=DEFAULT_DENSITY_FLOOR_RATIO, help="Minimum native object-density ratio against owner group baselines")
    parser.add_argument("--road-floor-ratio", type=float, default=DEFAULT_ROAD_FLOOR_RATIO, help="Minimum native road-density ratio against owner group baselines")
    parser.add_argument("--guard-reward-ratio-floor-ratio", type=float, default=DEFAULT_GUARD_REWARD_RATIO_FLOOR_RATIO, help="Minimum native guard/reward ratio against owner group baselines")
    parser.add_argument("--road-largest-share-multiplier", type=float, default=DEFAULT_ROAD_LARGEST_SHARE_MULTIPLIER, help="Maximum native largest road-component share as a multiple of the matched owner share")
    parser.add_argument("--road-largest-share-absolute-cap", type=float, default=DEFAULT_ROAD_LARGEST_SHARE_ABSOLUTE_CAP, help="Absolute cap for native largest road-component share")
    parser.add_argument("--road-component-count-floor-ratio", type=float, default=DEFAULT_ROAD_COMPONENT_COUNT_FLOOR_RATIO, help="Minimum native road-component count as a ratio of matched owner component count")
    parser.add_argument("--closure-shape-gate", action="store_true", help="Fail when owner evidence has guard-mediated town-route closures but native maps are closed by permanent blockers before guards matter")
    parser.add_argument("--guard-closure-min-owner-open-pair-count", type=int, default=DEFAULT_GUARD_CLOSURE_MIN_OWNER_OPEN_PAIR_COUNT, help="Minimum owner guard-closed town-pair count before closure-shape comparison is enforced")
    parser.add_argument("--no-density-gate", action="store_true", help="Report density metrics but do not fail on owner-density underfill")
    parser.add_argument("--no-policy-gate", action="store_true", help="Report policy metrics but do not fail on category, road, and guard/reward underfill")
    parser.add_argument("--no-topology-gate", action="store_true", help="Report road topology metrics but do not fail on road component shape gaps")
    parser.add_argument("--latest-amap-artifact", action="store_true", help="Validate against the newest .artifacts/rmg_native_batch_export* directory containing .amap files")
    parser.add_argument("--artifact-root", type=Path, default=DEFAULT_ARTIFACT_ROOT, help="Artifact root searched by --latest-amap-artifact")
    parser.add_argument("--require-all-owner-matches", action="store_true", help="Fail unless every parsed owner H3M has a matching parsed native AMAP")
    parser.add_argument("--allow-failures", action="store_true", help="Return success while still reporting parse/rule/density/policy failures")
    parser.add_argument("--summary", action="store_true", help="Print a compact human-readable summary instead of JSON")
    parser.add_argument("--failure-limit", type=int, default=8, help="Maximum individual failures to include in --summary output")
    parser.add_argument("--pretty", action="store_true", help="Pretty-print JSON")
    args = parser.parse_args()

    result = build_report(args)
    if args.summary:
        print(compact_summary(result, args.failure_limit))
    else:
        print(json.dumps(result, indent=2 if args.pretty else None, sort_keys=True))
    if result.get("status") == "pass" or args.allow_failures:
        return 0
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
