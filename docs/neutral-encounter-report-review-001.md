# Neutral Encounter Report Review 001

Status: completed review, documentation only.
Date: 2026-04-26.
Slice: neutral-encounter-additive-report-review-10184.

## Purpose

Review the opt-in additive neutral encounter report before any production neutral encounter metadata migration. This slice converts the report output into warning/error policy and the next planning recommendation.

No production `content/scenarios.json`, `content/encounters.json`, `content/map_objects.json`, `content/resource_sites.json`, runtime encounter behavior, pathing, AI, editor behavior, renderer behavior, save format, generated PNG import, or asset import changes are approved by this review.

## Report Inputs

Reviewed:

- `docs/neutral-encounter-representation-plan.md`
- `docs/neutral-encounter-additive-validator-report-plan.md`
- `tests/fixtures/neutral_encounter_schema/strict_cases.json`
- `python3 tests/validate_repo.py --neutral-encounter-report`
- `python3 tests/validate_repo.py --neutral-encounter-report-json /tmp/heroes-neutral-encounter-report.initial.json`
- `python3 tests/validate_repo.py --strict-neutral-encounter-fixtures`

Report schema: `neutral_encounter_report_v1`.
Report mode: `compatibility_report`.

## Findings

Current production content is internally consistent under legacy-compatible direct scenario encounter placement rules. The report found `435` warnings and `0` errors.

Core counts:

| Surface | Count |
| --- | ---: |
| Scenarios | 15 |
| Encounter definitions | 62 |
| Direct scenario encounter placements | 48 |
| Script-spawn advisory encounter effects | 36 |
| First-class neutral encounter map objects | 0 |
| Inferred `visible_stack` placements | 48 |

Difficulty counts:

| Difficulty | Direct placements |
| --- | ---: |
| `high` | 21 |
| `low` | 1 |
| `medium` | 26 |

Scenario counts:

| Scenario | Direct placements | Script-spawn advisory effects | Candidate bundle placements |
| --- | ---: | ---: | ---: |
| `bogbound-oath` | 3 | 2 | 0 |
| `causeway-stand` | 3 | 2 | 0 |
| `charter-pyre` | 3 | 2 | 0 |
| `daybreak-spire` | 3 | 3 | 0 |
| `fen-crown` | 3 | 2 | 0 |
| `glassfen-breakers` | 3 | 3 | 0 |
| `glassroad-sundering` | 3 | 2 | 0 |
| `ironbridge-stand` | 3 | 2 | 0 |
| `lockmarsh-surge` | 3 | 3 | 0 |
| `nightglass-redoubt` | 3 | 3 | 0 |
| `ninefold-confluence` | 6 | 5 | 1 |
| `prismhearth-watch` | 3 | 2 | 0 |
| `reedbarrow-ferry` | 3 | 2 | 0 |
| `river-pass` | 3 | 2 | 2 |
| `stonewake-watch` | 3 | 1 | 0 |

Repeated encounter ids:

| Encounter id | Direct placements |
| --- | ---: |
| `encounter_archive_wardens` | 3 |
| `encounter_beacon_wardens` | 2 |
| `encounter_bone_ferry_watch` | 3 |
| `encounter_bridgeward_levies` | 2 |
| `encounter_drum_circle` | 2 |
| `encounter_gate_marshals` | 2 |
| `encounter_glasswing_sortie` | 2 |
| `encounter_hollow_mire` | 2 |
| `encounter_reed_totemists` | 5 |
| `encounter_relay_pickets` | 2 |

Field-objective counts:

| Field-objective source | Count |
| --- | ---: |
| Placement-level overrides | 4 |
| Definition-backed direct placements | 23 |

Placement-level override placements:

- `glassfen-breakers`: `glassfen_relay_pickets`
- `nightglass-redoubt`: `nightglass_drum_circle`
- `prismhearth-watch`: `prismhearth_relay_pickets`
- `reedbarrow-ferry`: `reedbarrow_chain`

Missing future metadata counts:

| Future metadata | Missing count |
| --- | ---: |
| Representation metadata | 48 |
| Danger/readability cue | 48 |
| Guard link | 48 |
| State model | 48 |
| Placement ownership | 48 |
| Reward/guard summary | 48 |
| Passability metadata | 48 |
| AI hints | 48 |
| Editor placement metadata | 48 |

Candidate bundle summary:

| Bundle | Status | Placements | Production JSON migration |
| --- | --- | ---: | --- |
| `neutral_encounter_representation_bundle_001` | `planning_only` | 3 | false |

Candidate placements:

| Scenario | Placement id | Encounter id | Proposed mode | Proposed guard role |
| --- | --- | --- | --- | --- |
| `river-pass` | `river_pass_ghoul_grove` | `encounter_ghoul_grove` | `visible_stack` | `none` |
| `river-pass` | `river_pass_hollow_mire` | `encounter_hollow_mire` | `visible_stack` | `route_block` |
| `ninefold-confluence` | `ninefold_basalt_gatehouse_watch` | `encounter_basalt_gatehouse_watch` | `guard_linked_stack` | `guards_resource_node` |

