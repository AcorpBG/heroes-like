# Overworld Object Report Review 001

Status: completed review, documentation only.
Date: 2026-04-26.
Slice: overworld-object-additive-report-review-10184.

## Purpose

Review the opt-in additive overworld object report before any production object/resource-site JSON migration. This slice converts the current report output into follow-up decisions and a small implementation sequence.

No production `content/map_objects.json`, `content/resource_sites.json`, scenario placement, renderer, pathing, AI, runtime behavior, generated PNG, or asset import changes are approved by this review.

## Report Inputs

Reviewed:

- `docs/overworld-object-schema-migration-plan.md`
- `docs/overworld-object-taxonomy-density.md`
- `content/map_objects.json`
- `content/resource_sites.json`
- current `content/scenarios.json` placement reality
- `python3 tests/validate_repo.py --overworld-object-report`
- `python3 tests/validate_repo.py --overworld-object-report-json /tmp/heroes-overworld-object-report-review.json`

Report schema: `overworld_object_report_v1`.
Report mode: `compatibility_report`.

## Findings

Current production content is internally consistent under the legacy-compatible rules. The report found `169` warnings and `0` errors.

Core counts:

| Surface | Count |
| --- | ---: |
| Map objects | 43 |
| Resource sites | 48 |
| Scenario resource-site placements | 127 |
| Scenario encounter placements | 48 |
| Linked map-object resource sites | 38 |
| Placed resource sites without map-object links | 10 |

Family and inferred primary-class reality:

| Current family | Count | Inferred primary class |
| --- | ---: | --- |
| `blocker` | 2 | `decoration` |
| `faction_landmark` | 3 | `faction_landmark` |
| `guarded_reward_site` | 2 | `guarded_reward_site` |
| `mine` | 3 | `persistent_economy_site` |
| `neutral_dwelling` | 25 | `neutral_dwelling` |
| `pickup` | 2 | `pickup` |
| `repeatable_service` | 2 | `interactable_site` |
| `scouting_structure` | 2 | `interactable_site` |
| `transit_object` | 2 | `transit_route_object` |

Inferred primary-class totals:

| Inferred primary class | Count |
| --- | ---: |
| `decoration` | 2 |
| `faction_landmark` | 3 |
| `guarded_reward_site` | 2 |
| `interactable_site` | 4 |
| `neutral_dwelling` | 25 |
| `persistent_economy_site` | 3 |
| `pickup` | 2 |
| `transit_route_object` | 2 |

Footprint and passability reality:

| Reported bucket | Count |
| --- | ---: |
| `micro` footprint | 5 |
| `small` footprint | 23 |
| `medium` footprint | 15 |
| `passable_visit_on_enter` | 4 |
| `blocking_visitable` | 34 |
| `blocking_non_visitable` | 5 |

Missing future metadata:

| Metadata | Missing count |
| --- | ---: |
| `schema_version` | 43 |
| `primary_class` | 43 |
| `secondary_tags` | 43 |
| `footprint.anchor` | 43 |
| `footprint.tier` | 43 |
| `body_tiles` | 43 |
| `passability_class` | 43 |
| `interaction` | 43 |
| `animation_cues` | 43 |
| `editor_placement` | 43 |
| `approach` | 38 |
| `ai_hints` | 41 |

Placed resource sites without map-object links:

- `site_ore_crates`
- `site_scout_shrine`
- `site_riverwatch_free_company_yard`
- `site_lens_house`
- `site_ember_signal_post`
- `site_bog_drum_outpost`
- `site_prism_watch_relay`
- `site_roadside_sanctum`
- `site_reedscript_shrine`
- `site_starlens_sanctum`

Guard, ownership, transit, and neutral encounter findings:

- `27` current objects have guard/reward implications, mostly neutral dwellings plus guarded reward sites.
- `32` current objects have ownership/capture implications.
- `2` transit objects are missing future `route_effect` metadata: `object_repaired_ferry_stage` and `object_rope_lift`.
- Scenario data has `48` encounter placements, but there are no first-class `neutral_encounter` map-object records yet.
- Only one placed guard encounter is explicitly recognized as placed guard context in the current report: `encounter_basalt_gatehouse_watch`.

## Decisions

The warning volume is acceptable for a compatibility report. It confirms that the next step should be a narrow production additive schema planning slice, not a direct JSON migration.

`primary_class`, `secondary_tags`, `schema_version`, `footprint.anchor`, `footprint.tier`, `passability_class`, and `interaction` are the safest first production additive fields to plan because they can be added without changing runtime behavior if kept metadata-only.

`body_tiles` and `approach` should be planned in the same contract but should stay validator/editor metadata until scenario placement checks prove they will not trap heroes or invalidate existing maps. True occupancy and pathing adoption remain blocked until a later explicit pathing/editor slice.

