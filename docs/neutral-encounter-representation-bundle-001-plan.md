# Neutral Encounter Representation Bundle 001 Plan

Status: planning source only, not implementation.
Date: 2026-04-26.
Slice: neutral-encounter-representation-bundle-planning-10184.
Bundle id: `neutral_encounter_representation_bundle_001`.

## Purpose

Define the exact production metadata shape for the first tiny neutral encounter representation bundle before any production JSON migration.

This plan covers only three current direct scenario encounter placements:

| Scenario | Placement id | Encounter id |
| --- | --- | --- |
| `river-pass` | `river_pass_ghoul_grove` | `encounter_ghoul_grove` |
| `river-pass` | `river_pass_hollow_mire` | `encounter_hollow_mire` |
| `ninefold-confluence` | `ninefold_basalt_gatehouse_watch` | `encounter_basalt_gatehouse_watch` |

No production `content/scenarios.json`, `content/encounters.json`, `content/map_objects.json`, `content/resource_sites.json`, validator/test implementation, runtime encounter behavior, pathing, AI, editor behavior, renderer behavior, save format, generated PNG import, or asset import changes are approved by this planning slice.

## Current Reality

The candidate placements currently live as direct `scenarios[].encounters[]` records. They are not map-object records and they do not have sidecar metadata.

Current placement facts:

| Placement id | Coordinates | Difficulty | Combat seed | Field-objective source |
| --- | --- | --- | --- | --- |
| `river_pass_ghoul_grove` | `3,1` | `low` | `1201` | encounter definition, 1 objective |
| `river_pass_hollow_mire` | `6,4` | `medium` | `1202` | none |
| `ninefold_basalt_gatehouse_watch` | `60,52` | `high` | `16406` | encounter definition, 1 objective |

The Ninefold victory objective `break_basalt_gatehouse` references `ninefold_basalt_gatehouse_watch` by `placement_id`. That objective behavior must remain anchored to the same placement id.

The guarded Ninefold site exists as a resource-node placement:

```json
{
  "placement_id": "dwelling_basalt_gatehouse",
  "site_id": "site_basalt_gatehouse",
  "x": 60,
  "y": 36,
  "collected_by_faction_id": "faction_brasshollow"
}
```

## Attachment Decision

Recommendation: attach the eventual bundle metadata directly to the three scenario encounter placement records as an additive placement extension.

Target field name:

```json
"neutral_encounter": {}
```

Why this is the right first attachment:

- The direct scenario placement is the current authority for `placement_id`, `encounter_id`, coordinates, `difficulty`, `combat_seed`, and any placement-level `field_objectives`.
- Save/routing compatibility already depends on `placement_id`; moving the first metadata to another table would add a link hop before there is a runtime consumer.
- A sidecar file would reduce production JSON churn, but it would create a second authority for scenario placement identity and make rollback/reporting less obvious.
- A first-class `map_object` record is the long-term direction, but it is premature for this bundle because it would imply object placement, body tiles, approach rules, renderer/editor adoption, and pathing questions that are explicitly out of scope.

Compatibility rule: future metadata may be lifted from the scenario placement extension into first-class object placement records later, but this bundle must not require that migration. Until a later object-backed slice, the scenario encounter placement remains the source of truth.

## Exact Metadata Shape

Every migrated placement in this bundle should keep its existing direct placement fields unchanged and add this shape:

```json
{
  "neutral_encounter": {
    "schema_version": 1,
    "bundle_id": "neutral_encounter_representation_bundle_001",
    "primary_class": "neutral_encounter",
    "secondary_tags": [],
    "encounter": {
      "primary_encounter_id": "",
      "encounter_ids": [],
      "difficulty_source": "scenario_placement",
      "combat_seed_source": "scenario_placement",
      "field_objectives_source": "none",
      "preserve_placement_field_objectives": true
    },
    "representation": {
      "mode": "visible_stack",
      "footprint_tier": "micro",
      "readability_family": "",
      "danger_cue_id": "",
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
      "reward_categories": [],
      "resource_reward_ids": [],
      "guards_reward_tier": "none"
    },
    "passability": {
      "passability_class": "neutral_stack_blocking",
      "interaction_mode": "enter",
      "blocks_route_until_cleared": true
    },
    "ai_hints": {
      "path_blocking": true,
      "avoid_until_strength": "standard_guard",
      "neutral_clearance_value": 0,
      "guard_target_value_hint": 0
    },
    "editor_placement": {
      "placement_mode": "scenario_encounter_overlay",
      "requires_clear_adjacent_target": false,
      "warn_if_hiding_target": true,
      "density_bucket": "guard_or_encounter"
    }
  }
}
```

