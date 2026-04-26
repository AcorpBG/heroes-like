# Neutral Encounter Representation Bundle 001 Report Review

Status: completed review, documentation only.
Date: 2026-04-26.
Slice: neutral-encounter-representation-bundle-report-review-10184.

## Purpose

Review the authored `neutral_encounter_representation_bundle_001` report output after the metadata-only production implementation.

This review does not approve any further production content JSON migration, validator/test implementation, runtime encounter behavior, pathing, AI, editor behavior, renderer behavior, save behavior, generated PNG import, or asset import.

## Reviewed Inputs

- `project.md`
- `PLAN.md`
- `ops/progress.json`
- `ops/acorp_attention.md`
- `docs/neutral-encounter-representation-bundle-001-plan.md`
- `docs/neutral-encounter-report-review-001.md`
- `content/scenarios.json`, limited to the three authored placements
- `tests/validate_repo.py` neutral encounter report and validation sections
- `python3 tests/validate_repo.py --neutral-encounter-report`
- `python3 tests/validate_repo.py --neutral-encounter-report-json /tmp/heroes-neutral-encounter-report.review.json`
- `python3 tests/validate_repo.py --strict-neutral-encounter-fixtures`

Report schema: `neutral_encounter_report_v1`.
Report mode: `compatibility_report`.

## Authored Bundle Status

The bundle is now implemented as authored scenario-placement metadata only.

| Bundle | Status | Placements | Production JSON migration | Production JSON migration scope |
| --- | --- | ---: | --- | --- |
| `neutral_encounter_representation_bundle_001` | `metadata_authored` | 3 | true | `scenario_placement_metadata_only` |

The report-level compatibility adapters still show no runtime adoption:

| Adapter | Status |
| --- | --- |
| Runtime adoption | `not_active` |
| Pathing occupancy adoption | false |
| Renderer adoption | false |
| AI behavior switch | false |
| Editor behavior switch | false |
| Save migration | false |

This distinction is important: production JSON has migrated only for the three declared placement metadata extensions. Runtime behavior has not migrated.

## Authored Placements

| Scenario | Placement id | Encounter id | Coordinates | Difficulty | Combat seed | Representation mode | Guard role | Field-objective source |
| --- | --- | --- | --- | --- | ---: | --- | --- | --- |
| `river-pass` | `river_pass_ghoul_grove` | `encounter_ghoul_grove` | `3,1` | `low` | 1201 | `visible_stack` | `none` | `encounter_definition` |
| `river-pass` | `river_pass_hollow_mire` | `encounter_hollow_mire` | `6,4` | `medium` | 1202 | `visible_stack` | `route_block` | `none` |
| `ninefold-confluence` | `ninefold_basalt_gatehouse_watch` | `encounter_basalt_gatehouse_watch` | `60,52` | `high` | 16406 | `guard_linked_stack` | `guards_resource_node` | `encounter_definition` |

All three authored placements report:

- `encounter_exists: true`
- `metadata_authored: true`
- authored representation metadata present
- danger cue present
- guard link present
- no placement-level report warnings

## Report Counts After Migration

Core report counts remain:

| Surface | Count |
| --- | ---: |
| Scenarios | 15 |
| Encounter definitions | 62 |
| Direct scenario encounter placements | 48 |
| Script-spawn advisory encounter effects | 36 |
| First-class neutral encounter map objects | 0 |
| Authored bundle metadata placements | 3 |

Difficulty counts:

| Difficulty | Direct placements |
| --- | ---: |
| `high` | 21 |
| `low` | 1 |
| `medium` | 26 |

Field-objective counts remain:

| Field-objective source | Count |
| --- | ---: |
| Placement-level overrides | 4 |
| Definition-backed direct placements | 23 |

## Representation And Guard Counts

Representation mode source counts:

| Source | Mode | Count |
| --- | --- | ---: |
| Authored | `guard_linked_stack` | 1 |
| Authored | `visible_stack` | 2 |
| Inferred | `visible_stack` | 45 |

Guard-link role counts:

| Source | Guard role | Count |
| --- | --- | ---: |
| Authored | `guards_resource_node` | 1 |
| Authored | `none` | 1 |
| Authored | `route_block` | 1 |
| Inferred | `none_inferred` | 45 |

The remaining inferred counts are expected compatibility output for unmigrated direct scenario placements.

## Missing Future Metadata

The authored bundle reduced missing future metadata counts from `48` to `45` for every tracked future metadata category.

| Future metadata | Missing after migration |
| --- | ---: |
| Representation metadata | 45 |
| Danger/readability cue | 45 |
| Guard link | 45 |
| State model | 45 |
| Placement ownership | 45 |
| Reward/guard summary | 45 |
| Passability metadata | 45 |
| AI hints | 45 |
| Editor placement metadata | 45 |

Warnings/errors:

| Report output | Count |
| --- | ---: |
| Warnings | 408 |
| Errors | 0 |

The warning reduction is exactly the expected `27` warning reduction from three placements gaining nine future metadata groups each.