Compatibility adapters remain inactive for runtime adoption, production JSON migration, pathing occupancy adoption, renderer adoption, AI behavior switch, editor behavior switch, and save migration.

## Strict Fixture Coverage

Strict fixtures are isolated under `tests/fixtures/neutral_encounter_schema/strict_cases.json` and do not touch production content.

Fixture coverage:

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

Invalid cases covered:

- `bad_missing_representation_mode`
- `bad_invalid_representation_mode`
- `bad_missing_danger_cue`
- `bad_missing_guard_link`
- `bad_guard_role_none`
- `bad_unknown_target_kind`
- `bad_missing_target_reference`
- `bad_missing_state_model`
- `bad_missing_placement_ownership`
- `bad_missing_linked_encounter_id`
- `bad_unknown_linked_encounter_id`
- `bad_missing_guard_reward_summary`

The strict fixture command passed and reported `4` intentional warning cases for placeholder cue ids in the valid fixtures.

## Decisions

The warning volume is acceptable for a compatibility report. It is expected because all `48` direct production placements are still inferred from legacy scenario records and intentionally lack future first-class representation metadata.

The `36` script-spawn encounter effects remain advisory context only. They should not enter strict fixture scope or production bundle planning until a separate dynamic-spawn representation plan exists.

Repeated encounter ids are valid reuse, not errors. They should stay report-visible because repeated definitions may later need distinct readability families, guard context, seed context, or objective summaries during migration.

Placement-level field-objective overrides require care during bundle planning. They are not errors, but migrated metadata must preserve the placement-level source where it overrides the encounter definition.

The absence of first-class neutral encounter map objects remains a compatibility warning. It should not block report generation, default validation, or the next planning slice.

The candidate bundle is coherent enough for planning. It exercises two River Pass visible-stack cases and one Ninefold guard-linked stack case without requiring production migration yet.

## Warning And Error Policy

Remain compatibility warnings for current production content:

- Missing authored representation metadata, danger cues, guard links, state model, placement ownership, reward/guard summary, passability metadata, AI hints, and editor placement metadata.
- No first-class `primary_class: "neutral_encounter"` map-object records.
- Repeated encounter ids across direct scenario placements.
- Placement-level field-objective overrides.
- Script-spawn advisory encounter effects outside first strict fixture scope.
- Any inferred `visible_stack` mode or inferred `none_inferred` guard role produced only by report compatibility adapters.

Strict fixture errors now:

- Missing or invalid `representation.mode`.
- Missing danger cue on visible/camp encounter fixtures.
- Missing `guard_link` for guard-linked modes.
- Guard-linked fixture with `guard_role: "none"`.
- Unknown guard target kind.
- Guard-linked fixture missing both `target_id` and `target_placement_id`.
- Missing `state_model` or `placement_ownership`.
- Missing linked encounter id or unknown linked encounter id.
- Guard-linked fixture missing reward/guard summary.

Later migrated-bundle errors:

- A declared production neutral encounter metadata bundle must provide authored representation fields, danger/readability cues, state model, placement ownership, passability summary, AI/editor hints, and reward/guard summary for every placement in that bundle.
- A migrated guard-linked placement must provide valid guard-target metadata and preserve whether the target is a placement id, content id, resource node, route, scenario objective, town, or map object.
- A migrated placement with field-objective overrides must preserve placement-level objective behavior and not silently collapse back to definition-level objectives.
- A migrated placement must preserve `placement_id`, `encounter_id`, `difficulty`, and `combat_seed` compatibility.
- Unmigrated production direct placements remain compatibility-warning-only.

Later runtime/editor errors, not active:

- Pathing occupancy conflicts.
- Blocked or missing approach tiles.
- Renderer cue availability.
- Editor link readability or overlap checks.
- AI valuation requirements for fight/avoid/delay/route-around decisions.
- Save-state migration requirements.

## Recommended Next Slice

Proceed with production metadata planning for `neutral_encounter_representation_bundle_001`.

That planning slice should define the exact metadata shape, target attachment location, guard-link target convention, field-objective preservation rules, migrated-bundle validation level, rollback behavior, and non-change boundaries for only these three candidate placements:

- `river-pass`: `river_pass_ghoul_grove`
- `river-pass`: `river_pass_hollow_mire`
- `ninefold-confluence`: `ninefold_basalt_gatehouse_watch`

The next slice should still be planning-only. Production scenario, encounter, map-object, and resource-site JSON migration should wait until the plan explicitly approves the bundle and validation level. Runtime encounters, pathing, AI, editor behavior, renderer behavior, save migration, generated PNG import, `body_tiles`, and approach adoption remain out of scope.

GitHub auth remains blocked; keep work local and do not push.
