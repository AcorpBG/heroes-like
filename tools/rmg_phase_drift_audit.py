#!/usr/bin/env python3
"""Classify native RMG drift by comparing H3M facts, private phases, and AMAP output."""

from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from pathlib import Path
from typing import Any

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

import rmg_fast_audit as fast_audit  # noqa: E402


DEFAULT_OUT_DIR = Path(".artifacts/rmg_h3m_native_phase_drift_audit")
DEFAULT_H3M = Path("maps/h3m-maps/S-RandomNumberofplayers.h3m")
DEFAULT_SNAPSHOT = DEFAULT_OUT_DIR / "phase_snapshot.json"


def get_path(source: dict[str, Any], path: str, default: Any = 0) -> Any:
    current: Any = source
    for part in path.split("."):
        if not isinstance(current, dict) or part not in current:
            return default
        current = current[part]
    return current


def as_int(value: Any, default: int = 0) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def parse_h3m_records(path: Path) -> list[dict[str, Any]]:
    data = fast_audit.load_bytes(path)
    width = fast_audit.u32(data, 5)
    level_count = 2 if len(data) > 9 and data[9] != 0 else 1
    metadata = fast_audit.load_object_metadata()
    for def_offset in fast_audit.find_object_definition_offsets(data):
        tile_offset = def_offset - width * width * level_count * fast_audit.H3M_TILE_BYTES_PER_CELL
        if tile_offset <= 0:
            continue
        templates = fast_audit.parse_h3m_object_templates(data, def_offset, metadata)
        if templates.get("status") != "parsed":
            continue
        objects = fast_audit.parse_h3m_object_instances(
            data,
            as_int(templates.get("next_offset")),
            templates["templates"],
            width,
            level_count,
        )
        if objects.get("status") == "parsed":
            return list(objects.get("records", []))
    return []


def h3m_detail(records: list[dict[str, Any]]) -> dict[str, Any]:
    type_counts: Counter[str] = Counter()
    category_counts: Counter[str] = Counter()
    subtype_counts: Counter[str] = Counter()
    for record in records:
        type_id = as_int(record.get("type_id"), -1)
        type_name = str(record.get("type_name", f"type_{type_id}"))
        category = fast_audit.h3m_category(record)
        type_counts[f"{type_id}:{type_name}"] += 1
        category_counts[category] += 1
        if category in {"reward", "town", "guard"}:
            subtype_counts[f"{type_id}:{as_int(record.get('subtype'), -1)}:{type_name}"] += 1
    return {
        "type_counts": dict(type_counts.most_common()),
        "category_counts": dict(sorted(category_counts.items())),
        "literal_artifact_count": sum(1 for record in records if as_int(record.get("type_id"), -1) == 5),
        "mine_like_count": sum(1 for record in records if "mine" in str(record.get("type_name", "")).lower()),
        "resource_like_count": sum(1 for record in records if "resource" in str(record.get("type_name", "")).lower()),
        "reward_subtype_counts": dict(subtype_counts.most_common(40)),
    }


def native_detail(amap_path: Path) -> dict[str, Any]:
    package = json.loads(amap_path.read_text())
    doc = package.get("document", package)
    objects = doc.get("objects", [])
    kind_counts = Counter(str(obj.get("kind", obj.get("native_record_kind", obj.get("category_id", "object")))) for obj in objects)
    object_id_counts = Counter(str(obj.get("object_id", obj.get("asset_id", ""))) for obj in objects)
    route_links = doc.get("route_graph", {}).get("links", [])
    road_records = doc.get("terrain_layers", {}).get("roads", [])
    return {
        "kind_counts": dict(sorted(kind_counts.items())),
        "top_object_ids": dict(object_id_counts.most_common(50)),
        "literal_artifact_count": int(kind_counts.get("artifact", 0)),
        "route_link_count": len(route_links),
        "road_record_count": len(road_records),
        "road_record_cell_count": sum(len(record.get("cells", [])) for record in road_records if isinstance(record, dict)),
    }