## Guard-Link Convention

Guard links must distinguish stable content ids from scenario placement ids:

- `target_kind`: the target domain. For the basalt gatehouse this must be `resource_node`.
- `target_id`: the stable content id. For the basalt gatehouse this must be `site_basalt_gatehouse`.
- `target_placement_id`: the scenario-local placement id. For the basalt gatehouse this must be `dwelling_basalt_gatehouse`.

The report-only candidate constant that names `site_basalt_gatehouse` should be treated as the content target, not the resource-node placement id. The implementation slice should use both ids so the link can survive either future site-id validation or scenario-placement validation.

For `ninefold_basalt_gatehouse_watch`, the intended link is:

```json
"guard_link": {
  "guard_role": "guards_resource_node",
  "target_kind": "resource_node",
  "target_id": "site_basalt_gatehouse",
  "target_placement_id": "dwelling_basalt_gatehouse",
  "blocks_approach": true,
  "clear_required_for_target": true
}
```

This metadata is descriptive only in the first implementation slice. It must not make the resource node unclaimable, move the guard, alter pathing, or change AI target selection until a later runtime adoption slice.

## Field-Objective Preservation

The metadata must not duplicate or replace battle `field_objectives`.

Rules:

- Keep `placement_id`, `encounter_id`, `difficulty`, and `combat_seed` unchanged.
- Keep encounter-definition `field_objectives` in `content/encounters.json`.
- Keep any placement-level `field_objectives` on the scenario placement if present in a future bundle.
- Set `encounter.field_objectives_source` to `encounter_definition`, `placement_override`, or `none` so validators and reports can detect behavior preservation.
- Set `encounter.preserve_placement_field_objectives` to `true` for every bundle record, even when the current placement has no override.

For this bundle:

- `river_pass_ghoul_grove`: `field_objectives_source: "encounter_definition"`.
- `river_pass_hollow_mire`: `field_objectives_source: "none"`.
- `ninefold_basalt_gatehouse_watch`: `field_objectives_source: "encounter_definition"`.

## Example Metadata Snippets

These snippets are examples only. Do not edit production JSON in this planning slice.

### river_pass_ghoul_grove

```json
{
  "placement_id": "river_pass_ghoul_grove",
  "encounter_id": "encounter_ghoul_grove",
  "x": 3,
  "y": 1,
  "difficulty": "low",
  "combat_seed": 1201,
  "neutral_encounter": {
    "schema_version": 1,
    "bundle_id": "neutral_encounter_representation_bundle_001",
    "primary_class": "neutral_encounter",
    "secondary_tags": ["visible_army", "route_pressure"],
    "encounter": {
      "primary_encounter_id": "encounter_ghoul_grove",
      "encounter_ids": ["encounter_ghoul_grove"],
      "difficulty_source": "scenario_placement",
      "combat_seed_source": "scenario_placement",
      "field_objectives_source": "encounter_definition",
      "preserve_placement_field_objectives": true
    },
    "representation": {
      "mode": "visible_stack",
      "footprint_tier": "micro",
      "readability_family": "bramble_grove_raiders",
      "danger_cue_id": "neutral_warning_light",
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
      "risk_tier": "light",
      "reward_categories": ["gold", "small_resource", "experience"],
      "resource_reward_ids": ["gold"],
      "guards_reward_tier": "none"
    },
    "passability": {
      "passability_class": "neutral_stack_blocking",
      "interaction_mode": "enter",
      "blocks_route_until_cleared": true
    },
    "ai_hints": {
      "path_blocking": true,
      "avoid_until_strength": "light_guard",
      "neutral_clearance_value": 2,
      "guard_target_value_hint": 0
    },
    "editor_placement": {
      "placement_mode": "scenario_encounter_overlay",
      "requires_clear_adjacent_target": false,
      "warn_if_hiding_target": true,
      "density_bucket": "guard_or_encounter"
    }
  }
}
```

