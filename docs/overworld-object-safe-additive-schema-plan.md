# Overworld Object Safe Additive Schema Plan

Status: planning source only, no production migration.
Date: 2026-04-26.
Slice: overworld-object-safe-additive-schema-planning-10184.

## Purpose

Plan the first production additive overworld object fields that can be authored as runtime-inactive metadata before any production JSON migration. This narrows `docs/overworld-object-schema-migration-plan.md` to fields that can be safely added without changing map loading, rendering, pathing, interaction resolution, AI valuation, save data, generated asset import, or editor behavior.

This slice does not edit `content/map_objects.json` or `content/resource_sites.json`. Current production content remains compatibility-warning-only under the opt-in overworld object report.

## Safe Field Set

The first additive schema version is `1`. A migrated object record may add only these safe fields:

```json
{
  "schema_version": 1,
  "primary_class": "pickup",
  "secondary_tags": ["small_reward", "route_pacing"],
  "footprint": {
    "width": 1,
    "height": 1,
    "anchor": "bottom_center",
    "tier": "micro"
  },
  "passability_class": "passable_visit_on_enter",
  "interaction": {
    "cadence": "one_time",
    "remains_after_visit": false,
    "state_after_visit": "collected",
    "requires_ownership": false,
    "requires_guard_clear": false,
    "supports_revisit": false,
    "cooldown_days": 0,
    "refresh_rule": "none"
  }
}
```

Existing compatibility fields stay authoritative for runtime behavior:

- `family`
- `resource_site_id`
- `biome_ids`
- `footprint.width`
- `footprint.height`
- `passable`
- `visitable`
- `map_roles`
- current linked `resource_sites.json` behavior fields

## Exact Field Contract

| Field | Shape | Migrated default | Compatibility adapter when absent |
| --- | --- | --- | --- |
| `schema_version` | integer | `1` | Treat as legacy schema `0`; warn in report only. |
| `primary_class` | string enum | Required for migrated bundle | Infer from `family`, then linked resource-site `family`, then `visitable`. |
| `secondary_tags` | array of string ids | `[]`, plus meaningful known tags | Infer from family defaults, `map_roles`, and linked site behavior. Unknown tags are invalid in migrated bundles. |
| `footprint.anchor` | string enum | `bottom_center` | Infer `bottom_center` for report and migrated first wave unless a later editor slice declares another anchor. |
| `footprint.tier` | string enum | Area-derived tier | Infer from `width * height`: `micro` <=1, `small` <=2, `medium` <=4, `large` <=6, otherwise `region_feature`. |
| `passability_class` | string enum | Required for migrated bundle | Infer from legacy `passable`, `visitable`, and `family`. Runtime still reads legacy booleans. |
| `interaction` | object | Required for migrated bundle | Infer cadence from `visitable` plus linked site repeatable, persistent-control, weekly recruit, and transit fields. Other interaction keys receive class defaults for report only. |

Allowed `primary_class` values:

- `decoration`
- `pickup`
- `interactable_site`
- `persistent_economy_site`
- `transit_route_object`
- `neutral_dwelling`
- `neutral_encounter`
- `guarded_reward_site`
- `faction_landmark`
- `scenario_objective`

Allowed first-pass `secondary_tags` are the current validator/report vocabulary:

`road_control`, `sightline`, `ambush_lane`, `resource_front`, `recovery`, `spell_access`, `market`, `blocked_route`, `conditional_route`, `world_lore`, `guarded_reward`, `neutral_recruit_source`, `faction_pressure`, `scenario_objective`, `counter_capture_target`, `town_support`, `weekly_muster`, `small_reward`, `route_pacing`, `build_resource`.

Allowed `footprint.anchor` values:

- `bottom_center`
- `center`
- `top_left`
- `bottom_left`
- `bottom_right`

First migrated production bundles should use `bottom_center` only. The other anchors remain reserved for later editor/tooling cases.

Allowed `footprint.tier` values:

- `micro`
- `small`
- `medium`
- `large`
- `region_feature`

Allowed `passability_class` values:

- `passable_visit_on_enter`
- `passable_scenic`
- `blocking_visitable`
- `blocking_non_visitable`
- `edge_blocker`
- `conditional_pass`
- `town_blocking`
- `neutral_stack_blocking`

Allowed `interaction.cadence` values:

- `none`
- `one_time`
- `repeatable_daily`
- `repeatable_weekly`
- `cooldown_days`
- `persistent_control`
- `conditional`
- `scenario_scripted`

Required `interaction` keys for migrated safe-field bundles:

| Key | Type | Default by cadence |
| --- | --- | --- |
| `cadence` | string enum | Required. |
| `remains_after_visit` | boolean | `false` for one-time pickups, `true` for persistent, repeatable, transit, landmarks, dwellings, and blockers. |
| `state_after_visit` | string | `collected`, `visited`, `claimed`, `opened`, `cleared`, or `unchanged` by class. |
| `requires_ownership` | boolean | `false` unless linked site behavior already requires ownership. |
| `requires_guard_clear` | boolean | `true` only when linked guarded/guard-profile behavior already exists. |
| `supports_revisit` | boolean | `true` for repeatable, cooldown, persistent, conditional, and scripted objects. |
| `cooldown_days` | integer | Existing `visit_cooldown_days` when cadence is `cooldown_days`, else `0`. |
| `refresh_rule` | string | `none`, `daily_income`, `weekly_growth`, `cooldown`, `route_state`, `scenario`, or `persistent_state`. |

## Class And Family Mapping

| Current source | First additive primary class | Default secondary tags | First-wave status |
| --- | --- | --- | --- |
| `family: pickup` | `pickup` | `small_reward`, `route_pacing`, plus `map_roles` | First-wave candidate. |
| resource site with no `family` and one-shot rewards | `pickup` | `small_reward`, `route_pacing` | Candidate only after placed-site object-link planning. |
| `family: mine` | `persistent_economy_site` | `resource_front`, `counter_capture_target`, plus `map_roles` | First-wave candidate for metadata only. |
| `family: scouting_structure` | `interactable_site` | `sightline`, `counter_capture_target`, plus `map_roles` | First-wave candidate. |
| `family: repeatable_service` | `interactable_site` | `recovery`, plus `market` when exchange behavior exists | First-wave candidate. |
| `family: transit_object` | `transit_route_object` | `road_control`, `conditional_route`, plus `map_roles` | First-wave candidate for safe metadata; route effects are later. |
| `family: blocker` | `decoration` | `blocked_route`, plus `map_roles` | First-wave candidate for non-runtime metadata. |
| `family: decoration` | `decoration` | `world_lore`, plus `map_roles` | First-wave compatible if records exist later. |
| `family: faction_landmark` | `faction_landmark` | `faction_pressure`, `world_lore`, plus `map_roles` | First-wave candidate for safe metadata. |
| `family: neutral_dwelling` | `neutral_dwelling` | `neutral_recruit_source`, `weekly_muster`, `counter_capture_target`, plus `map_roles` | Shape is defined, but broad migration should wait for neutral dwelling ownership/guard review. |
| `family: guarded_reward_site` | `guarded_reward_site` | `guarded_reward`, plus `map_roles` | Shape is defined, but broad migration should wait for guard/reward summary planning. |
| future visible neutral encounter object | `neutral_encounter` | `ambush_lane` or `guarded_reward` as authored | Later representation decision, not first-wave migration. |
| future scenario objective object | `scenario_objective` | `scenario_objective`, plus authored route/objective tags | Later scenario-objective slice. |

## Passability Mapping

