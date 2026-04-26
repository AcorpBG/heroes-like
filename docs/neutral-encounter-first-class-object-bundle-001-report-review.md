# Neutral Encounter First-Class Object Bundle 001 Report Review

Status: completed review, documentation only.
Date: 2026-04-26.
Slice: neutral-encounter-first-class-object-bundle-report-review-10184.
Bundle id: `neutral_encounter_first_class_object_bundle_001`.

## Purpose

Review the opt-in neutral encounter report after the metadata-only first-class object-backed bundle implementation for the three authored bundle-001 placements.

This review does not approve broader production JSON migration, validator/test implementation, runtime encounter behavior changes, pathing/body-tile/approach adoption, AI behavior changes, editor behavior changes, renderer behavior changes, save behavior changes, generated PNG import, or asset import.

## Reviewed Inputs

- `project.md`
- `PLAN.md`
- `ops/progress.json`
- `ops/acorp_attention.md`
- `docs/neutral-encounter-first-class-object-bundle-001-plan.md`
- `docs/neutral-encounter-first-class-object-report-review.md`
- `content/scenarios.json` only for `river_pass_ghoul_grove`, `river_pass_hollow_mire`, and `ninefold_basalt_gatehouse_watch`
- `content/map_objects.json` only for the three neutral encounter object records
- `tests/validate_repo.py` neutral encounter report, first-class object bundle validation, and overworld object report sections
- `python3 tests/validate_repo.py --neutral-encounter-report`
- `python3 tests/validate_repo.py --neutral-encounter-report-json /tmp/heroes-neutral-encounter-report.inspect.json`

Report schema: `neutral_encounter_report_v1`.
Report mode: `compatibility_report`.

## Report Output

The report reflects the intended metadata-only lift: the three planned placements are now object-backed and lifted from the earlier scenario-placement metadata bundle, while the other direct encounter placements remain compatibility-warning-only.

Core counts:

| Surface | Count |
| --- | ---: |
| Scenarios | 15 |
| Encounter definitions | 62 |
| Direct scenario encounter placements | 48 |
| Script-spawn advisory encounter effects | 36 |
| First-class neutral encounter map objects | 3 |
| Authored bundle metadata placements | 3 |

Placement authority:

| Authority | Count |
| --- | ---: |
| `direct_only` | 45 |
| `scenario_metadata` | 0 |
| `object_backed` | 0 |
| `object_backed_lifted` | 3 |

First-class object migration counts:

| Report field | Count |
| --- | ---: |
| Object-backed placements | 3 |
| Lifted records | 3 |
| Missing `object_id` | 45 |
| Missing `object_placement_id` | 45 |
| Missing lifted metadata agreement | 0 |
| Missing guard target resolution | 0 |
| Missing object schema field records | 45 |

Missing object schema field counts remain compatibility warnings on the 45 unmigrated direct placements:

| Object schema field | Missing count |
| --- | ---: |
| `schema_version` | 45 |
| `primary_class` | 45 |
| `secondary_tags` | 45 |
| `footprint` | 45 |
| `passability_class` | 45 |
| `interaction` | 45 |
| `neutral_encounter` | 45 |

Warnings/errors:

| Report output | Count |
| --- | ---: |
| Warnings | 542 |
| Errors | 0 |

The warning reduction is the expected delta from the prior first-class object report review: the three lifted placements no longer count as missing object ids, object placement ids, or first-class object schema fields.

## Bundle Status

`neutral_encounter_first_class_object_bundle_001` is reported as:

| Field | Value |
| --- | --- |
| `status` | `metadata_authored` |
| `production_json_migration` | `true` |
| `production_json_migration_scope` | `metadata_only_first_class_object_records` |
| `placement_count` | `3` |
| `runtime_adoption` | `not_active` |
| `pathing_occupancy_adoption` | `false` |
| `renderer_adoption` | `false` |
| `ai_behavior_switch` | `false` |
| `editor_behavior_switch` | `false` |
| `save_migration` | `false` |
| Bundle warnings | none |

This is still metadata only. Runtime encounter resolution remains on the legacy direct scenario encounter placements and existing placement ids.

## Source Preservation

The three scenario bridge metadata records preserve the planned ids and legacy encounter placement fields:

| Scenario | Placement id | Encounter id | Coordinates | Difficulty | Combat seed | Object id | Object placement id |
| --- | --- | --- | ---: | --- | ---: | --- | --- |
| `river-pass` | `river_pass_ghoul_grove` | `encounter_ghoul_grove` | `3,1` | `low` | 1201 | `object_neutral_encounter_river_pass_ghoul_grove_stack` | `object_placement_river_pass_ghoul_grove` |
| `river-pass` | `river_pass_hollow_mire` | `encounter_hollow_mire` | `6,4` | `medium` | 1202 | `object_neutral_encounter_river_pass_hollow_mire_stack` | `object_placement_river_pass_hollow_mire` |
| `ninefold-confluence` | `ninefold_basalt_gatehouse_watch` | `encounter_basalt_gatehouse_watch` | `60,52` | `high` | 16406 | `object_neutral_encounter_ninefold_basalt_gatehouse_watch_stack` | `object_placement_ninefold_basalt_gatehouse_watch` |

Each bridge record keeps:

