# Neutral Encounter First-Class Object Bundle 001 Plan

Status: planning source only, not implementation.
Date: 2026-04-26.
Slice: neutral-encounter-first-class-object-bundle-planning-10184.
Bundle id: `neutral_encounter_first_class_object_bundle_001`.

## Purpose

Plan the smallest object-backed neutral encounter bundle by lifting the three authored `neutral_encounter_representation_bundle_001` scenario-placement metadata records into proposed first-class object records.

This plan does not approve production content JSON migration, validator/test implementation, runtime encounter behavior changes, pathing/body-tile/approach adoption, AI behavior changes, editor behavior changes, renderer behavior changes, save behavior changes, generated PNG import, or asset import.

## Scope

Exactly three placements are in scope:

| Scenario | Legacy placement id | Encounter id | Proposed object id | Proposed object placement id |
| --- | --- | --- | --- | --- |
| `river-pass` | `river_pass_ghoul_grove` | `encounter_ghoul_grove` | `object_neutral_encounter_river_pass_ghoul_grove_stack` | `object_placement_river_pass_ghoul_grove` |
| `river-pass` | `river_pass_hollow_mire` | `encounter_hollow_mire` | `object_neutral_encounter_river_pass_hollow_mire_stack` | `object_placement_river_pass_hollow_mire` |
| `ninefold-confluence` | `ninefold_basalt_gatehouse_watch` | `encounter_basalt_gatehouse_watch` | `object_neutral_encounter_ninefold_basalt_gatehouse_watch_stack` | `object_placement_ninefold_basalt_gatehouse_watch` |

These object ids are intentionally scenario-specific. They should not be reused across scenarios until a later slice proves reusable neutral encounter object definitions.

## Source Metadata Agreement

The lifted source is the current authored `neutral_encounter` metadata on the three direct scenario encounter placements in `content/scenarios.json`.

The object-backed lift must preserve these facts exactly:

| Placement id | Coordinates | Difficulty | Combat seed | Representation | Guard role | Field-objective source |
| --- | ---: | --- | ---: | --- | --- | --- |
| `river_pass_ghoul_grove` | `3,1` | `low` | 1201 | `visible_stack` | `none` | `encounter_definition` |
| `river_pass_hollow_mire` | `6,4` | `medium` | 1202 | `visible_stack` | `route_block` | `none` |
| `ninefold_basalt_gatehouse_watch` | `60,52` | `high` | 16406 | `guard_linked_stack` | `guards_resource_node` | `encounter_definition` |

Lifted agreement rule:

- Keep the original scenario encounter placement fields unchanged: `placement_id`, `encounter_id`, `x`, `y`, `difficulty`, and `combat_seed`.
- Keep `legacy_scenario_encounter_ref.placement_id` equal to the legacy `placement_id`.
- Keep `encounter_ref.encounter_id`, `primary_encounter_id`, and single-item `encounter_ids` equal to the current `encounter_id`.
- Keep `encounter_ref.difficulty`, `difficulty_source`, `combat_seed`, `combat_seed_source`, `field_objectives_source`, and `preserve_placement_field_objectives` in agreement with the authored source.
- Copy the authored `neutral_encounter` representation, guard link, state model, placement ownership, reward summary, passability, AI hints, and editor placement metadata into the object record without changing meaning.
- Record object-backed provenance as `authored_metadata.bundle_id: "neutral_encounter_first_class_object_bundle_001"` and `authored_metadata.lifted_from_bundle_id: "neutral_encounter_representation_bundle_001"`.

## Object Schema Fields

Every proposed object definition in this bundle should include:

- `id`: proposed object id from this plan.
- `schema_version`: `1`.
- `primary_class`: `neutral_encounter`.
- `secondary_tags`: exact source `neutral_encounter.secondary_tags`.
- `family`: `neutral_encounter`.
- `subtype`: exact source `neutral_encounter.representation.mode`.
- `footprint`: `{ "width": 1, "height": 1, "anchor": "bottom_center", "tier": "micro" }`.
- `passable`: `false`.
- `visitable`: `true`.
- `passability_class`: exact source `neutral_encounter.passability.passability_class`.
- `interaction`: one-time neutral stack metadata: `cadence: "one_time"`, `remains_after_visit: false`, `state_after_visit: "cleared"`, `requires_ownership: false`, `requires_guard_clear: false`, `supports_revisit: false`, `cooldown_days: 0`, `refresh_rule: "none"`.
- `neutral_encounter`: the lifted source metadata with an added `lifted_from_bundle_id` note only if the later implementation validator requires it. Any added provenance must not alter representation, guard, state, ownership, reward, passability, AI, or editor semantics.

