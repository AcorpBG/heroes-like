# Native RMG HoMM3 Object Placement Pipeline Report

Slice: `native-rmg-homm3-object-placement-pipeline-10184`
Status: implementation evidence

## Summary

This slice promotes the native RMG object-placement layer into an explicit shared
pipeline for supported original-content objects. It uses recovered HoMM3 RMG
behavior and structure only; no HoMM3 object names, art, DEF files, maps, text,
or binary writeout are imported.

Implemented behavior:

- Native output now advertises `native_random_map_homm3_object_placement_pipeline`.
- Every placed object record carries an original-content object definition id,
  footprint, passability mask, action mask, terrain constraints, type metadata,
  value/density metadata, writeout metadata, and no-authored-writeback policy.
- Mines and neutral dwellings now reserve their supported multi-tile body
  footprints in the shared occupancy index instead of reporting only an anchor
  tile.
- The object occupancy index validates unique primary and body tiles.
- Decorative filler is explicitly reported as ordinary object-template filler
  sourced from `rand_trn`-style proxy rows mapped to original authored blocker
  objects, not as a decoration super-type shortcut.
- Per-zone/global limit checks, local distribution counts, passability/action
  coverage, terrain/writeout coverage, and XL object-placement cost are exposed
  in `object_placement_pipeline_summary`.

## Evidence

Focused report scene:

```text
GODOT_SILENCE_ROOT_WARNING=1 /root/.local/bin/godot --headless --path . --quit-after 120 tests/native_random_map_homm3_object_placement_pipeline_report.tscn
```

The report validates medium and XL native generated maps for:

- original object definition coverage for resource sites, mines, dwellings,
  rewards, and decorative obstacles;
- footprint, passability/action, terrain, value/density, limit, occupancy, and
  writeout metadata on every placement;
- no duplicate body occupancy;
- decorative filler ordinary-template semantics;
- bounded XL object-placement cost summary. The current gate is a focused-report
  ceiling for the bounded native sampling path, not a release performance target.

## Boundaries

This slice does not claim exact HoMM3 object-table candidate scoring, DEF frame
dependencies, binary `.h3m` writeout, renderer art parity, or broad economy
rebalance. Existing Phase 3 mine/resource and guard/reward semantics remain in
place and continue to use original project content ids.