def compact_metrics(metrics: dict[str, Any]) -> dict[str, Any]:
    semantic = metrics.get("semantic_layout", {}) if isinstance(metrics.get("semantic_layout"), dict) else {}
    by_level = semantic.get("by_level", {}) if isinstance(semantic.get("by_level"), dict) else {}
    object_blocked = sum(as_int(level.get("object_blocked_tile_count")) for level in by_level.values() if isinstance(level, dict))
    guarded_blocked = sum(as_int(level.get("guarded_blocked_tile_count")) for level in by_level.values() if isinstance(level, dict))
    guard_controlled = sum(as_int(level.get("guard_controlled_tile_count")) for level in by_level.values() if isinstance(level, dict))
    return {
        "object_count": as_int(metrics.get("object_count")),
        "counts_by_category": metrics.get("counts_by_category", {}),
        "road_cell_count_total": as_int(metrics.get("road_cell_count_total")),
        "road_component_sizes_by_level": metrics.get("road_component_sizes_by_level", {}),
        "object_blocked_tile_count_total": object_blocked,
        "guarded_blocked_tile_count_total": guarded_blocked,
        "guard_controlled_tile_count_total": guard_controlled,
        "nearest_town_manhattan_min": as_int(semantic.get("nearest_town_manhattan_min")),
        "object_route_reachable_pair_count_total": as_int(semantic.get("object_route_reachable_pair_count_total")),
        "guarded_route_reachable_pair_count_total": as_int(semantic.get("guarded_route_reachable_pair_count_total")),
    }


def delta(owner: dict[str, Any], native: dict[str, Any], key: str) -> dict[str, int]:
    return {
        "owner": as_int(owner.get(key)),
        "native": as_int(native.get(key)),
        "delta": as_int(native.get(key)) - as_int(owner.get(key)),
    }


def category_delta(owner: dict[str, Any], native: dict[str, Any], category: str) -> dict[str, int]:
    owner_count = as_int(owner.get("counts_by_category", {}).get(category))
    native_count = as_int(native.get("counts_by_category", {}).get(category))
    return {"owner": owner_count, "native": native_count, "delta": native_count - owner_count}


def classify_private_vs_package(private_count: int, package_count: int, owner_count: int) -> str:
    if private_count == package_count and private_count != owner_count:
        return "native_private_phase_drift"
    if private_count != package_count:
        return "package_adaptation_drift"
    if private_count == owner_count == package_count:
        return "no_drift_detected"
    return "reference_alignment_unknown"


def finding(
    finding_id: str,
    metric: str,
    severity: str,
    classification: str,
    evidence: dict[str, Any],
    next_target: str,
) -> dict[str, Any]:
    return {
        "id": finding_id,
        "metric": metric,
        "severity": severity,
        "classification": classification,
        "evidence": evidence,
        "next_implementation_target": next_target,
    }


def load_controlled_manifest(path: Path | None) -> dict[str, Any] | None:
    if path is None:
        return None
    return json.loads(path.read_text())


def resolve_h3m_path(controlled_manifest: dict[str, Any] | None, h3m_path: Path | None) -> Path:
    if h3m_path is not None:
        return h3m_path
    if controlled_manifest and controlled_manifest.get("status") == "ready":
        output_path = get_path(controlled_manifest, "outputs.h3m_path", "")
        if output_path:
            return Path(str(output_path))
    return DEFAULT_H3M


