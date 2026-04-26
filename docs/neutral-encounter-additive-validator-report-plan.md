# Neutral Encounter Additive Validator Report Plan

Status: planning source only, not implementation.
Date: 2026-04-26.
Slice: neutral-encounter-additive-validator-report-planning-10184.

## Purpose

Plan report-only validator support for first-class neutral encounter representation before any production migration.

This document converts `docs/neutral-encounter-representation-plan.md` into a narrow implementation contract for an opt-in compatibility report and isolated strict fixtures. It does not approve production content migration or runtime adoption.

No `content/scenarios.json`, `content/encounters.json`, `content/map_objects.json`, `content/resource_sites.json`, runtime encounter rules, pathing, AI, editor behavior, renderer behavior, tests, validator implementation, generated PNG, or asset import changes are approved by this slice.

## Current Reality

Current production encounter placements are direct records under `scenarios[].encounters[]`. They are not first-class map-object records.

Reviewed production facts:

| Surface | Count |
| --- | ---: |
| Scenario records | 15 |
| Encounter definitions | 62 |
| Direct scenario encounter placements | 48 |
| Scenario placements with placement-level `field_objectives` | 4 |
| Direct placements whose encounter definition has `field_objectives` | 23 |
| Script-spawned encounter effects | 36 |
| First-class `primary_class: "neutral_encounter"` map objects | 0 |

Direct placement count by scenario:

| Scenario | Direct encounters |
| --- | ---: |
| `bogbound-oath` | 3 |
| `causeway-stand` | 3 |
| `charter-pyre` | 3 |
| `daybreak-spire` | 3 |
| `fen-crown` | 3 |
| `glassfen-breakers` | 3 |
| `glassroad-sundering` | 3 |
| `ironbridge-stand` | 3 |
| `lockmarsh-surge` | 3 |
| `nightglass-redoubt` | 3 |
| `ninefold-confluence` | 6 |
| `prismhearth-watch` | 3 |
| `reedbarrow-ferry` | 3 |
| `river-pass` | 3 |
| `stonewake-watch` | 3 |

Direct placement count by difficulty:

| Difficulty | Direct encounters |
| --- | ---: |
| `high` | 21 |
| `low` | 1 |
| `medium` | 26 |

Repeated encounter ids in direct placements:

| Encounter id | Placements |
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

Placement-level field-objective overrides:

| Scenario | Placement id |
| --- | --- |
| `reedbarrow-ferry` | `reedbarrow_chain` |
| `nightglass-redoubt` | `nightglass_drum_circle` |
| `prismhearth-watch` | `prismhearth_relay_pickets` |
| `glassfen-breakers` | `glassfen_relay_pickets` |

Script-spawned encounter effects should be counted in an advisory report bucket only. They are dynamic scenario effects, not first-class visible neutral encounter placements for the first strict fixture scope.

## Report-Only Compatibility Inference

The future report should infer a neutral encounter compatibility view from current direct scenario placements without requiring object ids.

Inference rules:

- Treat every current `scenarios[].encounters[]` record as `inferred_primary_class: "neutral_encounter"`.
- Infer `representation.mode: "visible_stack"` for direct placements unless a future migrated bundle authors a different mode.
- Preserve `placement_id` as the compatibility bridge for save state, routing, and later metadata attachment.
- Preserve `encounter_id`, `x`, `y`, `difficulty`, `combat_seed`, and placement-level `field_objectives` exactly as report inputs.
- Treat repeated encounter ids as valid reuse, not errors. Report them because repeated content may need distinct readability, seed, or guard context later.
- Treat missing representation metadata, missing danger cues, missing guard links, missing reward/guard summary, missing passability class, missing AI hints, and missing editor placement metadata as compatibility warnings.
- Treat absent guard links as `guard_role: "none_inferred"` unless a future fixture or migrated bundle declares a guard role.
- Treat first-class neutral encounter map-object absence as a report warning, not an error.
- Keep `content/encounters.json` as the encounter definition source. Do not duplicate full army, commander, battlefield, reward, or objective data in the neutral encounter report.

Report fields per direct placement:

```json
{
  "scenario_id": "river-pass",
  "placement_id": "river_pass_ghoul_grove",
  "encounter_id": "encounter_ghoul_grove",
  "encounter_exists": true,
  "x": 3,
  "y": 1,
  "difficulty": "low",
  "combat_seed": 1201,
  "inferred_primary_class": "neutral_encounter",
  "inferred_representation_mode": "visible_stack",
  "representation_metadata_present": false,
  "danger_cue_present": false,
  "guard_link_present": false,
  "inferred_guard_role": "none_inferred",
  "field_objectives_source": "encounter_definition",
  "field_objective_count": 1,
  "reward_categories": ["gold", "experience"],
  "candidate_bundle_id": "",
  "warnings": [
    "future schema warning: missing neutral encounter representation metadata",
    "future schema warning: missing danger/readability cue",
    "future schema warning: missing guard_link metadata"
  ]
}
```

Scenario-level report fields:

- `scenario_id`
- `direct_encounter_count`
- `difficulty_counts`
- `repeated_encounter_ids`
- `placement_field_objective_count`
- `definition_field_objective_count`
- `missing_representation_metadata_count`
- `missing_guard_link_count`
- `missing_danger_cue_count`
- `candidate_bundle_placements`
- `script_spawn_encounter_count` as advisory context only

Global report fields:

- `schema: "neutral_encounter_report_v1"`
- `mode: "compatibility_report"`
- `compatibility_adapters.runtime_adoption: "not_active"`
- `compatibility_adapters.production_json_migration: false`
- `compatibility_adapters.pathing_occupancy_adoption: false`
- `compatibility_adapters.renderer_adoption: false`
- `compatibility_adapters.ai_behavior_switch: false`
- `summary.scenario_count`
- `summary.encounter_definition_count`
- `summary.direct_placement_count`
- `summary.script_spawn_encounter_count`
- `summary.first_class_neutral_encounter_object_count`
- `summary.difficulty_counts`
- `summary.representation_mode_counts`
- `summary.missing_future_metadata_counts`
- `scenarios`
- `placements`
- `repeated_encounter_ids`
- `field_objectives`
- `guard_links`
- `candidate_bundles`
- `warnings`
- `errors`

## Missing Metadata Counts

For current production content, the first report should count these missing fields across the 48 direct placements:

| Future metadata | Current expected count | Level |
| --- | ---: | --- |
| `representation.mode` | 48 inferred/missing authored metadata | warning |
| `representation.readability_family` | 48 | warning |
| `representation.danger_cue_id` | 48 | warning |
| `guard_link.guard_role` | 48 inferred as none | warning |
| `guard_link.target_kind` | 48 inferred as none | warning |
| `state_model` | 48 | warning |
| `placement_ownership` | 48 | warning |
| `reward_guard_summary` | 48 inferred from encounter rewards when possible | warning |
| `passability.passability_class` | 48 inferred as `neutral_stack_blocking` | warning |
| `ai_hints` | 48 | warning |
| `editor_placement` | 48 | warning |

These counts are expected compatibility noise. They should not fail default validation or opt-in report generation.

## Candidate Bundle Summary

The report should include a candidate bundle section, but the bundle remains planning-only until a later implementation slice.

Candidate bundle id: `neutral_encounter_representation_bundle_001`.

| Scenario | Placement id | Encounter id | Proposed mode | Proposed guard role | Report expectation |
| --- | --- | --- | --- | --- | --- |
| `river-pass` | `river_pass_ghoul_grove` | `encounter_ghoul_grove` | `visible_stack` | `none` | Candidate independent visible stack. |
| `river-pass` | `river_pass_hollow_mire` | `encounter_hollow_mire` | `visible_stack` | `route_block` | Candidate route-block summary without runtime pathing adoption. |
| `ninefold-confluence` | `ninefold_basalt_gatehouse_watch` | `encounter_basalt_gatehouse_watch` | `guard_linked_stack` | `guards_resource_node` | Candidate guard-link planning case for `site_basalt_gatehouse`. |

Candidate summary fields:

- `bundle_id`
- `status: "planning_only"`
- `production_json_migration: false`
- `placement_count`
- `placements`
- `required_before_migration`
- `warnings`

## Strict Non-Production Fixture Scope

Strict fixtures should live outside production content, under a future directory such as `tests/fixtures/neutral_encounter_schema/`.

Valid fixture cases:

- `visible_stack`: direct 1x1 visible army encounter, no guard target, danger cue present, state model present.
- `camp_anchor`: fixed encounter camp, camp representation metadata present, depleted/cleared state behavior present.
- `guard_linked_stack`: visible stack guarding another placement, valid `guard_link.target_kind`, `target_placement_id`, and `clear_required_for_target`.
- `guard_linked_camp`: fixed camp guarding another placement, guard target link present, camp cleared-state policy present.