### river_pass_hollow_mire

```json
{
  "placement_id": "river_pass_hollow_mire",
  "encounter_id": "encounter_hollow_mire",
  "x": 6,
  "y": 4,
  "difficulty": "medium",
  "combat_seed": 1202,
  "neutral_encounter": {
    "schema_version": 1,
    "bundle_id": "neutral_encounter_representation_bundle_001",
    "primary_class": "neutral_encounter",
    "secondary_tags": ["visible_army", "route_block", "mire_pressure"],
    "encounter": {
      "primary_encounter_id": "encounter_hollow_mire",
      "encounter_ids": ["encounter_hollow_mire"],
      "difficulty_source": "scenario_placement",
      "combat_seed_source": "scenario_placement",
      "field_objectives_source": "none",
      "preserve_placement_field_objectives": true
    },
    "representation": {
      "mode": "visible_stack",
      "footprint_tier": "micro",
      "readability_family": "hollow_mire_pack",
      "danger_cue_id": "neutral_warning_standard",
      "visible_before_interaction": true,
      "uncertainty_policy": "exact_encounter_known"
    },
    "guard_link": {
      "guard_role": "route_block",
      "target_kind": "route",
      "target_id": "river_pass_mire_lane",
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
      "reward_categories": ["gold", "small_resource", "resource", "experience", "route_opening"],
      "resource_reward_ids": ["gold", "ore"],
      "guards_reward_tier": "route"
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
      "guard_target_value_hint": 1
    },
    "editor_placement": {
      "placement_mode": "scenario_encounter_overlay",
      "requires_clear_adjacent_target": false,
      "warn_if_hiding_target": true,
      "density_bucket": "guard_or_encounter"
    }
  }
}
```

### ninefold_basalt_gatehouse_watch

```json
{
  "placement_id": "ninefold_basalt_gatehouse_watch",
  "encounter_id": "encounter_basalt_gatehouse_watch",
  "x": 60,
  "y": 52,
  "difficulty": "high",
  "combat_seed": 16406,
  "neutral_encounter": {
    "schema_version": 1,
    "bundle_id": "neutral_encounter_representation_bundle_001",
    "primary_class": "neutral_encounter",
    "secondary_tags": ["visible_army", "guarded_reward", "neutral_dwelling_watch", "scenario_objective_guard"],
    "encounter": {
      "primary_encounter_id": "encounter_basalt_gatehouse_watch",
      "encounter_ids": ["encounter_basalt_gatehouse_watch"],
      "difficulty_source": "scenario_placement",
      "combat_seed_source": "scenario_placement",
      "field_objectives_source": "encounter_definition",
      "preserve_placement_field_objectives": true
    },
    "representation": {
      "mode": "guard_linked_stack",
      "footprint_tier": "micro",
      "readability_family": "basalt_gatehouse_custodians",
      "danger_cue_id": "neutral_warning_heavy",
      "visible_before_interaction": true,
      "uncertainty_policy": "exact_encounter_known"
    },
    "guard_link": {
      "guard_role": "guards_resource_node",
      "target_kind": "resource_node",
      "target_id": "site_basalt_gatehouse",
      "target_placement_id": "dwelling_basalt_gatehouse",
      "blocks_approach": true,
      "clear_required_for_target": true
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
      "risk_tier": "heavy",
      "reward_categories": ["gold", "small_resource", "resource", "experience", "recruitment", "scenario_progress"],
      "resource_reward_ids": ["gold", "ore"],
      "guards_reward_tier": "major"
    },
    "passability": {
      "passability_class": "neutral_stack_blocking",
      "interaction_mode": "enter",
      "blocks_route_until_cleared": true
    },
    "ai_hints": {
      "path_blocking": true,
      "avoid_until_strength": "heavy_guard",
      "neutral_clearance_value": 7,
      "guard_target_value_hint": 5
    },
    "editor_placement": {
      "placement_mode": "scenario_encounter_overlay",
      "requires_clear_adjacent_target": false,
      "warn_if_hiding_target": true,
      "density_bucket": "guard_or_encounter"
    }
  }
}
```