Neutral encounters should become first-class visible overworld object records, but not as part of the first broad object migration. The next plan should define the representation first: stack object versus guarded-camp object, guard-target links, danger cues, cleared state, placement ownership, and AI path-blocking hints.

Placed resource sites without object links should become a first migration target after the safe field plan, because they are already scenario-visible and currently depend on legacy site-only presentation. The first target set should be pickups, scouting/shrine services, faction outposts, and frontier shrines. This must be planned before editing production JSON.

Transit `route_effect` metadata should remain a placeholder warning until pathing and strategic AI can evaluate route endpoints, movement discounts/taxes, fog bypass, repair unlocks, and scenario gates.

Animation cue ids should remain warnings until a cue catalog exists. Do not add arbitrary ids to production objects before the animation catalog names cue families and fallback behavior.

AI and editor hints should roll out as advisory metadata only. They should not switch AI valuation, editor placement blocking, or map density validation until the content bundle and editor rules are declared migrated.

## Warning And Error Policy

Remain compatibility warnings for current production content:

- Missing `schema_version`, `primary_class`, `secondary_tags`, `footprint.anchor`, `footprint.tier`, `passability_class`, `interaction`, `body_tiles`, `approach`, `animation_cues`, `editor_placement`, and `ai_hints`.
- Missing `capture_profile` on capturable or persistent current objects.
- Missing `route_effect` on transit objects.
- Placed resource sites without map-object links.
- Absence of first-class `neutral_encounter` map-object records.
- Any inferred primary class, passability class, or secondary tag produced only by report compatibility adapters.

Strict fixture errors now:

- Unknown or missing required new-schema fields in `tests/fixtures/overworld_object_schema/` strict cases.
- Invalid `primary_class`, `passability_class`, interaction cadence, footprint tier, footprint anchor, body tile role, or body tile offset in strict fixtures.
- Visitable strict-fixture objects missing valid approach metadata.
- Transit strict-fixture objects missing route-effect metadata.
- Guarded strict-fixture objects missing guard metadata.
- Persistent economy strict-fixture objects missing ownership/capture metadata.
- Unknown linked resource-site, encounter, or guard ids inside strict fixtures.

Later migrated-bundle errors:

- Any production object bundle that declares the new schema must provide `schema_version`, `primary_class`, `secondary_tags`, footprint anchor/tier, `passability_class`, and `interaction`.
- Migrated visitable objects must provide approach metadata.
- Migrated transit objects must provide route-effect metadata, even if the runtime effect remains inactive.
- Migrated persistent economy sites must provide ownership/capture summary metadata.
- Migrated guarded reward and neutral dwelling objects must provide guard/reward summary metadata.
- Migrated neutral encounter objects must provide encounter links, danger/readability hints, cleared-state behavior, and guard-target linkage when guarding another object.
- Migrated placed site bundles should not allow site-only placement without a map-object link unless the bundle declares a temporary compatibility exemption.

Later runtime/editor errors, not yet active:

- Body-tile occupancy conflicts.
- Blocked or missing approach tiles in production scenarios.
- Route-effect endpoint invalidity for pathing.
- AI valuation requirements for object classes.
- Density-band violations.

## Prioritized Follow-Up Slices

1. First production additive object schema planning for safe fields. Define the exact JSON shape, defaults, compatibility adapter behavior, and migrated-bundle validation for `schema_version`, `primary_class`, `secondary_tags`, footprint anchor/tier, `passability_class`, and `interaction`. Keep runtime behavior unchanged.
2. Neutral encounter representation decision. Define first-class visible neutral encounter records, guard-target linkage, danger cue fields, cleared state, scenario placement strategy, and AI/editor placeholders before production migration.
3. Body tiles and approach metadata strategy. Decide coordinate conventions, rectangular defaulting, approach sides, visit offsets, town exceptions, and editor placement checks. Keep pathing inactive.
4. Placed-site object-link planning. Prioritize the 10 unlinked placed sites into pickups, scouting/shrines, faction outposts, and frontier shrines, then plan a small production additive content bundle.
5. Route-effect placeholder planning. Define metadata-only route-effect ids and shape for ferries/lifts/rails/root gates/fog routes without pathing or AI adoption.
6. Animation cue catalog prerequisite. Define object cue families and fallback cues before production object records reference cue ids broadly.
7. AI/editor hint rollout. Define advisory valuation, placement, density, and class hints after schema shape stabilizes, still without switching AI or editor behavior.

## Next Current Slice

Set the next current slice to first production additive object schema planning for safe metadata fields. Production JSON migration should still wait until that plan explicitly names a small migrated bundle and validation level.

GitHub auth remains blocked; keep work local and do not push.