Do not add `body_tiles`, `approach`, route effects, animation cue ids, renderer hints, AI valuation formulas, save-state fields, or editor placement adoption in this bundle.

## Guard-Target Convention

The basalt gatehouse link remains the canonical guard-target convention:

```json
{
  "guard_role": "guards_resource_node",
  "target_kind": "resource_node",
  "target_id": "site_basalt_gatehouse",
  "target_placement_id": "dwelling_basalt_gatehouse",
  "blocks_approach": true,
  "clear_required_for_target": true
}
```

`target_id` is the stable resource-site content id. `target_placement_id` is the scenario-local resource node placement id. In `ninefold-confluence`, `dwelling_basalt_gatehouse` resolves to `site_basalt_gatehouse`.

`river_pass_hollow_mire` keeps the advisory route target:

```json
{
  "guard_role": "route_block",
  "target_kind": "route",
  "target_id": "river_pass_mire_lane",
  "target_placement_id": "",
  "blocks_approach": true,
  "clear_required_for_target": false
}
```

`river_pass_ghoul_grove` keeps `target_kind: "none"` and an empty target.

## Proposed Object-Backed Snippets

These snippets are proposed records only. Do not edit production JSON in this planning slice.

### river_pass_ghoul_grove

```json
{
  "object": {
    "id": "object_neutral_encounter_river_pass_ghoul_grove_stack",
    "schema_version": 1,
    "primary_class": "neutral_encounter",
    "secondary_tags": ["visible_army", "route_pressure"],
    "family": "neutral_encounter",
    "subtype": "visible_stack",
    "footprint": {"width": 1, "height": 1, "anchor": "bottom_center", "tier": "micro"},
    "passable": false,
    "visitable": true,
    "passability_class": "neutral_stack_blocking",
    "interaction": {"cadence": "one_time", "remains_after_visit": false, "state_after_visit": "cleared", "requires_ownership": false, "requires_guard_clear": false, "supports_revisit": false, "cooldown_days": 0, "refresh_rule": "none"},
    "neutral_encounter": {
      "schema_version": 1,
      "bundle_id": "neutral_encounter_representation_bundle_001",
      "primary_class": "neutral_encounter",
      "secondary_tags": ["visible_army", "route_pressure"],
      "encounter": {"primary_encounter_id": "encounter_ghoul_grove", "encounter_ids": ["encounter_ghoul_grove"], "difficulty_source": "scenario_placement", "combat_seed_source": "scenario_placement", "field_objectives_source": "encounter_definition", "preserve_placement_field_objectives": true},
      "representation": {"mode": "visible_stack", "footprint_tier": "micro", "readability_family": "bramble_grove_raiders", "danger_cue_id": "neutral_warning_light", "visible_before_interaction": true, "uncertainty_policy": "exact_encounter_known"},
      "guard_link": {"guard_role": "none", "target_kind": "none", "target_id": "", "target_placement_id": "", "blocks_approach": true, "clear_required_for_target": false},
      "state_model": {"initial_state": "idle", "state_after_victory": "cleared", "state_after_defeat": "active", "remove_on_clear": true, "remember_after_clear": true},
      "placement_ownership": {"ownership_model": "neutral_ecology", "allowed_owner_kinds": ["neutral"], "spawner_kind": "scenario", "placement_authority": "scenario"},
      "reward_guard_summary": {"risk_tier": "light", "reward_categories": ["gold", "small_resource", "experience"], "resource_reward_ids": ["gold"], "guards_reward_tier": "none"},
      "passability": {"passability_class": "neutral_stack_blocking", "interaction_mode": "enter", "blocks_route_until_cleared": true},
      "ai_hints": {"path_blocking": true, "avoid_until_strength": "light_guard", "neutral_clearance_value": 2, "guard_target_value_hint": 0},
      "editor_placement": {"placement_mode": "scenario_encounter_overlay", "requires_clear_adjacent_target": false, "warn_if_hiding_target": true, "density_bucket": "guard_or_encounter"}
    }
  },
  "scenario_placement": {
    "placement_id": "river_pass_ghoul_grove",
    "object_id": "object_neutral_encounter_river_pass_ghoul_grove_stack",
    "object_placement_id": "object_placement_river_pass_ghoul_grove",
    "primary_class": "neutral_encounter",
    "x": 3,
    "y": 1,
    "encounter_ref": {"encounter_id": "encounter_ghoul_grove", "primary_encounter_id": "encounter_ghoul_grove", "encounter_ids": ["encounter_ghoul_grove"], "difficulty": "low", "difficulty_source": "scenario_placement", "combat_seed": 1201, "combat_seed_source": "scenario_placement", "field_objectives_source": "encounter_definition", "preserve_placement_field_objectives": true},
    "legacy_scenario_encounter_ref": {"placement_id": "river_pass_ghoul_grove", "encounter_id": "encounter_ghoul_grove", "source_list": "scenarios.encounters"},
    "guard_link": {"guard_role": "none", "target_kind": "none", "target_id": "", "target_placement_id": "", "blocks_approach": true, "clear_required_for_target": false},
    "authored_metadata": {"bundle_id": "neutral_encounter_first_class_object_bundle_001", "lifted_from_bundle_id": "neutral_encounter_representation_bundle_001"}
  }
}
```

