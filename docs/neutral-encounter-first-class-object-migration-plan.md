# Neutral Encounter First-Class Object Migration Plan

Status: planning source only, not implementation.
Date: 2026-04-26.
Slice: neutral-encounter-first-class-object-planning-10184.

## Purpose

Define the migration boundary between current scenario encounter placement metadata and future first-class neutral encounter object records.

This plan does not approve production content JSON migration, validator/test implementation, runtime encounter behavior changes, pathing/body-tile/occupancy changes, AI behavior changes, editor behavior changes, renderer behavior changes, save migration, generated PNG import, or asset import.

## Current Boundary

Current production neutral encounters are direct scenario encounter placements. The current authority is still:

- `scenarios[].encounters[].placement_id`
- `encounter_id`
- scenario coordinates `x` and `y`
- `difficulty`
- `combat_seed`
- placement-level `field_objectives` when authored
- encounter-definition `field_objectives` when no placement override exists

`neutral_encounter_representation_bundle_001` added authored representation metadata to three direct scenario placements only:

| Scenario | Placement id | Encounter id | Current metadata authority |
| --- | --- | --- | --- |
| `river-pass` | `river_pass_ghoul_grove` | `encounter_ghoul_grove` | Scenario encounter placement extension. |
| `river-pass` | `river_pass_hollow_mire` | `encounter_hollow_mire` | Scenario encounter placement extension. |
| `ninefold-confluence` | `ninefold_basalt_gatehouse_watch` | `encounter_basalt_gatehouse_watch` | Scenario encounter placement extension with guard target link. |

The opt-in report still shows `0` first-class `primary_class: "neutral_encounter"` map-object records. That absence is compatibility-warning debt, not an error.

## Placement Metadata Versus First-Class Objects

Representation metadata should remain on scenario encounter placements when:

- The encounter is already authored as a direct `scenarios[].encounters[]` placement and no runtime system consumes object-backed placement yet.
- The slice is only adding representation, danger cue, guard summary, passability summary, AI hints, or editor hints for report and validation visibility.
- The encounter is scenario-specific and has no reusable object identity beyond its placement.
- The metadata must preserve current `placement_id`, `encounter_id`, `difficulty`, `combat_seed`, coordinates, and field-objective behavior without creating a second authority.
- The guard target is descriptive only and does not yet alter target availability, route blocking, pathing, renderer output, or AI scoring.
- Rollback must be possible by deleting or ignoring the `neutral_encounter` placement extension.

Metadata should move to first-class object or object-placement records when one or more of these become true:

- The encounter must be edited, searched, placed, duplicated, or linked by the map editor as an object rather than as a special scenario encounter list entry.
- The encounter needs object schema fields that belong with map objects: `object_id`, `object_placement_id`, `primary_class`, `secondary_tags`, footprint, body tiles, approach, passability class, interaction cadence, art-direction family, renderer hint, or editor placement rules.
- The encounter guards, blocks, unlocks, or visually relates to another placed object, resource node, artifact node, town, route, or objective and the link needs validation beyond advisory report text.
- Renderer, pathing, AI, or save systems are ready to consume a common object-placement surface for neutral stacks, camp anchors, guarded sites, and route blockers.
- Multiple scenario placements intentionally share a neutral encounter object template while retaining distinct placement ids, coordinates, seeds, difficulty, and objective context.

Do not move a production encounter into a first-class object record just to reduce report warnings. The migration must buy a real future boundary: editor placement, object validation, renderer readiness, pathing readiness, AI valuation, or save-state clarity.

## Target Record Shape

Future first-class neutral encounter records should separate reusable object definition from scenario placement identity.

Recommended map-object definition shape:

```json
{
  "id": "object_neutral_encounter_hollow_mire_stack",
  "schema_version": 1,
  "primary_class": "neutral_encounter",
  "secondary_tags": ["visible_army", "route_block", "mire_pressure"],
  "family": "neutral_encounter",
  "subtype": "visible_stack",
  "art_direction_family": "hollow_mire_pack",
  "footprint": {"width": 1, "height": 1, "anchor": "bottom_center", "tier": "micro"},
  "passable": false,
  "visitable": true,
  "passability_class": "neutral_stack_blocking",
  "interaction": {
    "cadence": "one_time",
    "remains_after_visit": false,
    "state_after_visit": "cleared",
    "requires_ownership": false,
    "requires_guard_clear": false,
    "supports_revisit": false,
    "cooldown_days": 0,
    "refresh_rule": "none"
  },
  "neutral_encounter": {
    "representation": {
      "mode": "visible_stack",
      "readability_family": "hollow_mire_pack",
      "danger_cue_id": "neutral_warning_standard",
      "visible_before_interaction": true,
      "uncertainty_policy": "exact_encounter_known"
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
    }
  }
}
```

