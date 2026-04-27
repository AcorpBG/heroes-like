# Overworld Object Schema Migration Plan

Status: planning source only, not implementation.
Date: 2026-04-26.
Slice: overworld-object-schema-migration-planning-10184.

## Purpose

This document defines the staged production data contract for overworld objects before any JSON migration, scenario map placement, renderer sprite ingestion, runtime asset import, pathing rewrite, or AI adoption. It translates the object taxonomy, economy foundation, concept-art implementation briefs, animation foundation, and strategic AI foundation into a schema migration plan that can be implemented in controlled bundles.

This is intentionally not a content migration. `content/map_objects.json`, `content/resource_sites.json`, scenario placements, renderer mappings, runtime art, save data, and gameplay rules remain unchanged in this slice.

## Source Inputs

- `docs/overworld-object-taxonomy-density.md`
- `docs/concept-art-implementation-briefs.md`
- `docs/economy-overhaul-foundation.md`
- `docs/animation-systems-foundation.md`
- `docs/strategic-ai-foundation.md`
- Reality check against current `content/map_objects.json`, `content/resource_sites.json`, and `tests/validate_repo.py`

## Current Schema And Content Reality

Current `content/map_objects.json` is useful scaffolding:

- It has 43 object records under `items`.
- Current fields are mostly `id`, `name`, `family`, `resource_site_id`, `biome_ids`, `footprint`, `passable`, `visitable`, `map_roles`, and occasional `faction_id`.
- 25 objects are neutral dwellings.
- The current family set includes pickups, neutral dwellings, mines, scouting structures, guarded reward sites, transit objects, repeatable services, blockers, and faction landmarks.
- Footprints currently expose positive width/height and are used primarily as presentation hints, not true body-tile occupancy, path blocking, or visit-target rules.
- `passable` and `visitable` are booleans. They cannot express passable scenic, enter-to-collect, blocking visitable, edge blocker, or conditional pass.
- Object records link to resource-site records, but do not yet carry explicit primary class, secondary tags, approach sides, visit offsets, interaction cadence, ownership model, route effect ids, animation cues, AI valuation hooks, or editor placement rules.

Current `content/resource_sites.json` carries important behavior that must not be lost:

- It has 48 site records under `items`.
- Several early pickups still omit `family`, effectively acting as one-shot pickup content.
- Existing fields include `rewards`, `claim_rewards`, `control_income`, `persistent_control`, `guarded`, `guard_profile`, `transit_profile`, `repeatable`, `visit_cooldown_days`, `vision_radius`, `neutral_roster`, `neutral_dwelling_family_id`, `town_support`, `response_profile`, and pressure-related fields.
- It already distinguishes mines, scouting structures, guarded reward sites, transit objects, repeatable services, neutral dwellings, faction outposts, frontier shrines, and one-shot pickups.
- It remains the current behavior-bearing site domain. The object migration should not duplicate all resource-site behavior into map objects; it should define the presentation, placement, approach, and shared object contract while preserving resource-site linkage.

Current validation in `tests/validate_repo.py` already enforces:

- Supported map-object families.
- Supported resource-site families.
- Family matching between map objects and linked resource sites for the first foundation families.
- Positive object footprint dimensions.
- Explicit `passable` and `visitable` booleans.
- Non-empty `map_roles`.
- Guard profiles for guarded reward sites.
- Transit profiles for transit sites.
- Persistent control and income for mines/scouting structures.
- Neutral dwelling links across neutral dwelling families, sites, objects, army groups, and encounters.

The target schema should build on these checks through additive warnings first, not break existing content in one pass.

## Target Object Taxonomy Fields

Every production overworld object should eventually expose these top-level meanings, even if the implementation stores some of them in nested dictionaries:

- `schema_version`: object schema version for staged validation and compatibility.
- `primary_class`: one canonical class from the production taxonomy.
- `secondary_tags`: structured tags for cross-system behavior and search.
- `family`: legacy/current family id retained through compatibility, then gradually aligned with `primary_class` and subtype fields.
- `subtype`: object-family-specific subtype such as `ore_quarry`, `chain_ferry`, `road_tollhouse`, `reed_cache`, or `mirror_ruin`.
- `resource_site_id`: optional link to behavior-bearing site content.
- `encounter_id` or `guard_encounter_id`: optional link to a visible encounter or guard.
- `town_id` or `faction_id`: optional ownership/faction identity links when relevant.
- `art_direction_family`: concept-art/brief family id, not an imported asset path.
- `renderer_hint_id`: optional renderer mapping id, introduced only after schema and sample fixtures settle.

