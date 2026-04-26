# Neutral Encounter First-Class Object Report Review

Status: completed review, documentation only.
Date: 2026-04-26.
Slice: neutral-encounter-first-class-object-report-review-10184.

## Purpose

Review the updated opt-in neutral encounter report and strict fixture output after first-class object report scaffolding.

This review does not approve production JSON migration, validator/test implementation, runtime encounter behavior changes, pathing/body-tile/occupancy changes, AI behavior changes, editor behavior changes, renderer behavior changes, save migration, generated PNG import, or asset import.

## Reviewed Inputs

- `project.md`
- `PLAN.md`
- `ops/progress.json`
- `ops/acorp_attention.md`
- `docs/neutral-encounter-first-class-object-migration-plan.md`
- `docs/neutral-encounter-representation-bundle-001-report-review.md`
- `tests/validate_repo.py` neutral encounter report and strict fixture sections
- `tests/fixtures/neutral_encounter_schema/strict_cases.json`
- `python3 tests/validate_repo.py --neutral-encounter-report`
- `python3 tests/validate_repo.py --neutral-encounter-report-json /tmp/heroes-neutral-encounter-report.inspect.json`
- `python3 tests/validate_repo.py --strict-neutral-encounter-fixtures`

Report schema: `neutral_encounter_report_v1`.
Report mode: `compatibility_report`.

## Current Report Output

The report is behaving as intended for the current production state: direct scenario encounter placements remain the authority, three placements have authored scenario metadata, and no object-backed neutral encounter placement has been migrated.

Core counts:

| Surface | Count |
| --- | ---: |
| Scenarios | 15 |
| Encounter definitions | 62 |
| Direct scenario encounter placements | 48 |
| Script-spawn advisory encounter effects | 36 |
| First-class neutral encounter map objects | 0 |
| Authored `neutral_encounter_representation_bundle_001` metadata placements | 3 |

Placement authority:

| Authority | Count |
| --- | ---: |
| `direct_only` | 45 |
| `scenario_metadata` | 3 |
| `object_backed` | 0 |
| `object_backed_lifted` | 0 |

First-class object migration counts:

| Report field | Count |
| --- | ---: |
| Object-backed placements | 0 |
| Lifted records | 0 |
| Missing `object_id` | 48 |
| Missing `object_placement_id` | 48 |
| Missing lifted metadata agreement | 0 |
| Missing guard target resolution | 0 |
| Missing object schema fields | 48 |

Missing object schema field counts:

| Object schema field | Missing count |
| --- | ---: |
| `schema_version` | 48 |
| `primary_class` | 48 |
| `secondary_tags` | 48 |
| `footprint` | 48 |
| `passability_class` | 48 |
| `interaction` | 48 |
| `neutral_encounter` | 48 |

Warnings/errors:

| Report output | Count |
| --- | ---: |
| Warnings | 553 |
| Errors | 0 |

The warning increase from the previous authored-bundle review is expected. The report now adds first-class object migration warnings for missing object identifiers and object-schema records while keeping those warnings non-blocking for current production content.

## Guard-Target Resolution

The report shows `0` missing guard target resolutions. That does not mean all encounters have fully migrated target links. It means no current placement that requires object-level guard-target resolution is unresolved in this report state.

The authored basalt gatehouse link remains the validated compatibility example:

| Field | Value |
| --- | --- |
| `target_kind` | `resource_node` |
| `target_id` | `site_basalt_gatehouse` |
| `target_placement_id` | `dwelling_basalt_gatehouse` |

Direct-only and scenario-metadata placements without first-class object records should keep this as advisory/report-level validation. Runtime target availability, pathing, renderer behavior, editor links, and AI scoring remain inactive.

## Bundle 001 Relationship

`neutral_encounter_representation_bundle_001` remains authored as scenario-placement metadata only. It is not an object-backed bundle yet.

Current relationship:

- `river_pass_ghoul_grove`, `river_pass_hollow_mire`, and `ninefold_basalt_gatehouse_watch` keep their authored `neutral_encounter` metadata on direct scenario encounter placements.
- Those three records are the best candidates for a future planning-only first-class object bundle because they already exercise two `visible_stack` placements and one `guard_linked_stack` placement.
- A future object-backed planning bundle should lift the existing metadata exactly, preserve `placement_id` and `encounter_id`, add proposed `object_id` and `object_placement_id`, and explicitly record `lifted_from_bundle_id: "neutral_encounter_representation_bundle_001"`.
- Do not create object-backed production records merely to reduce the `553` warnings. The next bundle must prove the object boundary: object identifiers, placement bridge, lifted agreement, object schema fields, and guard-target convention.

## Strict Fixture Coverage

Strict fixture validation remains isolated under `tests/fixtures/neutral_encounter_schema/strict_cases.json`.

Existing representation fixtures:

| Fixture group | Count |
| --- | ---: |
| Fixture encounter definitions | 4 |
| Valid scenario-metadata neutral encounter records | 4 |
| Valid object-backed neutral encounter records | 4 |
| Invalid scenario-metadata neutral encounter records | 12 |
| Invalid object-backed neutral encounter records | 6 |

Object-backed valid coverage:

| Fixture | Representation mode | Object shape covered |
| --- | --- | --- |
| `object_backed_visible_stack` | `visible_stack` | 1x1 blocking visible stack with object id, object placement id, legacy placement bridge, encounter ref, and lifted metadata. |
| `object_backed_camp_anchor` | `camp_anchor` | 2x2 fixed camp object with retained/depleted state and scenario placement bridge. |
| `object_backed_guard_linked_stack` | `guard_linked_stack` | 1x1 visible guard stack with resource-node target agreement and lifted metadata. |
| `object_backed_guard_linked_camp` | `guard_linked_camp` | 2x2 fixed camp guard with scenario-objective target agreement and placement override field-objective source. |

Object-backed invalid coverage:

| Fixture | Failure covered |
| --- | --- |
| `bad_object_backed_missing_object_id` | Scenario placement lacks `object_id`. |
| `bad_object_backed_missing_legacy_placement_id_bridge` | Scenario placement lacks legacy `placement_id` bridge. |
| `bad_object_backed_missing_encounter_ref` | Scenario placement lacks `encounter_ref`. |
| `bad_object_backed_mismatched_field_objective_source` | Object metadata and placement disagree on field-objective source. |
| `bad_object_backed_mismatched_guard_target_ids` | Object metadata/lifted metadata and placement disagree on guard target ids. |
| `bad_object_backed_duplicate_scenario_object_authority_disagreement` | Lifted scenario metadata disagrees with object-backed scenario authority. |

The strict fixture command passes with `4` intentional placeholder cue warnings from the existing valid representation fixtures. Those warnings do not apply to production content.

## Validation Policy

Compatibility-warning-only remains:

- The 45 production direct-only encounter placements.
- The 3 authored scenario-metadata placements until a later object-backed bundle is explicitly planned and implemented.
- Missing `object_id` and `object_placement_id` across all 48 current placements.
- Missing first-class object schema fields across all 48 current placements.
- No first-class `primary_class: "neutral_encounter"` map-object records.
- Repeated encounter ids, script-spawn advisory effects, placement field-objective overrides, and inferred `visible_stack`/`none_inferred` report adapters.

Strict fixture-only remains:

- Object-backed schema shape for `visible_stack`, `camp_anchor`, `guard_linked_stack`, and `guard_linked_camp`.
- Missing `object_id`, missing legacy placement bridge, missing encounter ref, field-objective source mismatch, guard-target mismatch, and duplicate authority disagreement.
- Placeholder cue warning expectations in non-production valid fixtures.

Migrated-bundle strict production checks remain:

- `neutral_encounter_representation_bundle_001` scenario-placement metadata only: the existing three authored placements and their current metadata contract.
- Basalt gatehouse guard-target resolution from `target_placement_id: "dwelling_basalt_gatehouse"` to the scenario resource node with `site_id: "site_basalt_gatehouse"`.
- Rejection of undeclared production `neutral_encounter` metadata outside the authored bundle.

Future object-backed migrated-bundle strict checks should apply only after a new bundle is explicitly planned and then implemented. They should require object id, object placement id, legacy placement bridge, encounter ref, lifted metadata agreement, object schema fields, guard-link agreement, and field-objective source preservation for only the declared bundle placements.

## Recommendation

Proceed with a tiny planning-only object-backed bundle that lifts the existing authored `neutral_encounter_representation_bundle_001` metadata.

Recommended next slice: `neutral-encounter-first-class-object-bundle-planning-10184`.

Scope:

- Plan `neutral_encounter_first_class_object_bundle_001` for the same three placements: `river_pass_ghoul_grove`, `river_pass_hollow_mire`, and `ninefold_basalt_gatehouse_watch`.
- Define proposed `object_id` and `object_placement_id` values.
- Define exact lifted metadata agreement from `neutral_encounter_representation_bundle_001`.
- Define object-schema fields required for the object-backed records.
- Preserve guard-target convention for basalt gatehouse.
- Keep the slice planning-only.

Do not pause the neutral encounter migration yet. The current report and fixtures are now specifically positioned to answer the object-backed lift boundary with a small, reversible planning slice. Pausing before that would leave the first-class object report reviewed but unused.

Still out of scope for the next slice:

- Production JSON migration.
- Runtime encounter behavior changes.
- Pathing/body-tile/approach adoption.
- AI/editor/renderer/save adoption.
- Generated PNG import or asset import.
- Broad migration of the remaining 45 direct-only placements.

GitHub auth remains blocked; keep work local and do not push.