Recommended scenario object-placement shape:

```json
{
  "placement_id": "river_pass_hollow_mire",
  "object_id": "object_neutral_encounter_hollow_mire_stack",
  "object_placement_id": "object_placement_river_pass_hollow_mire",
  "primary_class": "neutral_encounter",
  "x": 6,
  "y": 4,
  "encounter_ref": {
    "encounter_id": "encounter_hollow_mire",
    "primary_encounter_id": "encounter_hollow_mire",
    "encounter_ids": ["encounter_hollow_mire"],
    "difficulty": "medium",
    "difficulty_source": "scenario_placement",
    "combat_seed": 1202,
    "combat_seed_source": "scenario_placement",
    "field_objectives_source": "none",
    "preserve_placement_field_objectives": true
  },
  "legacy_scenario_encounter_ref": {
    "placement_id": "river_pass_hollow_mire",
    "encounter_id": "encounter_hollow_mire",
    "source_list": "scenarios.encounters"
  },
  "guard_link": {
    "guard_role": "route_block",
    "target_kind": "route",
    "target_id": "river_pass_mire_lane",
    "target_placement_id": "",
    "blocks_approach": true,
    "clear_required_for_target": false
  },
  "reward_guard_summary": {
    "risk_tier": "standard",
    "reward_categories": ["gold", "small_resource", "resource", "experience", "route_opening"],
    "resource_reward_ids": ["gold", "ore"],
    "guards_reward_tier": "route"
  },
  "authored_metadata": {
    "bundle_id": "neutral_encounter_first_class_object_bundle_001",
    "lifted_from_bundle_id": "neutral_encounter_representation_bundle_001"
  }
}
```

The object definition should own reusable object-schema metadata. The scenario object placement should own scenario-local identity, coordinates, encounter binding, difficulty, combat seed, field-objective source, guard target placement links, and compatibility back to the old direct scenario encounter placement.

## Identifier Rules

`placement_id` remains the save and objective compatibility anchor until a later save migration is explicitly approved.

`object_id` identifies the reusable first-class map-object definition. It should be stable across scenarios only when the visual/object behavior is genuinely reusable.

`object_placement_id` identifies the scenario-local object placement if the editor or object-placement table needs a distinct id from legacy `placement_id`. For the first migration bundle, it should be a deterministic wrapper id such as `object_placement_<placement_id>`.

`encounter_id` remains the combat content source in `content/encounters.json`. Do not duplicate army stacks, battlefield tags, rewards, commanders, or field objectives into object metadata.

`primary_encounter_id` and `encounter_ids` may exist in object-backed metadata for grouped variants, but the first migrated object bundle should use exactly one encounter id per placement.

`scenario_id`, `x`, and `y` remain scenario placement data. Reusable map-object definitions must not carry scenario coordinates.

Field-objective links must preserve source:

- `none`
- `encounter_definition`
- `placement_override`

Guard target ids must distinguish content ids from scenario-local placement ids:

| Target kind | `target_id` | `target_placement_id` |
| --- | --- | --- |
| `resource_node` | Resource-site content id, such as `site_basalt_gatehouse`. | Scenario resource-node placement id, such as `dwelling_basalt_gatehouse`. |
| `map_object` | Object definition id. | Scenario object placement id when available. |
| `artifact_node` | Artifact content id. | Scenario artifact-node placement id. |
| `town` | Town content id when stable. | Scenario town placement id. |
| `scenario_objective` | Objective id. | Optional placement id tied to the objective. |
| `route` | Stable route or lane id. | Optional endpoint placement id. |

The basalt gatehouse convention remains the compatibility example: `target_kind: "resource_node"`, `target_id: "site_basalt_gatehouse"`, and `target_placement_id: "dwelling_basalt_gatehouse"`.

## Existing Bundle Compatibility

The three authored `neutral_encounter_representation_bundle_001` placement metadata records should remain valid after first-class object planning.

Compatibility strategy:

- Do not rewrite the three records in this slice.
- Treat the current scenario placement metadata as the source for any future lifted object-backed planning bundle.
- If a future first-class object bundle includes one of these placements, copy the authored representation, guard link, state model, ownership, reward summary, passability summary, AI hints, and editor hints into the object/object-placement structure while retaining the original scenario encounter placement as a compatibility source.
- The future report should be able to show `lifted_from_bundle_id: "neutral_encounter_representation_bundle_001"` so reviewers can distinguish an object-backed migration from a brand-new metadata decision.
- During transition, duplicate metadata may exist in both the legacy scenario placement extension and the object-backed placement only inside a declared migrated bundle. The validator should require exact agreement or an explicit deprecation marker for that bundle.
- Rollback should remove or ignore object-backed records first; the existing scenario placement metadata should still preserve the authored report state for the three records.

The remaining 45 direct encounter placements stay compatibility-warning-only until another bundle is declared.

## Validation Levels

Level 0, current compatibility:

- Direct scenario encounter placements remain accepted without first-class object records.
- `neutral_encounter_representation_bundle_001` remains strict only for the existing three authored placement extensions.
- No default validation failure for missing first-class objects.

Level 1, object migration report-only:

- Extend the opt-in neutral encounter report to distinguish direct-only placements, scenario-metadata placements, object-backed placements, and lifted records.
- Count missing `object_id`, missing `object_placement_id`, missing lifted metadata agreement, missing guard target resolution, and missing object schema fields as warnings.
- Keep production direct placements compatibility-warning-only.

Level 2, strict fixtures:

- Add non-production fixtures for object-backed `visible_stack`, `camp_anchor`, `guard_linked_stack`, and `guard_linked_camp`.
- Include invalid fixture cases for missing `object_id`, missing legacy `placement_id` bridge, missing encounter ref, mismatched field-objective source, mismatched guard target ids, and duplicate scenario/object authority disagreement.
- Keep fixture strictness outside production content.

Level 3, one tiny production planning bundle:

- Choose one to three placements for `neutral_encounter_first_class_object_bundle_001`.
- Prefer lifting existing authored placements before migrating unrelated broad content.
- Define object ids, object placement ids, lifted metadata, and guard-target conventions in a planning document only.

Level 4, metadata-only production object records:

- Add object-backed metadata for the declared tiny bundle only.
- Runtime remains on legacy scenario encounter placement behavior.
- The report should mark the bundle as metadata-authored object-backed records while adapters still show runtime, pathing, renderer, editor, AI, and save migration inactive.

Level 5, report review:

- Review warning counts, lifted metadata agreement, guard target resolution, and rollback behavior.
- Decide whether a second tiny object-backed bundle is useful or whether body/approach planning should come next.

Level 6, later runtime adoption:

- Only after review should later slices plan pathing/body tiles, renderer presentation, editor placement, AI valuation, and save adoption.
- These are separate adoption gates, not side effects of metadata migration.

## Staged Migration Sequence

1. Complete this planning boundary.
2. Implement report-only and strict fixture support for first-class neutral encounter object records, with no production JSON migration.
3. Review that report/fixture output.
4. Plan one tiny production first-class object bundle, likely by lifting existing authored placement metadata.
5. Add metadata-only production object-backed records for that tiny bundle, with runtime behavior still reading current scenario encounter placements.
6. Review object-backed report output and rollback clarity.
7. Plan body-tile and approach metadata for neutral stack and camp modes.
8. Plan editor link visualization and placement validation.
9. Plan renderer adoption after art/placeholder direction and cue availability are approved.
10. Plan strategic AI valuation for fight, avoid, delay, and route-around decisions.
11. Plan save migration only after object-backed placement identity and mutable state behavior are proven.

## Rollback Expectations

Rollback must remain one-step at each level:

- Report-only additions can be disabled without content changes.
- Strict fixture checks can be removed without touching production content.
- A planning bundle can be abandoned by deleting the planning document.
- Metadata-only object records can be ignored while current scenario encounter placements remain authoritative.
- If object-backed metadata disagrees with lifted scenario metadata, reject the bundle rather than silently choosing one side.
- Runtime adapters must not require object-backed records until a later adoption slice explicitly changes behavior.
- Save migration must not start until rollback has a tested path from object-backed state to `placement_id`-keyed legacy state.

## Next Concrete Slice

Implement opt-in first-class neutral encounter object report and strict fixture scaffolding.

That slice should extend neutral encounter reporting to identify direct-only, scenario-metadata, and object-backed records; add non-production strict fixtures for object-backed records; and keep all production JSON migration, runtime encounter behavior, pathing, renderer, editor, AI, save migration, generated PNG import, and asset import out of scope.