Invalid fixture cases:

- Missing `representation.mode`.
- Invalid representation mode.
- Missing `danger_cue_id` for a visible encounter.
- Missing `guard_link` when mode is `guard_linked_stack` or `guard_linked_camp`.
- Guard-linked fixture with `guard_role: "none"`.
- Guard-linked fixture with unknown `target_kind`.
- Guard-linked fixture missing both `target_id` and `target_placement_id`.
- Missing `state_model`.
- Missing `placement_ownership`.
- Missing linked `encounter_id`.
- Unknown linked `encounter_id`.
- Missing reward/guard summary when the fixture declares a guard target.

Fixture scope exclusions:

- No production JSON fixtures.
- No script-spawned encounters in strict scope.
- No pathing occupancy checks.
- No true approach-tile validation.
- No renderer sprite validation.
- No AI valuation requirements beyond required advisory fields.
- No save migration fixtures.

## Warning And Error Policy

Default `python3 tests/validate_repo.py`:

- Should remain unchanged for this slice and the next implementation slice unless explicitly approved.
- Should not print neutral encounter compatibility warnings by default.
- Should not fail current production direct placements for missing future metadata.

Opt-in report warnings:

- Missing first-class neutral encounter map-object records.
- Missing authored representation metadata on current direct placements.
- Missing danger/readability cue metadata.
- Missing guard links and inferred `none_inferred` guard roles.
- Missing state model, placement ownership, passability class, AI hints, and editor placement metadata.
- Repeated encounter ids across multiple placements.
- Placement-level field-objective overrides that will need careful migration.
- Script-spawned encounters that are not included in first strict fixture scope.

Opt-in report errors:

- Current direct placement references an unknown `encounter_id`.
- Current direct placement has missing or duplicate `placement_id` within a scenario.
- Current direct placement has non-integer coordinates.
- Current direct placement coordinates are outside the scenario map bounds.
- Current direct placement has missing `difficulty` or missing `combat_seed` if existing base validation does not already catch it.

Strict fixture errors:

- Any required new-schema fixture field is missing.
- Any enum value is invalid.
- Any linked encounter id is unknown.
- Any guard-linked fixture lacks a usable target link.
- Any cue/link case intentionally marked invalid passes without an error.

Later migrated-bundle errors:

- Only a declared production neutral encounter bundle may require authored representation fields.
- Unmigrated production direct placements remain compatibility-warning-only.
- A migrated bundle must preserve `placement_id`, `encounter_id`, `difficulty`, and `combat_seed` compatibility.
- A migrated guard-linked bundle must provide valid guard target metadata.
- A migrated camp-anchor bundle must provide cleared/depleted state behavior.

Later runtime/editor errors, not active:

- Pathing occupancy conflicts.
- Blocked approach tiles.
- Link lines that hide or overlap the target in editor views.
- AI valuation requirements for neutral clearance.
- Renderer cue availability.
- Save-state migration requirements.

## CLI Expectations

Recommended implementation path: add a separate neutral encounter report command rather than folding this into `--overworld-object-report`.

Rationale:

- The report is placement-centric and scenario-centric, while `--overworld-object-report` is object/resource-site-centric.
- The neutral report needs repeated encounter id analysis, difficulty distribution, field-objective summaries, guard-link readiness, candidate bundles, and script-spawn advisory counts.
- Keeping it separate prevents the existing overworld object report from becoming a large mixed-domain dashboard.
- The existing overworld object report should keep its one-line warning that no first-class neutral encounter map-object records exist yet, and may later point reviewers to the neutral encounter report.

Recommended flags:

- `--neutral-encounter-report`: print a concise text compatibility report.
- `--neutral-encounter-report-json /tmp/heroes-neutral-encounter-report.json`: write JSON.
- `--strict-neutral-encounter-fixtures`: validate only isolated fixture records.

Recommended validation commands after implementation:

```bash
python3 tests/validate_repo.py
python3 tests/validate_repo.py --neutral-encounter-report
python3 tests/validate_repo.py --neutral-encounter-report-json /tmp/heroes-neutral-encounter-report.json
python3 -m json.tool /tmp/heroes-neutral-encounter-report.json >/tmp/heroes-neutral-encounter-report-jsoncheck.txt
python3 tests/validate_repo.py --strict-neutral-encounter-fixtures
python3 tests/validate_repo.py --overworld-object-report
```

