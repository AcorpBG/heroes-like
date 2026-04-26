# Neutral Encounter Representation Plan

Status: planning source only, not implementation.
Date: 2026-04-26.
Slice: neutral-encounter-representation-planning-10184.

## Purpose

Plan first-class visible neutral encounter representation before any production migration. This document decides the representation contract for neutral armies on the adventure map, while keeping current production content and runtime behavior unchanged.

No `content/scenarios.json`, `content/encounters.json`, `content/map_objects.json`, `content/resource_sites.json`, runtime encounter rules, pathing, AI, editor behavior, renderer mapping, generated PNG, or asset import changes are approved by this slice.

## Source Inputs

- `docs/overworld-object-report-review-001.md`
- `docs/overworld-object-schema-migration-plan.md`
- `docs/overworld-object-taxonomy-density.md`
- `docs/strategic-ai-foundation.md`
- `docs/concept-art-implementation-briefs.md`
- Current `content/scenarios.json` encounter placements
- Current `content/encounters.json`
- Current `content/map_objects.json`
- Current `content/resource_sites.json`

## Current Reality

Current scenario encounter placements are direct scenario records, not map-object records.

Compatibility facts:

- `content/scenarios.json` has 15 scenarios.
- There are 48 direct encounter placements across those scenarios.
- Each scenario has 3 encounter placements except `ninefold-confluence`, which has 6.
- Encounter placements currently use `placement_id`, `encounter_id`, `x`, `y`, `difficulty`, `combat_seed`, and sometimes `field_objectives`.
- Encounter placements do not have `object_id`, `map_object_id`, `resource_site_id`, guard-target links, ownership fields, passability class, cleared-state metadata, danger cue metadata, or AI/editor hint fields.
- `content/resource_nodes` carries placed resource/site content separately. There are 127 resource-node placements, also without object ids.
- `content/map_objects.json` has no `primary_class: "neutral_encounter"` records.
- `content/encounters.json` contains reusable encounter definitions and rewards, including normal scenario encounters plus guard encounters referenced by neutral dwelling rosters.
- Current neutral dwelling guard links live in `resource_sites.json` under `neutral_roster.guard_encounter_id` and `guard_army_group_id`, not as visible neutral encounter objects.
- Current guarded reward sites use `guarded` and `guard_profile` on resource-site records, but do not link to a first-class visible guard placement.

Current placement ids must remain the save/routing compatibility anchor until a migration slice explicitly creates object-backed encounter placements.

## Representation Options

### Visible Stack Object

Definition: a visible neutral army/stack is its own 1x1 or compact footprint map object. The object is the combat trigger.

Strengths:

- Best read for route blockers, patrol-ready future behavior, wandering armies, ecology pressure, and simple neutral fights.
- Keeps danger as an army presence rather than a generic camp or building.
- Maps cleanly to `primary_class: "neutral_encounter"` and `passability_class: "neutral_stack_blocking"`.
- Gives AI a direct target to fight, avoid, mark for later, or route around.
- Preserves the object taxonomy rule that neutral encounters are army objects first.

Weaknesses:

- Needs guard-target linkage when the stack is protecting another object, otherwise the reward relationship is ambiguous.
- Needs danger/readability cues so a 1x1 army does not become a tiny unreadable token.
- Can clutter lanes if every placed battle becomes a stack with no relation to terrain or reward.

Best use:

- Chokepoint guards, visible neutral stacks, lane blockers, ecology packs, future patrol seeds, independent reward encounters, and simple direct battles.

### Guarded-Camp Object

Definition: the encounter is represented primarily as a small camp, lair, barricade, or guarded position. The camp object is the combat trigger.

Strengths:

- Good for fixed camps, ruined encampments, ambush nests, tollbreak bivouacs, and reward pockets where the neutral force is tied to a place.
- Easier to show threat state, campfire/activity, and cleared/depleted state as physical scenery.
- Can imply reward categories or region identity through props.

Weaknesses:

- Risks confusing neutral encounters with neutral dwellings, guarded reward buildings, pickups, or persistent sites.
- If overused, the adventure map reads like a board of camps rather than visible armies.
- Weak fit for route blockers and patrol-capable future behavior.
- Can hide the guarded target if the camp and reward site are visually merged.

Best use:

- Fixed encounter sites that are not recruit dwellings, not normal guarded rewards, and not meant to roam: tollbreak camps, wreckclaim crews, reed ambush nests, and fixed battlefield camps.