| Legacy/source fields | Safe metadata value | Runtime behavior in this slice |
| --- | --- | --- |
| `passable: true`, `visitable: true`, `family: pickup` | `passable_visit_on_enter` | Unchanged; legacy booleans remain authoritative. |
| `passable: true`, `visitable: true`, `family: transit_object` | `conditional_pass` when linked site has transit behavior, otherwise `passable_visit_on_enter` | Unchanged; no pathing effect. |
| `passable: true`, `visitable: false` | `passable_scenic` | Unchanged. |
| `passable: false`, `visitable: true`, non-transit | `blocking_visitable` | Unchanged. |
| `passable: false`, `visitable: true`, `family: transit_object` | `conditional_pass` | Unchanged; no route effect adoption. |
| `passable: false`, `visitable: false`, `family: blocker` | `blocking_non_visitable` by default | Unchanged. |
| future lane-edge blocker with explicit editor proof | `edge_blocker` | Reserved; no production runtime adoption yet. |
| future town object | `town_blocking` | Reserved for town schema/editor work. |
| future visible neutral stack | `neutral_stack_blocking` | Reserved for neutral encounter representation work. |

## Interaction Cadence Mapping

| Linked site/object reality | Safe `interaction.cadence` | Safe defaults |
| --- | --- | --- |
| Non-visitable object | `none` | `remains_after_visit: true`, `state_after_visit: "unchanged"`, no revisit. |
| Visitable object with one-shot rewards only | `one_time` | Collected/visited after interaction, no revisit. |
| Linked site has `persistent_control: true` | `persistent_control` | Remains, claimed after visit, revisit supported, `refresh_rule: "daily_income"` when income exists. |
| Linked site has `repeatable: true` and `visit_cooldown_days > 0` | `cooldown_days` | Remains, revisit supported, cooldown copied from site. |
| Linked site has `repeatable: true` without explicit cooldown | `repeatable_weekly` | Remains, revisit supported, `refresh_rule: "weekly_growth"` or `persistent_state`. |
| Linked site has `weekly_recruits` | `repeatable_weekly` | Remains, claimed/visited after interaction, revisit supported. |
| Linked site has `transit_profile` | `conditional` | Remains, opened/visited after interaction, revisit supported, `refresh_rule: "route_state"`. |
| Scenario hook drives behavior | `scenario_scripted` | Remains and uses `refresh_rule: "scenario"`; requires later scenario-objective slice before migration. |

## Minimal Example Records

These are examples only. They must not be copied into production JSON in this slice.