def reference_alignment_finding(snapshot: dict[str, Any], h3m_path: Path, controlled_manifest: dict[str, Any] | None) -> dict[str, Any]:
    selection = snapshot.get("selection_identity", {}) if isinstance(snapshot.get("selection_identity"), dict) else {}
    config = snapshot.get("config", {}) if isinstance(snapshot.get("config"), dict) else {}
    player_constraints = config.get("player_constraints", {}) if isinstance(config.get("player_constraints"), dict) else {}
    native_identity = {
        "seed": str(config.get("seed", "")),
        "players": as_int(player_constraints.get("player_count")),
        "source_template_id": selection.get("source_template_id"),
        "source_catalog_index": selection.get("source_catalog_index"),
    }
    if controlled_manifest is None:
        return finding(
            "reference-alignment",
            "seed/template evidence",
            "critical",
            "reference_alignment_unknown",
            {
                "native_identity": native_identity,
                "owner_h3m_path": str(h3m_path),
                "source_kind": "shipped_h3m_uncontrolled",
                "reason": "The H3M file exposes final facts but not the original RMG RNG seed/template selection trace. Exact per-seed parity cannot be asserted without a controlled h3maped.exe manifest.",
            },
            "produce controlled h3maped.exe reference outputs with tools/rmg_h3maped_controlled_reference.py before accepting exact placement parity claims",
        )

    controlled_status = str(controlled_manifest.get("status", ""))
    controlled_identity = controlled_manifest.get("controlled_identity", {}) if isinstance(controlled_manifest.get("controlled_identity"), dict) else {}
    expected_identity = {
        "seed": str(controlled_identity.get("seed", get_path(controlled_manifest, "inputs.seed", ""))),
        "players": as_int(controlled_identity.get("players", get_path(controlled_manifest, "inputs.players", 0))),
        "source_template_id": controlled_identity.get("source_template_id"),
        "source_catalog_index": controlled_identity.get("source_catalog_index"),
    }
    evidence = {
        "native_identity": native_identity,
        "controlled_identity": expected_identity,
        "controlled_manifest_status": controlled_status,
        "controlled_manifest": controlled_manifest.get("output_dir", ""),
        "owner_h3m_path": str(h3m_path),
    }
    if controlled_status != "ready":
        evidence["blocker"] = controlled_manifest.get("blocker", controlled_manifest.get("error", "controlled manifest is not ready"))
        return finding(
            "reference-alignment",
            "seed/template evidence",
            "critical",
            "controlled_reference_blocked",
            evidence,
            "finish deterministic h3maped.exe reference generation through a committed runner before interpreting exact parity",
        )

    mismatches = {
        key: {"native": native_identity.get(key), "controlled": expected_identity.get(key)}
        for key in expected_identity
        if str(native_identity.get(key, "")) != str(expected_identity.get(key, ""))
    }
    evidence["mismatches"] = mismatches
    if mismatches:
        return finding(
            "reference-alignment",
            "seed/template evidence",
            "critical",
            "reference_alignment_mismatch",
            evidence,
            "rerun native generation and h3maped.exe reference with identical seed/player/template identity before interpreting deltas as parity drift",
        )
    return finding(
        "reference-alignment",
        "seed/template evidence",
        "info",
        "reference_alignment_pass",
        evidence,
        "interpret remaining deltas as same-identity native-vs-h3maped behavior drift",
    )


