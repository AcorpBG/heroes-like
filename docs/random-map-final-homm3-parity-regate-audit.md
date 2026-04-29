# Random Map Final HoMM3-Parity Re-Gate Audit

Status: final re-gate report with post-gate size-model correction note.
Date: 2026-04-29.
Slice: `random-map-final-homm3-parity-regate-audit-10184`.
Correction slice: `random-map-size-class-parity-correction-10184`.

## Decision

HoMM3-style random map generation parity, translated into AcOrP's original systems, is **met for the Phase 2 RMG parity gate only with the corrected size-class boundary below**.

This is not an alpha, release, campaign, faction-breadth, asset-parity, or byte-clone claim. It means the RMG workstream now satisfies the strict functional gate that the earlier final audit left open: parity-intended translated templates materialize and validate, final generated-map writeout/export/save/replay contracts are closed, player-facing setup/retry exists, and accepted original-game non-parity cases are explicit and defensible.

Post-gate correction: the player-facing size model must expose HoMM3-style source classes explicitly: Small 36x36, Medium 72x72, Large 108x108, and Extra Large 144x144. Current runtime materialization remains capped at `64x48x2`; therefore Small is currently materializable at source size, while Medium/Large/Extra Large are visible but unavailable until the cap is lifted and validated. No report or UI surface may present a capped map as a full 72/108/144 source-size map.

## Evidence Read

Primary source model:

- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generator-implementation-model.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generator-implementation-checklist.md`
- `docs/random-map-generator-foundation.md`
- `docs/random-map-homm3-parity-gap-audit.md`
- `docs/random-map-final-homm3-parity-gate-audit.md`

Fresh validation evidence from this re-gate:

- `python3 tests/validate_repo.py`: passed.
- `random_map_large_batch_parity_stress_report.tscn`: passed; `case_count=58`, `validation_pass_case_count=42`, `materialized_validation_pass_count=42`, `translated_template_count=53`, `covered_translated_template_count=53`, `translated_parity_materialized_validation_pass_count=38`, `accepted_non_parity_count=15`, `expected_negative_count=1`, `metadata_only_count=0`, `unsupported_warning_count=0`, `hard_blocker_count=0`.
- `random_map_final_writeout_export_save_schema_report.tscn`: passed; `final_tile_stream_count=468`, `object_writeout_count=78`, generated export signature `5658c458`, tile stream signature `3e6c77cb`, object writeout signature `e6440936`, replay boundary `versioned_seed_config_identity_export_stream_and_materialized_map_signature_contract`.
- `random_map_player_setup_retry_ux_report.tscn`: passed; setup exposes seed/size-class/template/profile/player/water/underground controls, HoMM3-style size options, honest Small 36x36 provenance, and bounded visible retry/oversized-size failure before launch.
- `random_map_skirmish_ui_save_replay_report.tscn`: passed; generated skirmish launch uses v2 provenance, v2 replay boundary, no campaign/adopted authored writeback.
- `random_map_validation_batch_retry_report.tscn`: passed; `case_count=6`, `validation_pass_case_count=6`, `pass_after_retry_count=1`, retry evidence preserves the original failure.
- `random_map_playable_materialization_runtime_report.tscn`: passed; materialized generated skirmish map includes `78` object instances, `3` towns, `9` mines, `6` dwellings, `16` guards, `8` rewards, `2` overlay layers, save/restore, and export-stream replay boundary.

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
| Player-facing setup and retry UX | Implemented with corrected size boundary | Main-menu skirmish setup exposes generated-map controls including explicit size class, valid launch handoff, visible validation failure/retry exhaustion, and disabled launch on invalid generated setup without turning the menu into a report dashboard. |
| Large-batch stress and retry determinism | Implemented | The stress run is deterministic across same inputs, changes signatures on changed cases, validates 42 materialized cases, preserves one expected negative, and records bounded retry/original failure evidence. |
| Campaign/writeback boundaries | Implemented as intentional non-parity | Generated maps remain skirmish-session scoped and do not write into authored scenarios or campaigns. This is a required original-game product boundary, not a missing parity feature. |

## Accepted Original-Game Non-Parity

The `15` accepted non-parity cases do not invalidate the gate because they are not parity-intended runtime templates being hidden as success:

1. Oversized source-template and source-size requirements: AcOrP currently caps materialized generated maps at `64x48x2`. Downscaling templates or player-selected Medium/Large/Extra Large source classes whose source size exceeds that cap would create false evidence. The translated records and source size classes are preserved and visible, but oversized classes are unavailable until the current original runtime cap is lifted and validated.
2. Disconnected source graphs: AcOrP requires generated maps to expose reachable route graphs for runtime play. Disconnected source templates are preserved as source evidence and rejected or deferred until an explicit repair policy exists, rather than being counted as playable parity.
3. Campaign/writeback exclusion: HoMM3-style random-map parity for AcOrP is a generated skirmish/session feature. Not injecting generated maps into authored campaign JSON is a deliberate product boundary.
4. Save schema handling: Generated-map provenance and replay are versioned as v2 generated-map contracts within the current save version, with export signatures and tamper rejection. A global save-version bump is not required for this closure because restore validation proves the generated export contract.
5. Creative and asset translation: Source faction, town, object, terrain, and reward concepts are translated into original AcOrP ids and semantics. The gate does not require copied names, assets, maps, or byte-level HoMM3 map format cloning.

These decisions are translations or explicit runtime policy constraints. They do not require new RMG follow-up slices for this parity gate.

## Final Gate

The RMG parity queue can close for Phase 2 only with the size-class correction applied. The correct status is: HoMM3-style random-map-generation functional parity is met in AcOrP's original systems for generated skirmish/session use, with explicit non-parity boundaries for oversized templates/source size classes, disconnected source graphs, campaign/writeback exclusion, save-version policy, and creative originality.

Do not use this result to claim playable alpha, campaign readiness, release readiness, broad faction/content completion, or full product parity.