```json
[
  {
    "id": "example_safe_pickup",
    "family": "pickup",
    "schema_version": 1,
    "primary_class": "pickup",
    "secondary_tags": ["small_reward", "route_pacing"],
    "footprint": {"width": 1, "height": 1, "anchor": "bottom_center", "tier": "micro"},
    "passable": true,
    "visitable": true,
    "passability_class": "passable_visit_on_enter",
    "interaction": {"cadence": "one_time", "remains_after_visit": false, "state_after_visit": "collected", "requires_ownership": false, "requires_guard_clear": false, "supports_revisit": false, "cooldown_days": 0, "refresh_rule": "none"}
  },
  {
    "id": "example_safe_mine",
    "family": "mine",
    "schema_version": 1,
    "primary_class": "persistent_economy_site",
    "secondary_tags": ["resource_front", "counter_capture_target"],
    "footprint": {"width": 2, "height": 2, "anchor": "bottom_center", "tier": "medium"},
    "passable": false,
    "visitable": true,
    "passability_class": "blocking_visitable",
    "interaction": {"cadence": "persistent_control", "remains_after_visit": true, "state_after_visit": "claimed", "requires_ownership": false, "requires_guard_clear": false, "supports_revisit": true, "cooldown_days": 0, "refresh_rule": "daily_income"}
  },
  {
    "id": "example_safe_scouting_structure",
    "family": "scouting_structure",
    "schema_version": 1,
    "primary_class": "interactable_site",
    "secondary_tags": ["sightline", "counter_capture_target"],
    "footprint": {"width": 1, "height": 2, "anchor": "bottom_center", "tier": "small"},
    "passable": false,
    "visitable": true,
    "passability_class": "blocking_visitable",
    "interaction": {"cadence": "persistent_control", "remains_after_visit": true, "state_after_visit": "claimed", "requires_ownership": false, "requires_guard_clear": false, "supports_revisit": true, "cooldown_days": 0, "refresh_rule": "persistent_state"}
  },
  {
    "id": "example_safe_repeatable_service",
    "family": "repeatable_service",
    "schema_version": 1,
    "primary_class": "interactable_site",
    "secondary_tags": ["recovery"],
    "footprint": {"width": 2, "height": 1, "anchor": "bottom_center", "tier": "small"},
    "passable": false,
    "visitable": true,
    "passability_class": "blocking_visitable",
    "interaction": {"cadence": "cooldown_days", "remains_after_visit": true, "state_after_visit": "visited", "requires_ownership": false, "requires_guard_clear": false, "supports_revisit": true, "cooldown_days": 3, "refresh_rule": "cooldown"}
  },
  {
    "id": "example_safe_transit_object",
    "family": "transit_object",
    "schema_version": 1,
    "primary_class": "transit_route_object",
    "secondary_tags": ["road_control", "conditional_route"],
    "footprint": {"width": 2, "height": 1, "anchor": "bottom_center", "tier": "small"},
    "passable": true,
    "visitable": true,
    "passability_class": "conditional_pass",
    "interaction": {"cadence": "conditional", "remains_after_visit": true, "state_after_visit": "opened", "requires_ownership": false, "requires_guard_clear": false, "supports_revisit": true, "cooldown_days": 0, "refresh_rule": "route_state"}
  },
  {
    "id": "example_safe_blocker",
    "family": "blocker",
    "schema_version": 1,
    "primary_class": "decoration",
    "secondary_tags": ["blocked_route"],
    "footprint": {"width": 3, "height": 1, "anchor": "bottom_center", "tier": "large"},
    "passable": false,
    "visitable": false,
    "passability_class": "blocking_non_visitable",
    "interaction": {"cadence": "none", "remains_after_visit": true, "state_after_visit": "unchanged", "requires_ownership": false, "requires_guard_clear": false, "supports_revisit": false, "cooldown_days": 0, "refresh_rule": "none"}
  },
  {
    "id": "example_safe_faction_landmark",
    "family": "faction_landmark",
    "schema_version": 1,
    "primary_class": "faction_landmark",
    "secondary_tags": ["faction_pressure", "world_lore"],
    "footprint": {"width": 1, "height": 1, "anchor": "bottom_center", "tier": "micro"},
    "passable": false,
    "visitable": false,
    "passability_class": "blocking_non_visitable",
    "interaction": {"cadence": "none", "remains_after_visit": true, "state_after_visit": "unchanged", "requires_ownership": false, "requires_guard_clear": false, "supports_revisit": false, "cooldown_days": 0, "refresh_rule": "none"}
  }
]
```

## Migrated-Bundle Validation Levels

Level 0, current default validation:

- Existing production content remains valid without any new safe metadata.
- Existing `family`, `passable`, `visitable`, `footprint.width`, `footprint.height`, `biome_ids`, and `map_roles` checks continue.

Level 1, opt-in report:

- Missing safe fields warn only.
- Inferred values are labelled report-only.
- Production content with 0 new fields remains valid.

Level 2, strict fixtures:

- Fixture records require the full strict shape already covered by `tests/fixtures/overworld_object_schema/`.
- This level can continue testing later fields such as `body_tiles`, `approach`, `route_effect`, `animation_cues`, `editor_placement`, and `ai_hints`, but that strictness stays fixture-only.

Level 3, declared migrated production bundle:

- Only object ids named by a future migrated-bundle manifest or validator allowlist are strict.
- For those ids, `schema_version: 1`, `primary_class`, `secondary_tags`, `footprint.anchor`, `footprint.tier`, `passability_class`, and full `interaction` are errors if missing or malformed.
- Legacy fields remain required and must agree with safe metadata through the compatibility mapping.
- Unmigrated production object ids remain Level 1 warnings only.