### Hybrid Representation

Definition: neutral encounter placements support two presentation modes under one first-class object contract:

- `visible_stack` for the default army/route-blocking encounter.
- `camp_anchor` for fixed-place encounter sites.
- `guard_linked_stack` for a visible stack explicitly guarding another object or placement.
- `guard_linked_camp` for a fixed camp guarding another object or placement.

Decision: use the hybrid model as the target, with `visible_stack` as the default and camps as an explicit subtype, not the universal representation.

Why:

- It preserves the taxonomy requirement that neutral encounters are visible army objects first.
- It supports guarded reward and route-blocking use cases without collapsing all danger into buildings.
- It gives the editor and AI one object class to reason about while allowing presentation subtypes.
- It keeps the first migration small: existing direct scenario encounters can be reported as inferred `visible_stack` candidates without rewriting production JSON.

## Target Field Contract

The target neutral encounter object should eventually live in the overworld object contract while preserving links to encounter content.

Recommended shape:

```json
{
  "schema_version": 1,
  "primary_class": "neutral_encounter",
  "secondary_tags": ["route_block", "guarded_reward", "visible_army"],
  "encounter": {
    "encounter_ids": ["encounter_reed_totemists"],
    "primary_encounter_id": "encounter_reed_totemists",
    "difficulty_source": "scenario_placement",
    "combat_seed_source": "scenario_placement"
  },
  "representation": {
    "mode": "visible_stack",
    "footprint_tier": "micro",
    "readability_family": "reed_ambushers",
    "danger_cue_id": "neutral_warning_standard",
    "visible_before_interaction": true,
    "uncertainty_policy": "exact_encounter_known"
  },
  "guard_link": {
    "guard_role": "none",
    "target_kind": "none",
    "target_id": "",
    "target_placement_id": "",
    "blocks_approach": true,
    "clear_required_for_target": false
  },
  "state_model": {
    "initial_state": "idle",
    "state_after_victory": "cleared",
    "state_after_defeat": "active",
    "remove_on_clear": true,
    "remember_after_clear": true
  },
  "placement_ownership": {
    "ownership_model": "neutral_ecology",
    "allowed_owner_kinds": ["neutral"],
    "spawner_kind": "scenario",
    "placement_authority": "scenario"
  },
  "reward_guard_summary": {
    "risk_tier": "standard",
    "reward_categories": ["experience", "small_resource"],
    "resource_reward_ids": ["gold"],
    "guards_reward_tier": "minor"
  },
  "passability": {
    "passability_class": "neutral_stack_blocking",
    "interaction_mode": "enter",
    "blocks_route_until_cleared": true
  },
  "ai_hints": {
    "path_blocking": true,
    "avoid_until_strength": "standard_guard",
    "neutral_clearance_value": 4,
    "guard_target_value_hint": 0
  },
  "editor_placement": {
    "placement_mode": "scenario_encounter_overlay",
    "requires_clear_adjacent_target": false,
    "warn_if_hiding_target": true,
    "density_bucket": "guard_or_encounter"
  }
}
```

This is a target shape, not production JSON to add in this slice.

## Field Meanings

`primary_class`:

- Required target value: `neutral_encounter`.
- Compatibility inference for current `scenarios[].encounters[]` placements should report this class without editing JSON.

Linked encounter ids:

- `primary_encounter_id` points to the content definition in `content/encounters.json`.
- `encounter_ids` allows grouped variants later, but first migration should use one id.
- `difficulty_source` and `combat_seed_source` must preserve current scenario placement fields.

Guard-target links:

- `guard_role`: `none`, `route_block`, `guards_object`, `guards_resource_node`, `guards_artifact_node`, `guards_town_approach`, `guards_scenario_objective`, or `patrol_zone`.
- `target_kind`: `none`, `map_object`, `resource_node`, `artifact_node`, `town`, `scenario_objective`, or `route`.
- `target_id`: content id where stable, such as `site_barrow_vault` or a future object id.
- `target_placement_id`: scenario placement id when the link is placement-specific.
- `blocks_approach`: whether the guard should sit on or before the target approach.
- `clear_required_for_target`: metadata-only until runtime adoption.

Danger and readability cues:

- `representation.mode`: `visible_stack`, `camp_anchor`, `guard_linked_stack`, or `guard_linked_camp`.
- `readability_family`: stable art-direction family such as `tollbreak_band`, `reed_ambushers`, `railjack_raiders`, or `mirror_shard_wardens`.
- `danger_cue_id`: planned cue reference, warning-only until animation cue catalog exists.
- `risk_tier`: `light`, `standard`, `heavy`, `elite`, or `ambush_uncertain`.
- `uncertainty_policy`: `exact_encounter_known`, `tier_known`, `ambush_signaled`, or `scenario_hidden_after_warning`.
- Hidden punishment remains rejected. Ambush uncertainty must still have a visible warning cue.

Cleared state:

- `state_after_victory`: usually `cleared`.
- `remove_on_clear`: true for normal stack objects, false for camp anchors that leave a depleted camp.
- `remember_after_clear`: true so fog memory and save state can distinguish cleared from never-seen later.
- Runtime save state should store mutable placement state by `placement_id`, not by copying authored encounter object blobs.

Placement ownership:

- Default model: `neutral_ecology`.
- Allowed owner for normal neutral encounters: `neutral`.
- Future scenario-spawned or faction-influenced encounters may use `scenario_fixed` or `faction_influenced_neutral`, but not as a first migration requirement.
- Direct conversion of AI raid/hostile faction encounters into neutral encounter objects is out of scope.

Reward and guard summary:

- Summaries should be compact metadata for readability, validation, and AI valuation.
- They must not duplicate all battle or reward content from `content/encounters.json`.
- Target reward categories: `experience`, `small_resource`, `artifact`, `spell_access`, `route_opening`, `persistent_income`, `recruitment`, `scouting_reveal`, and `scenario_progress`.
- Guard summary should distinguish independent encounter rewards from guards protecting another target.

Passability and interaction:

- Default independent stack: `neutral_stack_blocking` with `interaction_mode: "enter"`.
- Camp anchor: usually `blocking_visitable` with adjacent approach, but this should wait for the body-tile/approach planning slice before production adoption.
- Guard-linked stack: blocks path or target approach until cleared as metadata only.
- Current runtime pathing and encounter trigger behavior must remain unchanged until a later explicit adoption slice.

AI placeholders:

- `path_blocking`: advisory only.
- `avoid_until_strength`: advisory tier for future neutral clearance planning.
- `neutral_clearance_value`: relative value, not an override for actual reward/risk scoring.
- `guard_target_value_hint`: optional extra value when linked target lacks full metadata.
- AI adoption must still compute live value from army strength, reward, objective pressure, travel cost, guard cost, exposure risk, and faction profile.

Editor placeholders:

- `placement_mode`: `scenario_encounter_overlay` for compatibility with current direct scenario placements.
- `warn_if_hiding_target`: should become an editor warning when guard links exist.
- `requires_clear_adjacent_target`: warning-only until true approach validation exists.
- Editor overlay can show links and footprint in editor mode only. Normal gameplay must not show helper glyphs or diagnostic panels.

## Scenario Placement Compatibility

The first report/validator follow-up must treat existing direct placement records as the compatibility source.

Current direct encounter placement:

```json
{
  "placement_id": "river_pass_ghoul_grove",
  "encounter_id": "encounter_ghoul_grove",
  "x": 3,
  "y": 1,
  "difficulty": "low",
  "combat_seed": 1201
}
```

Compatibility rule:

- Do not require an object id for existing placement records.
- Infer `primary_class: "neutral_encounter"` for report output only.
- Preserve `placement_id` as the future save-state bridge.
- Preserve `encounter_id`, `difficulty`, `combat_seed`, and `field_objectives`.
- Treat absent guard links as `guard_role: "none"` unless a later hand-authored bundle declares a link.
- Treat absent danger cues as compatibility warnings, not errors.

`ninefold-confluence` currently places 6 encounter records and 47 resource nodes. This broad scaffold is useful for candidate planning, but it is not proof that neutral encounter representation, guard links, approach tiles, or AI valuation are production-ready.

## Save And State Implications

Near-term save compatibility:

- Existing save/runtime behavior must continue using current scenario encounter placement ids and resolved encounter state.
- No save migration is approved by this plan.

Target save model:

- Mutable state belongs under scenario placement state keyed by `placement_id`.
- State fields should include `current_state`, `cleared_by_faction_id`, `cleared_turn`, `battle_result_id`, `reward_claimed`, `remembered_visibility`, and optional `linked_target_unlocked`.
- Authored object metadata should remain content-addressed by object id or inferred placement adapter, not copied into saves.
- Rollback must be possible by ignoring new neutral encounter metadata and reading current scenario encounter placements.