## Validation Level

The next implementation slice should activate migrated-bundle validation only for these three placement extensions.

Required migrated-bundle errors:

- Missing one of the three declared placements.
- Changed `placement_id`, `encounter_id`, `difficulty`, or `combat_seed`.
- Missing `neutral_encounter.schema_version: 1`.
- Missing or wrong `bundle_id`.
- Missing `primary_class: "neutral_encounter"`.
- Missing `encounter.primary_encounter_id`, or mismatch with the existing `encounter_id`.
- `encounter.encounter_ids` does not include the existing `encounter_id`.
- `difficulty_source` or `combat_seed_source` is not `scenario_placement`.
- Missing `field_objectives_source` or `preserve_placement_field_objectives`.
- Missing or invalid `representation.mode`, `readability_family`, `danger_cue_id`, or `visible_before_interaction`.
- Missing `guard_link`.
- For `ninefold_basalt_gatehouse_watch`, missing `guard_role: "guards_resource_node"`, `target_kind: "resource_node"`, `target_id: "site_basalt_gatehouse"`, `target_placement_id: "dwelling_basalt_gatehouse"`, or `clear_required_for_target: true`.
- Missing `state_model`, `placement_ownership`, `reward_guard_summary`, `passability`, `ai_hints`, or `editor_placement`.

Remain warnings or out of scope:

- Runtime pathing conflicts.
- True approach-tile validation.
- Renderer cue availability.
- AI valuation correctness.
- Save migration.
- Script-spawned encounter representation.
- Unmigrated production direct placements outside this bundle.

## Report Expectations

After a future implementation slice, the opt-in neutral encounter report should still be a compatibility report, but it should distinguish authored bundle metadata from inferred metadata.

Expected report changes for this bundle:

- `candidate_bundles.neutral_encounter_representation_bundle_001.status` should move from `planning_only` to `metadata_authored` or equivalent.
- The three candidate placements should report `representation_metadata_present: true`, `danger_cue_present: true`, `guard_link_present: true`, and `candidate_bundle_id: "neutral_encounter_representation_bundle_001"`.
- Missing future metadata counts should drop from `48` to `45` for fields authored by the bundle.
- Representation mode counts should include two authored `visible_stack` placements and one authored `guard_linked_stack` placement, while unmigrated placements remain inferred `visible_stack`.
- Guard-link reporting should show one authored `guards_resource_node`, one authored `route_block`, one authored `none`, and the remaining unmigrated placements as inferred none.
- Warning count may remain high because 45 production placements are still unmigrated compatibility records.

## Rollback

Rollback must be a small content revert:

- Remove the `neutral_encounter` extension from the three scenario placement records.
- Leave `placement_id`, `encounter_id`, `x`, `y`, `difficulty`, `combat_seed`, and any `field_objectives` untouched.
- Leave `content/encounters.json`, `content/map_objects.json`, and `content/resource_sites.json` untouched.
- Default validation and runtime behavior should return to the current direct-placement compatibility path.
- No save migration rollback should be needed because no save schema change is approved.

## Exact Non-Change Boundaries

This planning slice and the next metadata-only implementation slice must not:

- Move encounter placements into `content/map_objects.json`.
- Create a sidecar file as a second production authority.
- Migrate `content/encounters.json` rewards, armies, commanders, battlefield tags, or field objectives.
- Change direct scenario encounter trigger behavior.
- Change victory or defeat objective behavior.
- Change resource-node claim behavior for `dwelling_basalt_gatehouse`.
- Change pathing, body tiles, approach tiles, occupancy, route costs, or movement blockers.
- Change renderer assets, sprites, cue drawing, editor overlays, or visible helper glyphs.
- Change strategic AI, raid targeting, neutral encounter valuation, or enemy turns.
- Change save/load behavior or save format.
- Import generated PNGs or runtime assets.
- Add validator/test implementation in this planning slice.

## Next Slice

Proceed next with metadata-only implementation for `neutral_encounter_representation_bundle_001`, limited to the three declared scenario encounter placement extensions and matching migrated-bundle validation/report updates.

If implementation finds that placement extensions cannot be validated cleanly without touching runtime behavior, stop and add a prerequisite validator-only correction slice instead of migrating production JSON.