## JSON Report Shape

Recommended top-level JSON shape:

```json
{
  "schema": "neutral_encounter_report_v1",
  "generated_at": "2026-04-26T00:00:00Z",
  "mode": "compatibility_report",
  "compatibility_adapters": {
    "runtime_adoption": "not_active",
    "production_json_migration": false,
    "pathing_occupancy_adoption": false,
    "renderer_adoption": false,
    "ai_behavior_switch": false,
    "report_normalization": "scenario_direct_placements_inferred_as_visible_stack"
  },
  "summary": {
    "scenario_count": 15,
    "encounter_definition_count": 62,
    "direct_placement_count": 48,
    "script_spawn_encounter_count": 36,
    "first_class_neutral_encounter_object_count": 0,
    "difficulty_counts": {"high": 21, "low": 1, "medium": 26},
    "representation_mode_counts": {"visible_stack_inferred": 48},
    "missing_future_metadata_counts": {
      "representation": 48,
      "danger_cue": 48,
      "guard_link": 48,
      "state_model": 48,
      "placement_ownership": 48,
      "reward_guard_summary": 48,
      "passability": 48,
      "ai_hints": 48,
      "editor_placement": 48
    }
  },
  "scenarios": {},
  "placements": {},
  "repeated_encounter_ids": {},
  "field_objectives": {
    "placement_override_count": 4,
    "definition_backed_placement_count": 23,
    "placements": []
  },
  "guard_links": {
    "authored_guard_link_count": 0,
    "inferred_none_count": 48,
    "candidate_guard_link_count": 1
  },
  "candidate_bundles": {},
  "warnings": [],
  "errors": []
}
```

## Text Report Shape

Recommended text output:

```text
NEUTRAL ENCOUNTER REPORT
- schema: neutral_encounter_report_v1
- mode: compatibility_report
- scenarios: 15; encounter definitions: 62
- direct encounter placements: 48; script-spawned encounter effects: 36
- first-class neutral encounter objects: 0
- difficulty high: 21
- difficulty low: 1
- difficulty medium: 26
- inferred visible_stack placements: 48
- placement field-objective overrides: 4; definition-backed field objectives: 23
- repeated encounter ids: 10
- missing representation metadata: 48; missing guard links: 48; missing danger cues: 48
- candidate bundle neutral_encounter_representation_bundle_001: 3 planning-only placements
- runtime adoption: not_active; production migration=False
Warnings: <count>; Errors: <count>
```

## Rollback

Rollback must be simple:

- Remove or ignore the neutral report flags and fixture directory.
- Leave default `python3 tests/validate_repo.py` behavior unchanged.
- Leave production content JSON untouched.
- Keep existing direct `placement_id`, `encounter_id`, `difficulty`, and `combat_seed` records as the only runtime source.
- Keep `--overworld-object-report` behavior independent; its existing first-class-neutral warning remains sufficient if the separate report is removed.
- No save migration rollback is needed because no save migration is approved.

## Exact Non-Change Rules

This planning slice and the next report/fixture implementation slice must not:

- Edit production `content/scenarios.json`.
- Edit production `content/encounters.json`.
- Edit production `content/map_objects.json`.
- Edit production `content/resource_sites.json`.
- Add first-class production neutral encounter records.
- Add or migrate production object ids for encounter placements.
- Change runtime encounter triggering.
- Change battle payload construction.
- Change pathing, passability, body-tile, approach, or occupancy behavior.
- Change AI behavior, AI valuation, raid behavior, or strategic routing.
- Change editor behavior or placement rules.
- Change renderer behavior or sprite mappings.
- Add generated PNGs or import runtime assets.
- Add save migration or save schema changes.
- Treat script-spawned encounters as strict neutral encounter representation fixtures.
- Claim that neutral encounter representation is production-ready.

## Next Slice

This plan supports a narrow implementation slice: implement `--neutral-encounter-report`, `--neutral-encounter-report-json`, and `--strict-neutral-encounter-fixtures` with isolated fixtures only.

The implementation slice should still be report-only for production content. Production neutral encounter metadata migration, candidate bundle implementation, renderer adoption, pathing/approach adoption, AI adoption, editor adoption, generated asset import, and save migration should remain later explicit slices.
