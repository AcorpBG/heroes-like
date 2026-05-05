# Native RMG HoMM3 Roads Rivers Connections Report

Date: 2026-05-05
Slice: `native-rmg-homm3-roads-rivers-connections-10184`

## Scope

This slice implements the recovered post-town cleanup/connection payload handling boundary for the native RMG path. It uses recovered behavior and structure only: no HoMM3 art, names, maps, text, or binary map output are imported.

## Implemented

- Added a native late connection payload payload under `road_network.late_connection_payload_resolution`, generated after town/castle records exist.
- Required route links now report a corridor/path result through the road route graph, and connection payload validation fails explicitly if a required link has no corridor.
- `Wide` links now resolve as normal-guard suppression records with `normal_guard_value = 0`; they do not change corridor width.
- Border-guard links now materialize original gate records (`connection_gate_records`) with type-9-equivalent metadata and authored original object ids such as `object_charter_bar_gate`.
- Road and river records now expose deterministic overlay byte metadata separately from `rand_trn` decoration/object scoring.
- River generation now runs after the post-town connection payload stage and records road crossing metadata for land rivers.

## Boundaries

- No broad object placement pipeline was implemented.
- Mines/resources, reward placement, monster selection, and full guard/reward scaling remain later slices.
- Road and river renderer art was not changed.
- Generated records remain staged/package-surface metadata with no authored content writeback.

## Evidence

Focused report scene:

```text
GODOT_SILENCE_ROOT_WARNING=1 /root/.local/bin/godot --headless --path . --quit-after 120 tests/native_random_map_homm3_roads_rivers_connections_report.tscn
```

The report checks deterministic connection payload signatures, required-link corridor resolution, `Wide` suppression, original border-gate materialization, and road/river overlay metadata separation.