## Basalt Gatehouse Convention

The basalt gatehouse guard-link convention is confirmed from both `content/scenarios.json` and `tests/validate_repo.py`.

`ninefold_basalt_gatehouse_watch` uses:

| Field | Value | Meaning |
| --- | --- | --- |
| `guard_role` | `guards_resource_node` | The encounter guards a resource-node placement. |
| `target_kind` | `resource_node` | The target domain is a scenario resource node. |
| `target_id` | `site_basalt_gatehouse` | Stable resource-site content id. |
| `target_placement_id` | `dwelling_basalt_gatehouse` | Scenario-local resource-node placement id. |
| `clear_required_for_target` | true | Descriptive metadata only in this slice. |

The validator checks that `target_placement_id: "dwelling_basalt_gatehouse"` resolves to a scenario resource node and that its `site_id` matches `target_id: "site_basalt_gatehouse"`.

## Strict Fixture Coverage

Strict neutral encounter fixture validation remains isolated under `tests/fixtures/neutral_encounter_schema/strict_cases.json`.

Fixture coverage remains:

| Fixture group | Count |
| --- | ---: |
| Fixture encounter definitions | 4 |
| Valid neutral encounter records | 4 |
| Invalid neutral encounter records | 12 |

Valid representation modes covered:

| Mode | Count |
| --- | ---: |
| `visible_stack` | 1 |
| `camp_anchor` | 1 |
| `guard_linked_stack` | 1 |
| `guard_linked_camp` | 1 |

The strict fixture command passes with `4` intentional placeholder cue warnings. Those fixture warnings do not apply to production content.

## Validation Policy

Compatibility-warning-only remains:

- The remaining 45 unmigrated production direct scenario encounter placements.
- Missing future representation, danger, guard, state, ownership, reward, passability, AI, and editor metadata on those 45 placements.
- No first-class `primary_class: "neutral_encounter"` map-object records.
- Repeated encounter ids across current direct placements.
- Placement-level field-objective overrides outside the migrated bundle.
- Script-spawn advisory encounter effects.
- Inferred `visible_stack` modes and `none_inferred` guard roles from the compatibility adapter.

Strict fixture-only remains:

- Future schema shape coverage for `visible_stack`, `camp_anchor`, `guard_linked_stack`, and `guard_linked_camp`.
- Invalid missing/unsupported representation mode, danger cue, guard link, guard role, target kind, state model, ownership, linked encounter id, and reward/guard summary cases.
- Placeholder cue warning expectations in non-production valid fixtures.

Migrated-bundle strict validation now applies to:

- Exactly the three `neutral_encounter_representation_bundle_001` placements.
- Preservation of base placement fields: `placement_id`, `encounter_id`, `x`, `y`, `difficulty`, and `combat_seed`.
- Exact authored `neutral_encounter` metadata for schema version, bundle id, primary class, secondary tags, encounter links, field-objective source, representation fields, guard links, state model, ownership, reward summary, passability, AI hints, and editor placement.
- Basalt gatehouse target validation from `target_placement_id` to scenario resource node and from resource node `site_id` to `target_id`.
- Rejection of any production `neutral_encounter` metadata outside the declared bundle.

Runtime/editor/pathing validation is still not active:

- No pathing occupancy conflict errors.
- No approach-tile errors.
- No renderer cue availability errors.
- No editor overlap/readability errors.
- No AI valuation errors.
- No save migration errors.

## Compatibility Policy For Remaining Placements

The remaining `45` direct scenario encounter placements should stay compatibility-warning-only until a later slice explicitly declares another migrated production bundle or a first-class object migration.

Do not partially enforce strict metadata against those placements by default. The report should keep them visible as migration debt, but default validation should continue accepting them as legacy-compatible authored content.

## Recommended Next Slice

Proceed with first-class neutral encounter object planning before authoring a second broad metadata bundle.

Reasoning:

- The first bundle proves that scenario-placement metadata can carry the target representation contract.
- A second small bundle would reduce warning counts, but it would not answer the larger boundary question around first-class neutral encounter objects, body/approach metadata, editor placement, renderer adoption, pathing adoption, and future migration away from direct scenario-only placement.
- The report still shows `0` first-class neutral encounter map objects. That is now the highest-value planning gap before wider migration.

Recommended next slice: `neutral-encounter-first-class-object-planning-10184`.

Scope should remain planning-only:

- Define when neutral encounter representation metadata stays on scenario placements versus moves to first-class map-object or object-placement records.
- Define link rules from first-class encounter objects back to current `placement_id`, `encounter_id`, scenario coordinates, field objectives, and save compatibility.
- Define a no-runtime-change migration sequence for object ids, body tiles, approach offsets, placement ownership, guard targets, report output, and rollback.
- Keep runtime encounter behavior, pathing, AI, editor behavior, renderer behavior, save migration, generated PNG import, and asset import out of scope.

GitHub auth remains blocked; keep work local and do not push.