Primary class target values:

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

Secondary tags should use stable lowercase ids such as:

- `road_control`
- `sightline`
- `ambush_lane`
- `resource_front`
- `recovery`
- `spell_access`
- `market`
- `blocked_route`
- `conditional_route`
- `world_lore`
- `guarded_reward`
- `neutral_recruit_source`
- `faction_pressure`
- `scenario_objective`
- `counter_capture_target`
- `town_support`

Compatibility rule: during the additive phase, existing `family` remains authoritative for runtime behavior. `primary_class` and `secondary_tags` begin as validation/editor/planning metadata until adoption slices explicitly switch systems over.

## Footprint And Body Tiles

The target schema must separate visual scale from gameplay occupancy.

Recommended shape:

```json
"footprint": {
  "width": 2,
  "height": 2,
  "anchor": "bottom_center",
  "tier": "medium"
},
"body_tiles": [
  {"x": 0, "y": 0, "role": "body"},
  {"x": 1, "y": 0, "role": "body"},
  {"x": 0, "y": 1, "role": "body"},
  {"x": 1, "y": 1, "role": "body"}
]
```

Contract:

- `footprint.width` and `footprint.height` remain required positive integers.
- `footprint.tier` should be one of `micro`, `small`, `medium`, `large`, or `region_feature`.
- `footprint.anchor` should make renderer/editor anchoring explicit, with `bottom_center` as the likely default for towns and large sites.
- `body_tiles` are local offsets inside the footprint, not map coordinates.
- `body_tiles` should not be required in the first additive pass; missing body tiles infer the full rectangular footprint for validation warnings only.
- Future irregular objects may define partial body tiles, but rectangular bodies should be the first implementation target.
- Towns keep the current documented 3x2 bottom-middle approach contract. Normal play should not show footprint helper glyphs.

Migration risk: if gameplay pathing starts using body tiles too early, existing maps may trap heroes or invalidate old placements. True occupancy must wait until editor warnings and scenario placement checks are ready.

## Approach Offsets And Sides

Every visitable object needs explicit visit rules before true placement validation.

Recommended shape:

```json
"approach": {
  "mode": "adjacent",
  "primary_sides": ["south"],
  "visit_offsets": [{"x": 0, "y": 1}],
  "stop_before_interaction": true,
  "requires_clear_tile": true,
  "linked_exit_offsets": []
}
```

Target fields:

- `mode`: `enter`, `adjacent`, `pass_through`, `linked_endpoint`, or `none`.
- `primary_sides`: zero or more of `north`, `east`, `south`, `west`.
- `visit_offsets`: local offsets relative to the footprint anchor or footprint rectangle, using one convention selected before implementation.
- `stop_before_interaction`: whether the hero stops before resolving the interaction.
- `requires_clear_tile`: whether the approach tile must be pathable and unoccupied.
- `linked_exit_offsets`: for ferries, rails, root gates, fog slips, and other route objects.
- `approach_notes`: optional planning/editor text only, not player-facing UI.

Class defaults:

- Pickups usually use `mode: "enter"`.
- Mines, dwellings, shrines, guarded sites, and support buildings use `mode: "adjacent"`.
- Transit objects may use `pass_through` or `linked_endpoint`.
- Decoration uses `none`.
- Neutral encounters use `enter` or `adjacent` depending on whether the encounter is a stack object or a guarded camp.

Validator staging should warn when `visitable: true` objects lack approach metadata after the additive schema exists.

## Passability Classes

The current `passable` boolean should remain for compatibility, but it needs a richer companion field.

Target values:

- `passable_visit_on_enter`
- `passable_scenic`
- `blocking_visitable`
- `blocking_non_visitable`
- `edge_blocker`
- `conditional_pass`
- `town_blocking`
- `neutral_stack_blocking`

Compatibility mapping:

| Current fields | Default target class |
| --- | --- |
| `passable: true`, `visitable: true`, `family: pickup` | `passable_visit_on_enter` |
| `passable: true`, `visitable: false` | `passable_scenic` |
| `passable: false`, `visitable: true`, `family: transit_object` | `conditional_pass` or `blocking_visitable` by subtype |
| `passable: false`, `visitable: true` | `blocking_visitable` |
| `passable: false`, `visitable: false`, `family: blocker` | `blocking_non_visitable` or `edge_blocker` |

The boolean fields should be retained until the renderer, pathing, save/load, map editor, and validators no longer depend on them. Removal is not in the near-term plan.

## Interaction Cadence

Object records should describe cadence at the object-contract level while detailed rewards/services remain in resource-site content.

Recommended shape:

```json
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
```