### river_pass_hollow_mire

```json
{
  "object": {
    "id": "object_neutral_encounter_river_pass_hollow_mire_stack",
    "schema_version": 1,
    "primary_class": "neutral_encounter",
    "secondary_tags": ["visible_army", "route_block", "mire_pressure"],
    "family": "neutral_encounter",
    "subtype": "visible_stack",
    "footprint": {"width": 1, "height": 1, "anchor": "bottom_center", "tier": "micro"},
    "passable": false,
    "visitable": true,
    "passability_class": "neutral_stack_blocking",
    "interaction": {"cadence": "one_time", "remains_after_visit": false, "state_after_visit": "cleared", "requires_ownership": false, "requires_guard_clear": false, "supports_revisit": false, "cooldown_days": 0, "refresh_rule": "none"},
    "neutral_encounter": {
      "schema_version": 1,
      "bundle_id": "neutral_encounter_representation_bundle_001",
      "primary_class": "neutral_encounter",
      "secondary_tags": ["visible_army", "route_block", "mire_pressure"],
      "encounter": {"primary_encounter_id": "encounter_hollow_mire", "encounter_ids": ["encounter_hollow_mire"], "difficulty_source": "scenario_placement", "combat_seed_source": "scenario_placement", "field_objectives_source": "none", "preserve_placement_field_objectives": true},
      "representation": {"mode": "visible_stack", "footprint_tier": "micro", "readability_family": "hollow_mire_pack", "danger_cue_id": "neutral_warning_standard", "visible_before_interaction": true, "uncertainty_policy": "exact_encounter_known"},
      "guard_link": {"guard_role": "route_block", "target_kind": "route", "target_id": "river_pass_mire_lane", "target_placement_id": "", "blocks_approach": true, "clear_required_for_target": false},
      "state_model": {"initial_state": "idle", "state_after_victory": "cleared", "state_after_defeat": "active", "remove_on_clear": true, "remember_after_clear": true},
      "placement_ownership": {"ownership_model": "neutral_ecology", "allowed_owner_kinds": ["neutral"], "spawner_kind": "scenario", "placement_authority": "scenario"},
      "reward_guard_summary": {"risk_tier": "standard", "reward_categories": ["gold", "small_resource", "resource", "experience", "route_opening"], "resource_reward_ids": ["gold", "ore"], "guards_reward_tier": "route"},
      "passability": {"passability_class": "neutral_stack_blocking", "interaction_mode": "enter", "blocks_route_until_cleared": true},
      "ai_hints": {"path_blocking": true, "avoid_until_strength": "standard_guard", "neutral_clearance_value": 4, "guard_target_value_hint": 1},
      "editor_placement": {"placement_mode": "scenario_encounter_overlay", "requires_clear_adjacent_target": false, "warn_if_hiding_target": true, "density_bucket": "guard_or_encounter"}
    }
  },
  "scenario_placement": {
    "placement_id": "river_pass_hollow_mire",
    "object_id": "object_neutral_encounter_river_pass_hollow_mire_stack",
    "object_placement_id": "object_placement_river_pass_hollow_mire",
    "primary_class": "neutral_encounter",
    "x": 6,
    "y": 4,
    "encounter_ref": {"encounter_id": "encounter_hollow_mire", "primary_encounter_id": "encounter_hollow_mire", "encounter_ids": ["encounter_hollow_mire"], "difficulty": "medium", "difficulty_source": "scenario_placement", "combat_seed": 1202, "combat_seed_source": "scenario_placement", "field_objectives_source": "none", "preserve_placement_field_objectives": true},
    "legacy_scenario_encounter_ref": {"placement_id": "river_pass_hollow_mire", "encounter_id": "encounter_hollow_mire", "source_list": "scenarios.encounters"},
    "guard_link": {"guard_role": "route_block", "target_kind": "route", "target_id": "river_pass_mire_lane", "target_placement_id": "", "blocks_approach": true, "clear_required_for_target": false},
    "authored_metadata": {"bundle_id": "neutral_encounter_first_class_object_bundle_001", "lifted_from_bundle_id": "neutral_encounter_representation_bundle_001"}
  }
}
```

