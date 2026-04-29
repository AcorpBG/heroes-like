# Random Map Final HoMM3-Parity Gate Audit

Status: final parity gate report; parity not met.
Date: 2026-04-29.
Slice: `random-map-final-homm3-parity-gate-audit-10184`.

## Decision

RMG parity is **not met**.

The completed Phase 2 RMG slices are substantial foundation work, but the final gate cannot count warning-class, metadata-only, deferred, unsupported, report-only, no-UI, no-durable-export, or unproven coverage as full parity. The parent `random-map-generator-foundation-10184` must remain open for the RMG parity queue.

The largest hard gate is the large-batch parity report itself: it passed as a diagnostic harness, but its successful result includes `38` metadata-only translated-template cases, `19` unsupported-warning cases, and `0` validation-pass cases across `58` expanded cases. That is honest evidence that the translated catalog is represented, not evidence that all template families materialize into validated playable maps.

## Evidence Read

Primary HoMM3 model inputs:

- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generator-implementation-model.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generator-implementation-checklist.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/rmg-template-catalog.json`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/rmg-template-summary.csv`

Current implementation and validation evidence:

- `content/random_map_template_catalog.json`
- `content/random_map_template_import_summary.json`
- `scripts/core/RandomMapGeneratorRules.gd`
- `scripts/core/ScenarioSelectRules.gd`
- `docs/random-map-generator-foundation.md`
- `docs/random-map-homm3-parity-gap-audit.md`
- `tests/random_map_*_report.gd` and focused report scenes

Focused audit runs:

- `random_map_large_batch_parity_stress_report.tscn`: pass as report; `case_count=58`, `metadata_only_count=38`, `unsupported_warning_count=19`, `validation_pass_case_count=0`, `hard_blocker_count=0`.
- `random_map_water_underground_transit_gameplay_report.tscn`: pass; water transit count `4`, underground cross-level link count `8`, `final_art_autotile_polish=deferred`.
- `random_map_playable_materialization_runtime_report.tscn`: pass; compact skirmish materialization summary includes `78` object instances, `3` towns, `9` mines, `6` dwellings, `16` guards, `8` rewards, `2` overlay layers; replay boundary is seed/config identity only, not full input-stream replay.
- `random_map_object_pool_value_weighting_report.tscn`: pass; compact case has `66` selected candidates and value/fairness summaries.
- `random_map_validation_batch_retry_report.tscn`: pass as report; `case_count=6`, `validation_pass_case_count=2`, `expected_validation_fail_case_count=4`, `pass_after_retry_count=1`.

## Gate Matrix