Target `cadence` values:

- `none`
- `one_time`
- `repeatable_daily`
- `repeatable_weekly`
- `cooldown_days`
- `persistent_control`
- `conditional`
- `scenario_scripted`

Compatibility:

- If linked `resource_site_id` has `repeatable` and `visit_cooldown_days`, object cadence may initially infer `cooldown_days`.
- If linked site has `persistent_control`, object cadence may infer `persistent_control`.
- If linked site has only `rewards`, object cadence may infer `one_time`.

The first implementation should prefer inferred warnings over duplicating existing site behavior manually.

## Guard And Reward Links

Guard and reward metadata should make risk readable and allow AI/editor valuation without moving all encounter/site data into map objects.

Recommended shape:

```json
"guard": {
  "guard_policy": "linked_encounter",
  "guard_tier": "standard",
  "encounter_id": "encounter_example_guard",
  "guard_target_role": "blocks_approach",
  "warning_cue_id": "object_warning_guarded_standard",
  "visible_before_interaction": true
},
"reward_summary": {
  "reward_categories": ["persistent_income"],
  "reward_tier": "standard",
  "resource_output_ids": ["ore"],
  "artifact_pool_id": "",
  "spell_school_tags": []
}
```

Guard policy values:

- `none`
- `linked_encounter`
- `linked_army_group`
- `site_guard_profile`
- `ambient_warning_only`
- `scenario_scripted`

Guard tier values:

- `unguarded`
- `light`
- `standard`
- `heavy`
- `elite`
- `ambush_uncertain`

Reward categories:

- `small_resource`
- `resource_choice`
- `persistent_income`
- `weekly_yield`
- `recruitment`
- `spell_access`
- `artifact`
- `experience`
- `scouting_reveal`
- `route_opening`
- `movement_discount`
- `recovery`
- `market_service`
- `town_support`
- `scenario_progress`

Rules:

- Guarded reward sites must expose a guard policy and reward categories before broad placement.
- Neutral encounters guarding another object need a guard-target link so the editor, renderer, and AI can keep both the guard and the target readable.
- Ambush/uncertain objects must still have a visible warning cue. Hidden punishment is rejected.

## Ownership And Capture States

Object schema should normalize mutable state categories without storing live state in authored records.

Recommended authored fields:

```json
"ownership": {
  "ownership_model": "capturable",
  "allowed_owner_kinds": ["neutral", "player", "enemy"],
  "initial_owner_policy": "scenario",
  "capture_profile_id": "standard_resource_site",
  "counter_capture_value": 6,
  "ownership_visual_policy": "material_accent"
}
```

Target ownership models:

- `none`
- `scenario_fixed`
- `capturable`
- `claimable_once`
- `town_controlled`
- `route_controlled`
- `faction_locked`
- `neutral_ecology`

Target state vocabulary:

- `neutral`
- `player_owned`
- `enemy_owned`
- `contested`
- `guarded`
- `cleared`
- `collected`
- `depleted`
- `refreshed`
- `damaged`
- `repaired`
- `blocked`
- `open`
- `closed`
- `scenario_locked`
- `remembered`
- `fogged`

Authored content should define possible states and state policies. Save data should store actual mutable state by placement id or site id.

## Route Effects

Transit and route-control objects need data that pathing, editor checks, AI, and animation can share.

Recommended shape:

```json
"route_effect": {
  "effect_id": "ferry_shortcut",
  "effect_type": "linked_endpoint",
  "requires_visit": true,
  "requires_owner": false,
  "movement_cost_delta": -2,
  "toll_resources": {},
  "blocked_state_ids": ["damaged", "closed"],
  "linked_endpoint_group_id": "ferry_mire_01"
}
```

Effect types:

- `open_route`
- `close_route`
- `linked_endpoint`
- `movement_discount`
- `movement_tax`
- `scouting_sightline`
- `fog_bypass`
- `repair_unlock`
- `faction_favored_pass`
- `scenario_gate`

Staging rule: route effects should validate as metadata first. Pathfinding adoption must wait until route effects have sample fixtures and map-editor warnings, otherwise existing maps can become inconsistent.

## Resource-Site Linkage

The migration should preserve a clean split:

- `map_objects.json` owns world-object identity, footprint, approach, passability class, visible state vocabulary, animation cue ids, editor placement rules, and high-level AI valuation hints.
- `resource_sites.json` owns rewards, income, service costs, persistent control behavior, repeatability, recruitment payloads, transit profiles, guard profiles, and current site behavior until economy/schema migration says otherwise.
- Future economy/resource schema migration should decide the resource ids, outputs, cadence, market compatibility, and canonical `wood` policy before persistent resource-front content expands.