Level 4, later runtime/editor adoption:

- Not active in this slice.
- Pathing, editor placement, AI, animation, save/load, and route systems may only make fields behavior-bearing after their own migration and rollback plans.

## First Small Production Bundle Candidate

Do not implement this bundle in this slice. Candidate ids are chosen because they are already production object records, have simple legacy behavior, and can carry safe metadata without adding new object links or changing runtime logic.

Candidate `safe_metadata_bundle_001`:

| Object id | Family | Why it is low risk |
| --- | --- | --- |
| `object_waystone_cache` | `pickup` | Existing linked one-time pickup, 1x1, passable and visitable. |
| `object_timber_wagon` | `pickup` | Existing linked one-time pickup, 1x1, passable and visitable. |
| `object_watchtower_beacon` | `scouting_structure` | Existing linked scouting site, small footprint, persistent/capturable inference already reportable. |
| `object_wayfarer_infirmary` | `repeatable_service` | Existing linked repeatable support service, no new route or combat behavior required. |
| `object_market_caravanserai` | `repeatable_service` | Existing linked service/market-style object, metadata can remain descriptive. |
| `object_brightwood_sawmill` | `mine` | Existing linked economy site, useful first persistent-site metadata case. |
| `object_bramble_wall` | `blocker` | Existing non-visitable blocker, no interaction behavior. |
| `object_ember_signal_brazier` | `faction_landmark` | Existing non-visitable faction landmark, no behavior-bearing migration needed. |

Explicitly deferred from the first production bundle:

- The 25 `neutral_dwelling` objects, until guard/ownership summary expectations are reviewed.
- `guarded_reward_site` objects, until guard/reward summary metadata planning is complete.
- `transit_object` records, if the implementation would be tempted to add `route_effect`; they may only enter a safe bundle if route effects stay absent and warning-only.
- The 10 placed resource sites without object links, because adding map-object companion records or placement links is production content migration:
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

## Later Slices Explicitly Out Of Scope

These fields and behaviors are deliberately staged after the safe metadata pass:

- `body_tiles`: later body/occupancy metadata strategy, then editor/pathing validation.
- `approach`: later visit-offset, side, and clear-tile strategy.
- `neutral_encounter` records: later first-class visible neutral encounter representation decision.
- `route_effects`: later metadata-only route-effect placeholder plan, then pathing/AI adoption.
- `animation_cues`: later cue catalog prerequisite before broad object references.
- `editor_placement`: later advisory placement, density, and clearance metadata.
- `ai_hints`: later advisory valuation metadata and separate AI adoption.

## Rollback Strategy

Safe metadata rollback must be mechanical:

1. Remove the added safe fields from the declared migrated bundle records only.
2. Remove the migrated-bundle allowlist or manifest entry, if one is added later.
3. Leave `family`, `passable`, `visitable`, `footprint.width`, `footprint.height`, `resource_site_id`, `biome_ids`, and `map_roles` untouched.
4. Keep report inference active so the project can still inspect current reality.
5. Do not roll back validator fixture scaffolding unless the fixture vocabulary itself is wrong.

Because runtime systems continue reading legacy fields, removing safe metadata should not alter map load, pathing, rendering, site interaction, AI, saves, or scenario outcomes.

## AcOrP Review Decisions Recorded

- Current production content remains compatibility-warning-only until a production bundle is explicitly declared migrated.
- The safe field set is limited to `schema_version`, `primary_class`, `secondary_tags`, `footprint.anchor`, `footprint.tier`, `passability_class`, and `interaction`.
- First-class neutral encounter records are still needed, but they require a separate representation decision before production migration.
- True body-tile occupancy, approach validation, route effects, animation cues, editor hints, and AI hints are not first-wave production migration fields.
- GitHub auth remains blocked; work stays local.