| Area | Gate status | Audit finding |
|---|---|---|
| Template breadth and grammar | Partial | All 53 extracted templates are imported into the original catalog and source creative names are not retained. However, the large-batch sweep marks most translated families as metadata-only, and catalog/runtime records still expose `unsupported_runtime_fields` / `preserved_not_fully_consumed` grammar. Metadata preservation is not runtime parity. |
| Template filtering and assignment | Partial | Size, water, player filters, capacity checks, team/free-for-all metadata, owner slots, and faction selection exist for supported profiles. Full materialized assignment across all 1-8 player translated families is unproven because translated-template sweep cases do not materialize. |
| Zone layout | Partial | Runtime zone graph and deterministic footprint layout exist for compact/materialized cases. The gate remains partial because disconnected source graphs are preserved as unsupported warnings and broad translated-family layout is not proven by validated playable generation. |
| Terrain, water, underground, and transit | Partial | Water/island and underground gameplay reports prove deterministic materialized transit summaries for focused cases. Parity remains blocked by deferred final art/autotile polish, no full boat/shipyard/ferry/key transit system, no broad translated-family materialization, and no durable tile writeout proof. |
| Connection guards, wide links, and border semantics | Partial | Link payloads, wide suppression semantics, border-guard equivalents, guard records, and diagnostics exist in compact cases. Full parity is not proven across all wide/border source templates, and special guard/key/gate/final object writeout remains incomplete. |
| Monster and reward bands | Partial | Guard/reward band staging, value classes, faction fallback diagnostics, and compact runtime references exist. The gate remains partial because true full monster selection/scaling across all source masks, all template bands, and all generated map sizes is not proven. |
| Decoration and object placement | Partial | Terrain-biased decoration density and object footprint records exist for supported maps. HoMM3-style decoration/object placement parity remains partial because final object stamping/writeout, broad obstacle-table breadth, final multi-tile body semantics, and full translated-family density are not proven. |
| Object pool and value weighting | Partial | The compact object-pool report validates deterministic selected candidates, value totals, pool limits, and fairness deltas. It cannot count as full parity while translated families are metadata-only or unsupported, and while final export/writeout remains staged. |
| Town, mine, and dwelling placement | Partial | Compact materialized maps contain towns, seven-category mine equivalents, and neutral dwellings. Full template-driven minimum/density placement across all translated templates, all sizes, rare-resource breadth, same-type neutral breadth, and broad fairness validation remain unproven. |
| Roads, rivers, and writeout | Partial / blocked for parity | Road and river overlays plus serialization-like records exist. The implementation still records staged overlay/no final tile-byte writeout and deferred multi-tile/object-instance state. No durable generated file export or final map-structure round trip is proven. |
| Playable runtime materialization | Partial | A compact generated map can launch as a skirmish session and survive bounded runtime/save checks. This is not parity because runtime materialization is not proven for the translated catalog, water/underground broad cases, or large-batch cases. |
| Skirmish setup, save, and replay provenance | Partial | `ScenarioSelectRules` can build/start generated skirmish sessions and preserve seed/config/materialized identity. It explicitly uses `runtime_materialization_signature_preserved_without_save_version_bump` and `seed_config_and_materialized_map_identity_preserved_no_input_stream_replay_yet`, so save/schema/replay parity is incomplete. |
| Large-batch reliability | Blocked for parity | The large-batch report is valuable and deterministic, but its success is diagnostic success. It contains `38` metadata-only cases, `19` unsupported warnings, `20` original failures, and `0` validation-pass cases. That is not parity reliability. |
| UI and user-facing setup/retry UX | Blocked | Report-level setup/retry handoffs exist, but there is no completed player-facing random-map setup menu, visible retry/error UX, or browser integration that satisfies parity. |
| Campaign and writeback boundaries | Implemented as intentional non-parity | Generated maps correctly avoid campaign adoption and authored content writeback by default. This is an accepted original-game boundary, not a missing campaign feature. It does not substitute for durable export/save-schema parity. |
| Save/schema/export boundaries | Partial / blocked for parity | Runtime save provenance exists without a save-version bump. Durable generated scenario export, final map file/writeout, editor round-trip, and full replay contract remain unproven. |

## Blockers

1. Materialized parity coverage is not broad enough. The translated 53-template catalog is represented, but most sweep cases are metadata-only and current unsupported warnings remain accepted diagnostic evidence.
2. Final map writeout is not closed. Roads, rivers, terrain bytes, object instances, multi-tile bodies, and export/round-trip behavior remain staged or deferred.
3. Player-facing parity is not closed. Skirmish setup exists as rules/report/session plumbing, but not as a complete user-facing random-map setup and retry flow.
4. Save/replay parity is not closed. Current provenance preserves seed/config/materialized identity without a save-version bump and without full input-stream replay.

## Follow-Up Slices

The following RMG-only follow-ups are required before another parity claim can be audited:

1. `random-map-translated-template-runtime-sweep-10184` - convert the translated-template large-batch sweep from metadata-only/unsupported evidence into materialized generated maps, or explicit accepted non-parity decisions for individual template families.
2. `random-map-final-writeout-export-save-schema-10184` - close final tile/object/road/river writeout, generated export/round-trip, save-schema, and replay contract gaps.
3. `random-map-player-facing-setup-retry-ux-10184` - implement real player-facing random-map setup, validation failure, and retry UX without campaign adoption or authored content writeback.

## Final Gate

Do not claim HoMM3-style RMG parity for AcOrP yet. The correct status is: strong Phase 2 RMG foundation with compact playable materialization and useful report harnesses, but parity remains blocked by broad materialized coverage, final writeout/export/save schema, and player-facing setup/retry UX.