Link rules:

- If `resource_site_id` is present, it must reference an existing site.
- For current foundation families, linked object `family` must continue to match linked site `family` until `primary_class` adoption has explicit mapping rules.
- `persistent_economy_site` objects should normally link to sites with `persistent_control`.
- `guarded_reward_site` objects should link to sites with guard/reward data.
- `neutral_dwelling` objects should continue to link through `neutral_dwellings.json`, resource sites, encounters, and army groups.

## Animation Cue Ids

The object schema should reference cue ids without requiring a full animation system in the first migration.

Recommended shape:

```json
"animation_cues": {
  "idle": "object_quarry_idle",
  "focus": "object_default_focus",
  "visit": "object_default_visit",
  "capture": "object_capture_material_accent",
  "owned": "object_owned_subtle",
  "damaged": "object_damaged_smoke",
  "repaired": "object_repaired_spark",
  "output_ready": "object_output_ready_subtle",
  "guard_warning": "object_warning_guarded_standard",
  "cleared": "object_cleared_entrance",
  "collected": "pickup_collect_small"
}
```

Rules:

- Cue ids are references, not implementation.
- Missing cue ids should warn first and only become errors when an animation cue catalog exists.
- Decoration cues must stay quiet and should not use reward-like shimmer.
- Ownership/capture cues must be physical/material/state cues, not copied banners or large UI badges.
- Fogged/remembered objects need reduced or ghosted cue policy later so players do not infer live state from stale memory.

## AI Valuation Hooks

AI needs a compact data surface before it can value objects beyond current site reward heuristics.

Recommended shape:

```json
"ai_value": {
  "strategic_value": 5,
  "resource_value_ids": ["ore"],
  "route_value": 2,
  "scouting_value": 0,
  "risk_tier": "standard",
  "counter_capture_priority": 4,
  "faction_preference_tags": ["brasshollow_priority", "sunvault_secondary"],
  "avoid_until_strength": "standard_guard"
}
```

Rules:

- AI hooks should be advisory and validated for shape first.
- Runtime AI adoption should still compute value from actual map state, reward payloads, guard strength, faction shortages, route exposure, and objectives.
- `strategic_value` should not become a magic number that overrides real risk/reward evaluation.
- Neutral encounters need path-blocking and guard-target hints so AI can decide whether to fight, avoid, or route around.

## Editor And Tooling Implications

The map editor and content tooling need staged support before gameplay pathing relies on the new contract.

Editor requirements:

- Show object primary class and passability class in an inspector/debug surface.
- Preview footprint and approach tiles in editor mode only.
- Warn when approach tiles are blocked, out of bounds, or ambiguous.
- Warn when two visitable objects compete for the same approach tile.
- Warn when guarded sites hide their entrance behind a guard object.
- Warn when transit objects lack linked endpoint metadata.
- Warn when persistent economy objects are placed without plausible route access.
- Preserve negative space around towns, route junctions, major transit objects, and active hero lanes.
- Keep normal play free of helper circles, visible footprint glyphs, or large diagnostic panels.

Tooling requirements:

- Provide a migration helper/report before rewriting content.
- Generate additive-field suggestions from existing `family`, `passable`, `visitable`, `footprint`, `map_roles`, and linked resource-site fields.
- Produce warnings first, with a content bundle checklist for each migration wave.
- Keep generated images out of the repo unless a later explicit asset-ingestion slice approves original runtime assets.

## Validation Rules

Validation should move through levels.

Level 0, current compatibility:

- Existing tests continue to pass.
- Existing content shape remains valid.
- `passable`, `visitable`, `family`, positive `footprint`, `biome_ids`, and `map_roles` remain required.

Level 1, additive warnings:

- Warn when a map object lacks `schema_version`, `primary_class`, `secondary_tags`, `passability_class`, `approach`, `interaction`, `state_model`, `animation_cues`, or `ai_value`.
- Warn when `primary_class` does not match the current family mapping.
- Warn when visitable objects lack approach metadata.
- Warn when guarded/reward/transit/economy objects lack the relevant companion metadata.
- Warn when object/resource-site family mapping is ambiguous.

Level 2, fixture errors:

- Require full target fields only for a small sample fixture set.
- Validate body tiles are inside footprint bounds.
- Validate approach offsets are outside body tiles unless `mode` is `enter`.
- Validate linked endpoint objects reference each other or a shared endpoint group.
- Validate guard and reward categories for guarded reward fixtures.
- Validate animation cue ids against a stub cue catalog if one exists.

