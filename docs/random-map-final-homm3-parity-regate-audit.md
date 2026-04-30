# Random Map Final HoMM3-Parity Re-Gate Audit

Status: final re-gate report with size-model follow-up note.
Date: 2026-04-30.
Slice: `random-map-final-homm3-parity-regate-audit-10184`.
Correction slice: `random-map-size-class-parity-correction-10184`.
Runtime-size follow-up: `random-map-extra-large-runtime-support-10184`.

## Decision

HoMM3-style random map generation parity, translated into AcOrP's original systems, is **met for the Phase 2 RMG parity gate with the corrected size-class model and the 2026-04-30 runtime-size follow-up below**.

This is not an alpha, release, campaign, faction-breadth, asset-parity, or byte-clone claim. It means the RMG workstream now satisfies the strict functional gate that the earlier final audit left open: parity-intended translated templates materialize and validate, final generated-map writeout/export/save/replay contracts are closed, player-facing setup/retry exists, and accepted original-game non-parity cases are explicit and defensible.

Post-gate update: the player-facing size model exposes HoMM3-style source classes explicitly: Small 36x36, Medium 72x72, Large 108x108, and Extra Large 144x144. The runtime-size follow-up lifts generated-map materialization through `144x144x2`, so all four exposed classes are selectable and materialize at source dimensions. No report, UI surface, save, replay, or provenance path may present a hidden clamp as full source-size output.

## Evidence Read

Primary source model:

- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generator-implementation-model.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generator-implementation-checklist.md`
- `docs/random-map-generator-foundation.md`
- `docs/random-map-homm3-parity-gap-audit.md`
- `docs/random-map-final-homm3-parity-gate-audit.md`

Fresh validation evidence from this re-gate:

- `python3 tests/validate_repo.py`: passed.
- `random_map_large_batch_parity_stress_report.tscn`: passed; `case_count=58`, `validation_pass_case_count=55`, `materialized_validation_pass_count=55`, `translated_template_count=53`, `covered_translated_template_count=53`, `translated_parity_materialized_validation_pass_count=51`, `accepted_non_parity_count=2`, `expected_negative_count=1`, `metadata_only_count=0`, `unsupported_warning_count=0`, `hard_blocker_count=0`.
- `random_map_final_writeout_export_save_schema_report.tscn`: passed; `final_tile_stream_count=468`, `object_writeout_count=78`, generated export signature `c4f0270e`, tile stream signature `5d212f8f`, object writeout signature `8c37e543`, replay boundary `versioned_seed_config_identity_export_stream_and_materialized_map_signature_contract`.
- `random_map_player_setup_retry_ux_report.tscn`: passed; generated setup selected `homm3_extra_large`, launch handoff produced Extra Large 144x144 provenance, and over-cap custom requests beyond `144x144x2` rejected without hidden downscale.
- `random_map_skirmish_ui_save_replay_report.tscn`: passed; generated skirmish launch uses v2 provenance, v2 replay boundary, no campaign/adopted authored writeback.
- `random_map_validation_batch_retry_report.tscn`: passed; `case_count=6`, `validation_pass_case_count=6`, `pass_after_retry_count=1`, retry evidence preserves the original failure.
- `random_map_playable_materialization_runtime_report.tscn`: passed; materialized Extra Large generated skirmish map reports `144x144`, includes `1263` object instances, `3` towns, `9` mines, `6` dwellings, `16` guards, `8` rewards, `2` overlay layers, save/restore, and export-stream replay boundary.

The Godot report runs still emit existing ContentService warnings for broad authored content families. They did not fail the RMG gates and are not counted as RMG parity blockers in this slice.

## Gate Matrix

| Area | Re-gate status | Evidence-backed finding |
|---|---|---|
| Translated-template breadth and grammar | Implemented | The stress corpus covers all 53 translated templates and all translated families. Parity-intended translated cases now materialize and validation-pass instead of relying on metadata-only or unsupported-warning success. |
| Template filtering and assignment | Implemented | Size/water/level/player filtering, owner/team metadata, faction assignment, rejection diagnostics, and generated identity survive through materialized stress cases and skirmish setup. |
| Zone layout and graph runtime | Implemented | Materialized cases carry phase signatures, route graph evidence, and runtime map signatures. Disconnected source graphs are accepted non-parity, not silent pass cases. |
| Water, underground, and transit gameplay | Implemented for parity gate | Stress coverage includes land, islands, and level counts `1` and `2`; validation batch coverage includes islands/water and underground deferred-transit tags. The gate accepts original transit equivalents and explicit policy diagnostics rather than requiring copied HoMM3 boat/portal assets. |
| Connection guards, wide links, and border semantics | Implemented | Stress coverage includes wide-link and border-guard tags. Guard materialization and diagnostics are validated in generated maps, while wide-link suppression remains a translated semantic, not corridor-width cloning. |
| Monster, reward, object-pool, and value weighting | Implemented | Object/value weighting is part of stress coverage, and playable materialization verifies guards, rewards, mines, dwellings, and object instances in runtime state. |
| Town, mine, and dwelling placement | Implemented | Materialized runtime and batch evidence verify player towns, seven-category mine equivalents, neutral dwellings, object footprints, and generated placement identity. |
| Route, guard, decoration, footprint, and writeout reliability | Implemented | Runtime materialization, validation batch, and final writeout reports verify object body/writeout, required phase statuses, route/guard coverage, overlays, and stable signatures. |
| Final writeout, export, save schema, and replay closure | Implemented | Generated exports now include standalone final tile streams, road/river/object writeout, multi-tile body completeness, v2 provenance, export-stream replay metadata, save/restore, and tampered export rejection without authored writeback. |
| Player-facing setup and retry UX | Implemented with corrected size boundary | Main-menu skirmish setup exposes generated-map controls including explicit size class, valid launch handoff, visible validation failure/retry exhaustion, and disabled launch on invalid generated setup without turning the menu into a report dashboard. Extra Large validation is covered by the runtime-size follow-up evidence. |
| Large-batch stress and retry determinism | Implemented | The stress run is deterministic across same inputs, changes signatures on changed cases, validates 55 materialized cases, preserves one expected negative, and records bounded retry/original failure evidence. |
| Campaign/writeback boundaries | Implemented as intentional non-parity | Generated maps remain skirmish-session scoped and do not write into authored scenarios or campaigns. This is a required original-game product boundary, not a missing parity feature. |

## Accepted Original-Game Non-Parity

The `2` accepted non-parity cases do not invalidate the gate because they are not parity-intended runtime templates being hidden as success:

1. Over-cap custom source requirements: AcOrP currently supports exposed generated source classes through `144x144x2`. Larger custom source requirements need a separate runtime-size slice and must fail validation rather than downscale.
2. Disconnected source graphs: AcOrP requires generated maps to expose reachable route graphs for runtime play. Disconnected source templates are preserved as source evidence and rejected or deferred until an explicit repair policy exists, rather than being counted as playable parity.
3. Campaign/writeback exclusion: HoMM3-style random-map parity for AcOrP is a generated skirmish/session feature. Not injecting generated maps into authored campaign JSON is a deliberate product boundary.
4. Save schema handling: Generated-map provenance and replay are versioned as v2 generated-map contracts within the current save version, with export signatures and tamper rejection. A global save-version bump is not required for this closure because restore validation proves the generated export contract.
5. Creative and asset translation: Source faction, town, object, terrain, and reward concepts are translated into original AcOrP ids and semantics. The gate does not require copied names, assets, maps, or byte-level HoMM3 map format cloning.

These decisions are translations or explicit runtime policy constraints. They do not require new RMG follow-up slices for this parity gate.

## Final Gate

The RMG parity queue can close for Phase 2 only with the size-class correction and Extra Large runtime-size support applied. The correct status is: HoMM3-style random-map-generation functional parity is met in AcOrP's original systems for generated skirmish/session use, with explicit non-parity boundaries for over-cap custom requests, disconnected source graphs, campaign/writeback exclusion, save-version policy, and creative originality.

Do not use this result to claim playable alpha, campaign readiness, release readiness, broad faction/content completion, or full product parity.
