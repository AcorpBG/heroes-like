# Native RMG HoMM3 Generator Data Model Report

Date: 2026-05-05
Slice: `native-rmg-homm3-generator-data-model-10184`

## Scope

This slice adds a reusable, original-content data model for the Phase 3 native RMG rewrite. It is a data/model and validation gate only. It does not replace the runtime zone graph, terrain/island shaping, roads/rivers, object placement pipeline, guard/reward algorithms, or package adoption gates.

## Implemented

- Added `content/random_map_generator_data_model.json` with source-backed model surfaces for templates, runtime zones, links, generated cells, object type metadata, object definitions, validation results, compatibility gates, and explicit unsupported parity boundaries.
- Added native validation/report plumbing in `src/gdextension/src/rmg_data_model.cpp`, exposed through `MapPackageService.inspect_random_map_generator_data_model()`.
- Kept existing `generate_random_map()` and `convert_generated_payload()` surfaces unchanged; the new model is report-only and gated for later Phase 3 adoption.
- Added `tests/native_random_map_homm3_generator_data_model_report.gd/.tscn` to validate the model, template catalog metrics, generated object definition coverage, explicit unsupported boundaries, and package compatibility.

## Remaining Phase 3 Boundaries

The model explicitly defers exact zone footprint heuristics, terrain art/flip byte parity, full object placement, guard/reward strength formula adoption, and binary `.h3m` writeout. Those remain owned by later Phase 3 child slices in `PLAN.md`.