def build_report(snapshot: dict[str, Any], h3m_path: Path, amap_path: Path, controlled_manifest: dict[str, Any] | None = None) -> dict[str, Any]:
    owner_metrics = fast_audit.parse_h3m(h3m_path)
    native_metrics = fast_audit.load_amap(amap_path)
    owner_records = parse_h3m_records(h3m_path)
    owner_detail = h3m_detail(owner_records)
    native_extra = native_detail(amap_path)
    owner = compact_metrics(owner_metrics)
    native = compact_metrics(native_metrics)
    phase = snapshot.get("phase_summaries", {}) if isinstance(snapshot.get("phase_summaries"), dict) else {}
    package_phase = phase.get("public_package_adoption", {}) if isinstance(phase.get("public_package_adoption"), dict) else {}

    private_counts = {
        "town": as_int(get_path(phase, "town_castle_phase.project_town_record_candidate_count")),
        "player_start": as_int(get_path(phase, "town_castle_phase.project_player_start_candidate_count")),
        "neutral_town": as_int(get_path(phase, "town_castle_phase.project_neutral_town_candidate_count")),
        "mine": as_int(get_path(phase, "mines_rewards_and_object_vector.materialized_private_mine_coordinate_record_count")),
        "reward_coordinate": as_int(get_path(phase, "mines_rewards_and_object_vector.materialized_private_reward_coordinate_record_count")),
        "reward_lookup_selected": as_int(get_path(phase, "mines_rewards_and_object_vector.reward_object_lookup_selected_count")),
        "reward_candidate_scan_eligible": as_int(get_path(phase, "mines_rewards_and_object_vector.reward_candidate_scan_eligible_total")),
        "reward_coordinate_selected": as_int(get_path(phase, "mines_rewards_and_object_vector.reward_coordinate_selected_count")),
        "road_overlay_cells": as_int(get_path(phase, "roads_and_rivers.road_overlay_cell_count")),
        "road_coordinate_records": as_int(get_path(phase, "roads_and_rivers.generator_coordinate_record_count")),
        "road_pair_candidates": as_int(get_path(phase, "roads_and_rivers.pair_candidate_iteration_count")),
        "road_segments": as_int(get_path(phase, "roads_and_rivers.accepted_predecessor_chain_count")),
        "connection_blockers": as_int(get_path(phase, "connections_blockers_guards.private_blocker_cell_count")),
        "connection_guards": as_int(get_path(phase, "connections_blockers_guards.private_guard_record_count")),
        "decorative": as_int(get_path(phase, "decorative_obstacle_filler.private_decorative_obstacle_record_count")),
        "decorative_marked_body_cells": as_int(get_path(phase, "decorative_obstacle_filler.private_decorative_marked_body_cell_count")),
    }
    package_counts = {
        "town": as_int(package_phase.get("town_package_object_count", native.get("counts_by_category", {}).get("town", 0))),
        "mine": as_int(package_phase.get("mine_package_object_count", native_extra["kind_counts"].get("mine", 0))),
        "reward": as_int(package_phase.get("reward_package_object_count", native_extra["kind_counts"].get("reward_reference", 0))),
        "connection_blockers": as_int(package_phase.get("connection_blocker_package_object_count", native_extra["kind_counts"].get("connection_gate", 0))),
        "connection_guards": as_int(package_phase.get("connection_guard_package_object_count", native_extra["kind_counts"].get("route_guard", 0))),
        "decorative": as_int(package_phase.get("decorative_obstacle_package_object_count", native_extra["kind_counts"].get("decorative_obstacle", 0))),
        "road_tiles": as_int(package_phase.get("road_package_tile_count", native.get("road_cell_count_total", 0))),
        "road_segments": as_int(package_phase.get("road_package_segment_count", native_extra.get("road_record_count", 0))),
        "object_total": as_int(package_phase.get("package_object_count", native.get("object_count", 0))),
    }

    final_deltas = {
        "objects": delta(owner, native, "object_count"),
        "towns": category_delta(owner, native, "town"),
        "rewards": category_delta(owner, native, "reward"),
        "guards": category_delta(owner, native, "guard"),
        "decorative": category_delta(owner, native, "decoration"),
        "object_category": category_delta(owner, native, "object"),
        "road_unique_tiles": delta(owner, native, "road_cell_count_total"),
        "object_blocked_tiles": delta(owner, native, "object_blocked_tile_count_total"),
        "guarded_blocked_tiles": delta(owner, native, "guarded_blocked_tile_count_total"),
        "guard_controlled_tiles": delta(owner, native, "guard_controlled_tile_count_total"),
        "nearest_town_manhattan_min": delta(owner, native, "nearest_town_manhattan_min"),
        "object_route_reachable_pairs": delta(owner, native, "object_route_reachable_pair_count_total"),
        "guarded_route_reachable_pairs": delta(owner, native, "guarded_route_reachable_pair_count_total"),
        "literal_artifacts": {
            "owner": as_int(owner_detail.get("literal_artifact_count")),
            "native": as_int(native_extra.get("literal_artifact_count")),
            "delta": as_int(native_extra.get("literal_artifact_count")) - as_int(owner_detail.get("literal_artifact_count")),
        },
        "mine_like": {
            "owner": as_int(owner_detail.get("mine_like_count")),
            "native": as_int(native_extra["kind_counts"].get("mine")),
            "delta": as_int(native_extra["kind_counts"].get("mine")) - as_int(owner_detail.get("mine_like_count")),
        },
    }

    findings: list[dict[str, Any]] = []
    findings.append(reference_alignment_finding(snapshot, h3m_path, controlled_manifest))

    owner_towns = as_int(owner.get("counts_by_category", {}).get("town"))
    native_towns = as_int(native.get("counts_by_category", {}).get("town"))
    if owner_towns != native_towns:
        findings.append(
            finding(
                "town-count-and-placement",
                "town objects",
                "critical",
                classify_private_vs_package(private_counts["town"], package_counts["town"], owner_towns),
                {
                    "owner_town_count": owner_towns,
                    "native_town_count": native_towns,
                    "private_town_candidate_count": private_counts["town"],
                    "package_town_object_count": package_counts["town"],
                    "private_neutral_town_count": private_counts["neutral_town"],
                    "owner_nearest_town_manhattan_min": owner.get("nearest_town_manhattan_min"),
                    "native_nearest_town_manhattan_min": native.get("nearest_town_manhattan_min"),
                },
                "town_castle_phase 0x4a8d2c/0x4a8db2/0x4a93a2 scheduling plus zone-to-edge coordinate replay, not post-package count fitting",
            )
        )

    owner_mines = as_int(owner_detail.get("mine_like_count"))
    native_mines = as_int(native_extra["kind_counts"].get("mine"))
    if owner_mines != native_mines:
        findings.append(
            finding(
                "mine-density-overproduction",
                "mine-like objects",
                "high",
                classify_private_vs_package(private_counts["mine"], package_counts["mine"], owner_mines),
                {
                    "owner_mine_like_count": owner_mines,
                    "native_mine_count": native_mines,
                    "private_mine_coordinate_record_count": private_counts["mine"],
                    "package_mine_object_count": package_counts["mine"],
                },
                "mine_requirements_boundary 0x4a9911/0x4a9641 minimum+density loops and template row weighting",
            )
        )

    owner_rewards = as_int(owner.get("counts_by_category", {}).get("reward"))
    native_rewards = as_int(native.get("counts_by_category", {}).get("reward"))
    if owner_rewards != native_rewards or final_deltas["literal_artifacts"]["delta"] != 0:
        reward_classification = "native_private_phase_drift"
        if private_counts["reward_coordinate"] != package_counts["reward"] and private_counts["reward_coordinate"] > 0:
            reward_classification = "package_adaptation_drift"
        findings.append(
            finding(
                "reward-and-artifact-materialization",
                "rewards/artifacts/resources",
                "critical",
                reward_classification,
                {
                    "owner_reward_category_count": owner_rewards,
                    "native_reward_category_count": native_rewards,
                    "owner_literal_artifact_count": final_deltas["literal_artifacts"]["owner"],
                    "native_literal_artifact_count": final_deltas["literal_artifacts"]["native"],
                    "private_reward_lookup_selected_count": private_counts["reward_lookup_selected"],
                    "private_reward_candidate_scan_eligible_total": private_counts["reward_candidate_scan_eligible"],
                    "private_reward_coordinate_selected_count": private_counts["reward_coordinate_selected"],
                    "private_reward_coordinate_record_count": private_counts["reward_coordinate"],
                    "package_reward_object_count": package_counts["reward"],
                },
                "reward_scheduler_boundary and candidate_selector_boundary 0x4aa354/0x4a9f1c/0x4aa9b7 coordinate commit, including literal artifact/resource object selection",
            )
        )

    owner_roads = as_int(owner.get("road_cell_count_total"))
    native_roads = as_int(native.get("road_cell_count_total"))
    if owner_roads != native_roads:
        findings.append(
            finding(
                "road-overlay-overdraw",
                "road unique tiles and components",
                "critical",
                classify_private_vs_package(private_counts["road_overlay_cells"], package_counts["road_tiles"], owner_roads),
                {
                    "owner_road_unique_tiles": owner_roads,
                    "native_road_unique_tiles": native_roads,
                    "private_road_overlay_cell_count": private_counts["road_overlay_cells"],
                    "private_road_coordinate_record_count": private_counts["road_coordinate_records"],
                    "private_pair_candidate_iteration_count": private_counts["road_pair_candidates"],
                    "private_accepted_predecessor_chain_count": private_counts["road_segments"],
                    "package_road_tile_count": package_counts["road_tiles"],
                    "package_road_segment_count": package_counts["road_segments"],
                    "owner_road_components": owner.get("road_component_sizes_by_level"),
                    "native_road_components": native.get("road_component_sizes_by_level"),
                    "complete_executable_vector_claim": get_path(phase, "roads_and_rivers.complete_executable_vector_claim", None),
                },
                "roads_and_rivers 0x4ab52a coordinate vector population and pair acceptance, especially any mine/town endpoint over-inclusion",
            )
        )

    owner_guards = as_int(owner.get("counts_by_category", {}).get("guard"))
    native_guards = as_int(native.get("counts_by_category", {}).get("guard"))
    if owner_guards != native_guards:
        findings.append(
            finding(
                "guard-count-underproduction",
                "guard objects",
                "high",
                "native_private_phase_drift",
                {
                    "owner_guard_count": owner_guards,
                    "native_guard_count": native_guards,
                    "private_connection_guard_record_count": private_counts["connection_guards"],
                    "package_connection_guard_count": package_counts["connection_guards"],
                    "native_kind_counts": native_extra["kind_counts"],
                },
                "mine/reward guard writers plus connections_blockers_guards 0x4a79a3 family; split private guard production from package footprint adoption",
            )
        )

    if as_int(final_deltas["guard_controlled_tiles"]["delta"]) != 0 or as_int(final_deltas["object_blocked_tiles"]["delta"]) != 0:
        findings.append(
            finding(
                "blocker-and-guard-footprints",
                "blocked/control tiles",
                "critical",
                "package_adaptation_drift",
                {
                    "object_blocked_tile_delta": final_deltas["object_blocked_tiles"],
                    "guarded_blocked_tile_delta": final_deltas["guarded_blocked_tiles"],
                    "guard_controlled_tile_delta": final_deltas["guard_controlled_tiles"],
                    "private_connection_blocker_cell_count": private_counts["connection_blockers"],
                    "private_decorative_marked_body_cell_count": private_counts["decorative_marked_body_cells"],
                    "package_connection_blocker_count": package_counts["connection_blockers"],
                    "package_decorative_count": package_counts["decorative"],
                },
                "public_package_adoption object body/action masks; preserve recovered H3M passability/action masks instead of reducing objects to compact anchors",
            )
        )

    owner_decor = as_int(owner.get("counts_by_category", {}).get("decoration"))
    native_decor = as_int(native.get("counts_by_category", {}).get("decoration"))
    if owner_decor != native_decor:
        findings.append(
            finding(
                "decorative-density",
                "decorative obstacles",
                "medium",
                classify_private_vs_package(private_counts["decorative"], package_counts["decorative"], owner_decor),
                {
                    "owner_decoration_count": owner_decor,
                    "native_decoration_count": native_decor,
                    "private_decorative_obstacle_record_count": private_counts["decorative"],
                    "package_decorative_obstacle_count": package_counts["decorative"],
                    "decor_candidate_bit_26_count_before_filler": get_path(phase, "decorative_obstacle_filler.decor_candidate_bit_26_count_before_filler", 0),
                    "occupied_blocked_bit_27_count_before_filler": get_path(phase, "decorative_obstacle_filler.occupied_blocked_bit_27_count_before_filler", 0),
                },
                "generated_cell_decoration_bit_state and decorative_obstacle_filler 0x49dc9e/0x49eb8d/0x49e700 upstream candidate bits",
            )
        )

    report = {
        "schema_id": "rmg_h3m_native_phase_drift_audit_v1",
        "status": "fail" if any(item["classification"] != "no_drift_detected" for item in findings) else "pass",
        "inputs": {
            "phase_snapshot": str(snapshot.get("phase_snapshot_path", DEFAULT_SNAPSHOT)),
            "h3m": str(h3m_path),
            "amap": str(amap_path),
            "controlled_reference_manifest": str(controlled_manifest.get("output_dir", "")) if controlled_manifest else "",
        },
        "scope": "strict Small 36x36 one-level land; controlled h3maped manifest required for same-identity parity claims, shipped H3M allowed only as uncontrolled corpus sanity",
        "reference_alignment": findings[0],
        "final_deltas": final_deltas,
        "owner_metrics": owner,
        "native_metrics": native,
        "owner_detail": owner_detail,
        "native_detail": native_extra,
        "private_phase_counts": private_counts,
        "package_phase_counts": package_counts,
        "root_cause_findings": findings,
        "implementation_order": [
            "Bind comparison identity: generate controlled h3maped.exe reference outputs with seed/template metadata through a committed runner.",
            "Fix town/castle private scheduling and zone coordinate placement before object count tuning.",
            "Fix reward coordinate commit and artifact/resource materialization in the object vector phase.",
            "Fix road endpoint vector and pair acceptance; do not compensate in package serialization.",
            "Fix guard production and package body/action footprints from recovered object masks.",
            "Re-run this audit and the fresh H3M/native corpus comparison after each phase repair.",
        ],
    }
    return report