- The legacy `placement_id`, `encounter_id`, `x`, `y`, `difficulty`, and `combat_seed`.
- `legacy_scenario_encounter_ref` back to `scenarios.encounters`.
- `encounter_ref` agreement with the direct placement encounter, difficulty, combat seed, and field-objective source.
- `authored_metadata.bundle_id: "neutral_encounter_first_class_object_bundle_001"`.
- `authored_metadata.lifted_from_bundle_id: "neutral_encounter_representation_bundle_001"`.

The three object records preserve the planned object schema fields:

| Object id | `primary_class` | `family` | `subtype` | Footprint | Passability | Interaction |
| --- | --- | --- | --- | --- | --- | --- |
| `object_neutral_encounter_river_pass_ghoul_grove_stack` | `neutral_encounter` | `neutral_encounter` | `visible_stack` | 1x1 `bottom_center` `micro` | `neutral_stack_blocking` | one-time, clears, no revisit |
| `object_neutral_encounter_river_pass_hollow_mire_stack` | `neutral_encounter` | `neutral_encounter` | `visible_stack` | 1x1 `bottom_center` `micro` | `neutral_stack_blocking` | one-time, clears, no revisit |
| `object_neutral_encounter_ninefold_basalt_gatehouse_watch_stack` | `neutral_encounter` | `neutral_encounter` | `guard_linked_stack` | 1x1 `bottom_center` `micro` | `neutral_stack_blocking` | one-time, clears, no revisit |

The object `neutral_encounter` metadata matches the lifted scenario metadata for representation, guard link, state model, placement ownership, reward summary, passability, AI hints, and editor placement placeholders.

## Guard-Target Resolution

Basalt gatehouse guard-target resolution is confirmed. The lifted scenario bridge, object metadata, and report agree on:

| Field | Value |
| --- | --- |
| `guard_role` | `guards_resource_node` |
| `target_kind` | `resource_node` |
| `target_id` | `site_basalt_gatehouse` |
| `target_placement_id` | `dwelling_basalt_gatehouse` |
| `blocks_approach` | `true` |
| `clear_required_for_target` | `true` |

In `ninefold-confluence`, the scenario resource node `dwelling_basalt_gatehouse` resolves to `site_basalt_gatehouse`. The report has `missing_guard_target_resolution_count: 0`.

The route-link case `river_pass_hollow_mire` remains advisory metadata only with `target_kind: "route"` and `target_id: "river_pass_mire_lane"`; it does not switch pathing behavior.

## Validation Policy

Compatibility-warning-only remains:

- The 45 production direct encounter placements outside `neutral_encounter_first_class_object_bundle_001`.
- Missing `object_id`, `object_placement_id`, and first-class object schema fields on those 45 placements.
- Inferred `visible_stack` representation and inferred `none_inferred` guard links for unmigrated direct placements.
- Repeated encounter ids, script-spawn advisory effects, placement field-objective overrides, and definition-backed field objectives.
- Future `body_tiles`, approach offsets, route effects, animation cue ids, renderer hints, AI adoption, editor adoption, pathing adoption, and save migration.

Strict production checks currently cover:

- `neutral_encounter_representation_bundle_001` scenario-placement metadata for the three source placements.
- `neutral_encounter_first_class_object_bundle_001` object-backed metadata for the same three placements.
- The planned object ids and object placement ids.
- Legacy placement bridge agreement.
- Encounter ref agreement and field-objective source preservation.
- Lifted metadata agreement with `neutral_encounter_representation_bundle_001`.
- Object schema fields: `schema_version`, `primary_class`, `secondary_tags`, `footprint`, `passability_class`, `interaction`, and `neutral_encounter`.
- Guard-link agreement and basalt resource-node target resolution.
- Rejection of undeclared production `primary_class: "neutral_encounter"` map objects or undeclared object-backed scenario placements outside the bundle.

Strict fixture-only remains:

- Broader valid object-backed shapes for `visible_stack`, `camp_anchor`, `guard_linked_stack`, and `guard_linked_camp`.
- Invalid object-backed authority/link cases for missing object ids, missing legacy placement bridge, missing encounter refs, field-objective source mismatch, guard-target mismatch, and duplicate authority disagreement.

## Recommendation

Pause neutral encounter metadata migration after this review and return to broader foundation/game-loop planning.

Rationale:

- The tiny object-backed bundle has proven the planned boundary: object ids, scenario bridge metadata, lifted agreement, guard-target resolution, and strict production checks all work for the declared records.
- Another tiny bundle would mostly reduce compatibility warnings without advancing runtime, pathing, renderer, AI, editor, save, or player-facing behavior.
- `body_tiles` and approach planning should happen as part of a broader object/pathing/editor adoption plan, not as a neutral-encounter-only patch.
- The project direction is deep production foundation, so the next useful slice should reassess broader foundation/game-loop priorities before further JSON migration.

Recommended next slice: `foundation-game-loop-prioritization-10184`.

Scope:

- Review the current foundation state after economy/object/neutral metadata scaffolding.
- Decide whether the next implementation track should prioritize economy capture loops, object/pathing/editor adoption, strategic AI turn pressure, or a live-client game-loop proof.
- Keep the existing 45 neutral encounter compatibility warnings accepted until a later bundle has a player-facing or tooling reason to migrate.

Still out of scope for the next slice unless explicitly replanned:

- Broad production neutral encounter migration.
- Runtime encounter behavior changes.
- Pathing/body-tile/approach adoption.
- Renderer, AI, editor, or save adoption.
- Generated PNG import or asset import.

GitHub auth remains blocked; keep work local and do not push.
