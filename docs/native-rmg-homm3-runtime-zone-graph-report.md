# Native RMG HoMM3 Runtime Zone Graph Report

Date: 2026-05-05
Slice: `native-rmg-homm3-runtime-zone-graph-10184`

## Scope

This slice replaces the catalog-template zone layout path with runtime template/zone graph construction before terrain, roads, guards, rewards, or object placement consume the map. It uses recovered HoMM3 RMG structure only as engineering reference and keeps output in original game content.

## Implemented

- Added native runtime zone graph records under `zone_layout.runtime_zone_graph` with source template/profile ids, source zone ids, source roles, base sizes, target areas, owner/player/faction choices, terrain/town/mine/treasure/monster rule payloads, adjacency, and per-zone diagnostics.
- Added runtime link records preserving endpoints, roles, raw guard values, `wide`, `border_guard`, road policy, and guard policy before later connection slices materialize roads/guards.
- Replaced catalog-template surface ownership from the old weighted nearest-seed owner grid with a deterministic target-area flood fill. Target areas are normalized from `base_size` and validated against actual generated zone cells.
- Added explicit runtime graph validation for connected playable graphs, endpoint resolution, start/neutral counts, target-area totals, wide-link counts, and diagnostics for unsupported/inactive player filters.
- Routed native road graph construction through `runtime_zone_graph.links` when available, while preserving the existing foundation fallback path for non-catalog templates.
- Added focused Godot report `tests/native_random_map_homm3_runtime_zone_graph_report.gd/.tscn`.

## Evidence

Focused fixture: `frontier_spokes_v1` / `frontier_spokes_profile_v1`, small land, 3 players.

Observed report facts:

- Runtime graph schema: `aurelion_native_rmg_runtime_zone_graph_v1`.
- Zone status: `zones_generated_runtime_template_graph`.
- Zones: 7, links: 9.
- Start zones: 3; neutral zones: 4.
- Target area sum: 1296; generated cell sum: 1296.
- Wide links: 1; border-guard links: 0.
- Route graph source link model: `runtime_template_zone_graph_links`.
- Runtime graph validation: `pass`.

## Remaining Boundaries

Exact HoMM3 zone footprint heuristics, terrain/island painting, road/river corridor materialization, special guard placement, and full object placement remain deferred to the later Phase 3 slices. The runtime graph now preserves the source semantics those slices need to consume.