def write_markdown(report: dict[str, Any], path: Path) -> None:
    lines = [
        "# RMG Phase Drift Audit",
        "",
        f"- Status: `{report.get('status')}`",
        f"- Scope: {report.get('scope')}",
        f"- H3M: `{report['inputs']['h3m']}`",
        f"- AMAP: `{report['inputs']['amap']}`",
        "",
        "## Final Deltas",
        "",
    ]
    for key, value in report.get("final_deltas", {}).items():
        if isinstance(value, dict) and {"owner", "native", "delta"}.issubset(value.keys()):
            lines.append(f"- `{key}`: owner `{value['owner']}`, native `{value['native']}`, delta `{value['delta']}`")
    lines.extend(["", "## Root Cause Findings", ""])
    for item in report.get("root_cause_findings", []):
        lines.append(f"### {item['id']}")
        lines.append(f"- Classification: `{item['classification']}`")
        lines.append(f"- Severity: `{item['severity']}`")
        lines.append(f"- Metric: `{item['metric']}`")
        lines.append(f"- Next target: {item['next_implementation_target']}")
        lines.append("")
    lines.extend(["## Implementation Order", ""])
    for index, item in enumerate(report.get("implementation_order", []), start=1):
        lines.append(f"{index}. {item}")
    path.write_text("\n".join(lines) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--phase-snapshot", type=Path, default=DEFAULT_SNAPSHOT)
    parser.add_argument("--h3m", type=Path)
    parser.add_argument("--controlled-reference-manifest", type=Path)
    parser.add_argument("--amap", type=Path)
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT_DIR)
    parser.add_argument("--pretty", action="store_true")
    parser.add_argument("--fail-on-drift", action="store_true")
    args = parser.parse_args()

    snapshot = json.loads(args.phase_snapshot.read_text())
    controlled_manifest = load_controlled_manifest(args.controlled_reference_manifest)
    h3m_path = resolve_h3m_path(controlled_manifest, args.h3m)
    amap_path = args.amap or Path(str(snapshot.get("native_amap_path", "")))
    if not amap_path:
        parser.error("--amap is required when phase snapshot does not include native_amap_path")
    args.out_dir.mkdir(parents=True, exist_ok=True)
    report = build_report(snapshot, h3m_path, amap_path, controlled_manifest)
    json_path = args.out_dir / "phase_drift_report.json"
    md_path = args.out_dir / "phase_drift_report.md"
    json_path.write_text(json.dumps(report, indent=2 if args.pretty else None, sort_keys=True) + "\n")
    write_markdown(report, md_path)
    print(json.dumps({"status": report["status"], "json": str(json_path), "markdown": str(md_path)}, sort_keys=True))
    return 1 if args.fail_on_drift and report["status"] != "pass" else 0


if __name__ == "__main__":
    raise SystemExit(main())
