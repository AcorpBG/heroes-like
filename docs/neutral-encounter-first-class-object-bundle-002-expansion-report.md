# Neutral Encounter First-Class Object Bundle 002 Expansion Report

Status: implementation evidence.
Date: 2026-04-27.
Slice: `neutral-encounter-object-migration-expansion-10184`.
Bundle id: `neutral_encounter_first_class_object_bundle_002`.

## Scope

This slice expanded first-class neutral encounter object metadata for a bounded set of three Reed Totemist objective placements:

| Scenario | Placement id | Encounter id | Object id |
| --- | --- | --- | --- |
| `river-pass` | `river_pass_reed_totemists` | `encounter_reed_totemists` | `object_neutral_encounter_river_pass_reed_totemists_stack` |
| `causeway-stand` | `causeway_levee_cutters` | `encounter_reed_totemists` | `object_neutral_encounter_causeway_levee_cutters_stack` |
| `stonewake-watch` | `stonewake_reed_totemists` | `encounter_reed_totemists` | `object_neutral_encounter_stonewake_reed_totemists_stack` |

The set was selected because the placements are already scenario objective encounters, reuse the same encounter definition, and benefit from explicit object/editor metadata without broad scenario churn.

## Implemented

- Added three `primary_class: "neutral_encounter"` map-object records.
- Added object-backed scenario placement bridges with stable `object_id`, deterministic `object_placement_id`, `encounter_ref`, `legacy_scenario_encounter_ref`, and `authored_metadata.bundle_id`.
- Added scenario-objective guard links that resolve through the existing scenario objective ids.
- Added shape-mask-friendly object metadata: `footprint`, `body_tiles`, and `approach` are separate. Each new stack uses one blocking body tile and a separate south adjacent visit tile.
- Tightened neutral encounter report/validator support for the declared bundle-002 records.

## Report Delta

After this slice:

- First-class neutral encounter map objects: `6`.
- Object-backed encounter placements: `6`.
- Lifted bundle-001 placements remain `3`.
- New non-lifted bundle-002 placements: `3`.
- Direct-only legacy-compatible placements: `42`.
- Missing object id/object placement id/object schema warning counts dropped from `45` to `42`.
- Missing guard target resolution remains `0`.

The bundle remains metadata-only. Runtime encounter resolution still uses legacy scenario encounter placements and current `placement_id` anchors.

## Deferred

No broad renderer import, sprite ingestion, save migration, `SAVE_VERSION` bump, wholesale scenario migration, AI behavior switch, runtime neutral encounter pathing adoption, rare-resource activation, or resource-id migration was performed. `wood` remains the only canonical wood resource id.

Recommended next P2.4 child: `overworld-object-ai-valuation-route-effects-10184`.