### ninefold_basalt_gatehouse_watch

```json
{
  "object": {
    "id": "object_neutral_encounter_ninefold_basalt_gatehouse_watch_stack",
    "schema_version": 1,
    "primary_class": "neutral_encounter",
    "secondary_tags": ["visible_army", "guarded_reward", "neutral_dwelling_watch", "scenario_objective_guard"],
    "family": "neutral_encounter",
    "subtype": "guard_linked_stack",
    "footprint": {"width": 1, "height": 1, "anchor": "bottom_center", "tier": "micro"},
    "passable": false,
    "visitable": true,
    "passability_class": "neutral_stack_blocking",
    "interaction": {"cadence": "one_time", "remains_after_visit": false, "state_after_visit": "cleared", "requires_ownership": false, "requires_guard_clear": false, "supports_revisit": false, "cooldown_days": 0, "refresh_rule": "none"},
    "neutral_encounter": {
      "schema_version": 1,
      "bundle_id": "neutral_encounter_representation_bundle_001",
      "primary_class": "neutral_encounter",
      "secondary_tags": ["visible_army", "guarded_reward", "neutral_dwelling_watch", "scenario_objective_guard"],
      "encounter": {"primary_encounter_id": "encounter_basalt_gatehouse_watch", "encounter_ids": ["encounter_basalt_gatehouse_watch"], "difficulty_source": "scenario_placement", "combat_seed_source": "scenario_placement", "field_objectives_source": "encounter_definition", "preserve_placement_field_objectives": true},
      "representation": {"mode": "guard_linked_stack", "footprint_tier": "micro", "readability_family": "basalt_gatehouse_custodians", "danger_cue_id": "neutral_warning_heavy", "visible_before_interaction": true, "uncertainty_policy": "exact_encounter_known"},
      "guard_link": {"guard_role": "guards_resource_node", "target_kind": "resource_node", "target_id": "site_basalt_gatehouse", "target_placement_id": "dwelling_basalt_gatehouse", "blocks_approach": true, "clear_required_for_target": true},
      "state_model": {"initial_state": "idle", "state_after_victory": "cleared", "state_after_defeat": "active", "remove_on_clear": true, "remember_after_clear": true},
      "placement_ownership": {"ownership_model": "neutral_ecology", "allowed_owner_kinds": ["neutral"], "spawner_kind": "scenario", "placement_authority": "scenario"},
      "reward_guard_summary": {"risk_tier": "heavy", "reward_categories": ["gold", "small_resource", "resource", "experience", "recruitment", "scenario_progress"], "resource_reward_ids": ["gold", "ore"], "guards_reward_tier": "major"},
      "passability": {"passability_class": "neutral_stack_blocking", "interaction_mode": "enter", "blocks_route_until_cleared": true},
      "ai_hints": {"path_blocking": true, "avoid_until_strength": "heavy_guard", "neutral_clearance_value": 7, "guard_target_value_hint": 5},
      "editor_placement": {"placement_mode": "scenario_encounter_overlay", "requires_clear_adjacent_target": false, "warn_if_hiding_target": true, "density_bucket": "guard_or_encounter"}
    }
  },
  "scenario_placement": {
    "placement_id": "ninefold_basalt_gatehouse_watch",
    "object_id": "object_neutral_encounter_ninefold_basalt_gatehouse_watch_stack",
    "object_placement_id": "object_placement_ninefold_basalt_gatehouse_watch",
    "primary_class": "neutral_encounter",
    "x": 60,
    "y": 52,
    "encounter_ref": {"encounter_id": "encounter_basalt_gatehouse_watch", "primary_encounter_id": "encounter_basalt_gatehouse_watch", "encounter_ids": ["encounter_basalt_gatehouse_watch"], "difficulty": "high", "difficulty_source": "scenario_placement", "combat_seed": 16406, "combat_seed_source": "scenario_placement", "field_objectives_source": "encounter_definition", "preserve_placement_field_objectives": true},
    "legacy_scenario_encounter_ref": {"placement_id": "ninefold_basalt_gatehouse_watch", "encounter_id": "encounter_basalt_gatehouse_watch", "source_list": "scenarios.encounters"},
    "guard_link": {"guard_role": "guards_resource_node", "target_kind": "resource_node", "target_id": "site_basalt_gatehouse", "target_placement_id": "dwelling_basalt_gatehouse", "blocks_approach": true, "clear_required_for_target": true},
    "authored_metadata": {"bundle_id": "neutral_encounter_first_class_object_bundle_001", "lifted_from_bundle_id": "neutral_encounter_representation_bundle_001"}
  }
}
```