Level 3, migrated content bundle errors:

- Require target fields for content included in each migration bundle.
- Keep unmigrated legacy content valid through compatibility defaults.
- Fail only when a bundle declares it has migrated and violates the contract.

Level 4, runtime adoption errors:

- After renderer/editor/pathing/AI adopt the fields, enforce fields needed by those systems.
- Save/load compatibility must be proven before removing or ignoring legacy fields.

## Staged Migration Sequence

1. Additive schema planning.
   - This document is the contract.
   - No JSON/content/runtime edits.

2. Additive schema fields.
   - Add optional fields to a small branch of content only after AcOrP has reviewed the contract.
   - Keep `family`, `passable`, `visitable`, current `footprint`, and `resource_site_id`.
   - No runtime behavior switch.

3. Validator warnings.
   - Add warning/report mode for target fields.
   - Do not fail existing content yet.
   - Generate a migration report for all map objects and linked resource sites.

4. Sample fixtures.
   - Add a tiny fixture set covering one pickup, one mine/resource front, one transit object, one guarded reward site, one neutral dwelling, one neutral encounter, one faction landmark, and one decoration/blocker.
   - Validate fixtures strictly.
   - Keep fixtures out of production maps unless explicitly promoted.

5. Content migration bundles.
   - Migrate in family bundles, not one giant JSON churn:
     - pickups and decoration/blockers
     - mines/resource fronts after economy/resource schema decisions
     - transit/route objects
     - guarded reward sites
     - neutral dwellings and visible neutral encounter split
     - faction landmarks
     - scenario objectives
   - Each bundle should include validation updates and a rollback note.

6. Renderer/editor adoption.
   - Renderer reads footprint/passability/animation hints for presentation only.
   - Editor previews body/approach/route metadata and emits placement warnings.
   - Normal gameplay remains scenery-first without helper overlays.

7. Pathing and interaction adoption.
   - Pathing begins using body tiles and approach offsets only after maps pass editor validation.
   - Interaction resolver uses `interaction` and `approach` metadata through compatibility adapters.
   - Save/load stores mutable placement state separately from authored object definitions.

8. AI adoption.
   - AI valuation consumes primary class, reward categories, guard tier, route effect, ownership model, and resource-site outputs.
   - AI still computes live value from actual state and difficulty/faction profile.

9. Legacy cleanup.
   - Only after content, renderer, editor, pathing, AI, and saves are stable, decide whether any legacy fields can be deprecated.
   - Near-term removal of `family`, `passable`, or `visitable` is not recommended.

## Rollback And Compatibility Concerns

- The first implementation should be additive and reversible.
- Existing maps must continue to load if target fields are absent.
- Legacy booleans and family fields remain the fallback source until each consuming system has an adapter.
- Save files should store content ids and placement state, not copied object schema blobs.
- If target passability produces blocked routes in existing scenarios, pathing adoption must be rolled back independently from metadata.
- Resource output fields should not be migrated before the economy/resource schema plan resolves `wood` versus `wood`, the nine-resource target, and market/cadence compatibility.
- Renderer sprite ingestion should not depend on generated-image filenames or imported concept PNGs.
- The neutral encounter split is a product/schema decision and should not be forced by a renderer shortcut.

## Decisions For AcOrP Review

- Confirm `primary_class` values and whether `interactable_site` should remain a broad class or split earlier into service/shrine/scouting subtypes.
- Confirm that `family` remains as compatibility metadata through at least the first renderer/editor/pathing adoption.
- Confirm when true body-tile occupancy should become gameplay pathing instead of editor warning metadata.
- Confirm whether visible neutral encounters become first-class object records separate from camps, dwellings, and guarded reward sites.
- Confirm whether route effects may be metadata-only until AI/pathing can safely evaluate them.
- Confirm that economy/resource schema migration happens before persistent resource-front bundles expand beyond current resource ids.
- Confirm animation cue ids can be planned before the cue catalog exists, with warnings rather than hard validation.

## Done Criteria For This Planning Slice

- The current schema/content reality is documented.
- The target field contract covers primary class, secondary tags, footprints/body tiles, approach offsets/sides, passability classes, interaction cadence, guard/reward links, ownership/capture states, route effects, resource-site linkage, animation cue ids, AI valuation hooks, editor/tooling implications, validation rules, migration sequence, and rollback concerns.
- The staged migration order is explicit: additive schema first, validator warnings, sample fixtures, content migration bundles, then renderer/editor/pathing/AI adoption.
- No JSON content, runtime code, scenario placement, renderer mapping, asset import, or generated PNG ingestion is performed in this slice.