## Validation Stages

Level 0, current compatibility:

- Existing scenarios, encounters, map objects, resource sites, and tests remain valid.
- Current direct encounter placements are accepted without object ids or guard links.

Level 1, additive report planning:

- Add report-only summaries for scenario encounter placements.
- Count placements by scenario, difficulty, repeated encounter id, field objectives, and linked-target absence.
- Warn that no first-class `neutral_encounter` map-object records exist.
- Warn for missing danger cue, representation mode, guard role, reward summary, passability class, AI hints, and editor placement metadata.

Level 2, fixture errors:

- Add non-production fixtures for valid visible stack, camp anchor, guard-linked stack, and invalid missing-link/missing-cue cases.
- Strict errors stay fixture-only.

Level 3, migrated planning bundle errors:

- Only a declared production planning bundle may require target fields.
- Unmigrated production encounter placements remain compatibility-warning-only.

Level 4, production metadata bundle:

- A tiny declared bundle may add metadata to selected production records only after the validator/report plan lands and passes.
- Runtime behavior still remains unchanged.

Level 5, editor/pathing/AI adoption:

- Editor begins checking guard-target placement, approach clarity, and target visibility.
- Pathing and combat trigger adoption only after placement validation proves current maps are safe.
- AI consumes neutral encounter hints only after strategic AI can value fight, avoid, delay, and route-around outcomes.

## Migration Sequence

1. Complete this representation plan.
2. Plan an additive neutral encounter validator/report slice.
3. Implement report-only inference from current `scenarios[].encounters[]`.
4. Add non-production strict fixtures for the four representation modes.
5. Review report output and choose a tiny production planning bundle.
6. Add metadata-only production bundle for a few selected encounter placements or future object records, with no runtime adoption.
7. Plan body-tile/approach interaction for camp anchors and guard-linked placements.
8. Plan editor link visualization and validation warnings.
9. Plan renderer presentation after original art/placeholder direction is approved.
10. Plan AI valuation and pathing adoption only after object placement and save-state compatibility are proven.

## Rollback

Rollback must be one switch at every stage:

- Report-only inference can be removed without touching content.
- Fixture strictness can be disabled without changing production content.
- Production metadata bundle can be ignored by runtime adapters because `placement_id`, `encounter_id`, `difficulty`, and `combat_seed` remain the authoritative compatibility fields.
- No save migration should be required until a later adoption slice proves compatibility.
- If guard-target links create bad placement warnings, links can be reverted independently from encounter definitions.
- If visible stack or camp presentation is rejected, representation metadata can remain while renderer mappings fall back to current encounter rendering.

## First Tiny Candidate Planning Bundle

Do not implement this bundle in this slice.

Candidate bundle id: `neutral_encounter_representation_bundle_001`.

Purpose: exercise direct visible stack compatibility and one guard-linked dwelling-watch candidate without touching production JSON yet.

Candidate records:

| Scenario | Placement id | Encounter id | Proposed mode | Proposed guard role | Reason |
| --- | --- | --- | --- | --- | --- |
| `river-pass` | `river_pass_ghoul_grove` | `encounter_ghoul_grove` | `visible_stack` | `none` | Small known River Pass route fight; good compatibility smoke case. |
| `river-pass` | `river_pass_hollow_mire` | `encounter_hollow_mire` | `visible_stack` | `route_block` | Existing River Pass danger placement that can test route-block summary without object migration. |
| `ninefold-confluence` | `ninefold_basalt_gatehouse_watch` | `encounter_basalt_gatehouse_watch` | `guard_linked_stack` | `guards_resource_node` | Current report recognizes it as the one placed guard-context candidate; useful link-planning case for `site_basalt_gatehouse`. |

Required before implementation:

- Additive validator/report planning must name the report fields and warning policy.
- Confirm whether target links can reference `resource_nodes[].placement_id` or only `site_id` until resource-node object links exist.
- Confirm that direct scenario placements can carry metadata without creating map-object records, or decide that first-class records must live in a separate object-placement table.
- Keep runtime encounter triggering, pathing, AI, editor behavior, and renderer output unchanged.

## Next Slice Recommendation

Next current slice should be neutral encounter additive validator/report planning. It should define report output, compatibility inference, fixture scope, warning/error policy, and CLI expectations before any production content migration.

Production JSON migration, runtime adoption, renderer asset work, generated PNG import, AI behavior changes, pathing/approach changes, and editor behavior changes should remain out of scope.