## Validation Level

This plan names Level 3 from `docs/neutral-encounter-first-class-object-migration-plan.md`: one tiny production planning bundle.

Later implementation, if approved, should use Level 4 metadata-only production object records for only these three placements. Strict production checks for that implementation should be limited to the declared bundle and should require:

- `object_id` and `object_placement_id`.
- Legacy `placement_id` bridge.
- `encounter_ref` agreement with the direct scenario encounter placement.
- Exact lifted metadata agreement with `neutral_encounter_representation_bundle_001`.
- Object-schema fields: `schema_version`, `primary_class`, `secondary_tags`, `footprint`, `passability_class`, `interaction`, and `neutral_encounter`.
- Guard-link agreement between object metadata, scenario object placement, and lifted source metadata.
- Basalt resource-node resolution from `dwelling_basalt_gatehouse` to `site_basalt_gatehouse`.
- Field-objective source preservation.

All remaining production direct-only or scenario-metadata placements stay compatibility-warning-only.

## Expected Report Delta If Implemented Later

If a later metadata-only production implementation adds these proposed object-backed records, the opt-in neutral encounter report should change as follows:

| Report field | Current reviewed value | Expected after implementation |
| --- | ---: | ---: |
| `object_backed_placement_count` | 0 | 3 |
| `lifted_record_count` | 0 | 3 |
| Missing `object_id` | 48 | 45 |
| Missing `object_placement_id` | 48 | 45 |
| Missing object-schema-field records | 48 | 45 |
| Scenario-metadata placements without object backing | 3 | 0 for the declared bundle, while any duplicate source metadata remains compatibility provenance |
| Missing lifted metadata agreement | 0 | 0 |
| Missing guard target resolution | 0 | 0 |

The report should identify the scenario-metadata relationship as:

- Source bundle: `neutral_encounter_representation_bundle_001`.
- Object-backed bundle: `neutral_encounter_first_class_object_bundle_001`.
- Lift status: `object_backed_lifted` for the three declared placements.
- Runtime, pathing, renderer, AI, editor, and save adoption: still inactive.

Strict production checks should apply only to `neutral_encounter_first_class_object_bundle_001` and the existing scenario-metadata `neutral_encounter_representation_bundle_001`. The remaining 45 direct placements should remain compatibility warnings.

## Rollback

Rollback for a later implementation must be one-step:

- Remove or ignore the object definitions and scenario object-placement records for `neutral_encounter_first_class_object_bundle_001`.
- Keep the existing direct scenario encounter placements and their `neutral_encounter_representation_bundle_001` metadata authoritative.
- Do not migrate save keys away from legacy `placement_id`.
- Do not require runtime adapters to consume object-backed records.
- Reject the object-backed bundle if lifted metadata disagrees with the existing scenario metadata instead of silently preferring one side.

## Non-Change Boundaries

This plan does not change:

- Production `content/scenarios.json`, `content/map_objects.json`, `content/encounters.json`, or `content/resource_sites.json`.
- Validator or test implementation.
- Runtime encounter resolution, battle routing, rewards, field objectives, or scenario objectives.
- Pathing, body tiles, approach offsets, blocking, occupancy, or movement costs.
- Renderer presentation, sprite selection, generated PNGs, imported assets, or cue availability.
- AI scoring, route choice, encounter avoidance, or target valuation.
- Editor placement behavior, object duplication, warnings, or save/export behavior.
- Save format, save migration, or resolved encounter state keys.

## Recommended Next Slice

If there are no implementation blockers, proceed with metadata-only production object-backed implementation for exactly these three records.

Recommended slice: add `neutral_encounter_first_class_object_bundle_001` object-backed metadata for `river_pass_ghoul_grove`, `river_pass_hollow_mire`, and `ninefold_basalt_gatehouse_watch`, with runtime behavior still reading current scenario encounter placements.

If blockers appear in report shape or strict fixture coverage, do report/validator prep first. Do not broaden the bundle before the three-record lift is implemented and reviewed.
