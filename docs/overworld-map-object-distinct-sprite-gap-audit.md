# Overworld Map Object Distinct Sprite Gap Audit

Slice: `overworld-map-object-distinct-sprite-gap-fill-10184`

## Scope

This audit covers authored overworld map objects in `content/map_objects.json`.
It intentionally does not broaden into town, hero, unit, battle, terrain, road,
or UI art. Those systems have separate content and rendering contracts.

## Baseline

- Authored map objects: 386.
- Decorative/blocker objects already covered by
  `art/overworld/decorative_object_sprites.json`: 200.
- Non-decoration objects with a preexisting unique non-decorative sprite
  assignment: 8.
- Remaining non-decoration objects without a distinct sprite assignment: 178.

## Gap Breakdown

The 178 generated gap objects are:

- neutral_dwelling: 32.
- guarded_reward_site: 32.
- transit_object: 27.
- scenario_objective: 14.
- mine: 10.
- faction_landmark: 9.
- pickup: 9.
- staged_resource_front: 9.
- repeatable_service: 7.
- scouting_structure: 6.
- neutral_encounter: 6.
- support_producer: 6.
- shrine: 6.
- sign_waypoint: 5.

## Implementation Evidence

- `art/overworld/map_object_sprites.json` records the 178 object-to-sprite
  mappings, source provenance, generated batch count, and coverage totals.
- `art/overworld/manifest.json` references the new map-object sprite manifest
  and includes the 178 new object assets under `object_assets`.
- Runtime sprites live under
  `art/overworld/runtime/objects/map_objects/distinct/`.
- Trimmed source sprites live under
  `art/overworld/source/trimmed/map_objects/distinct/`.
- Generated atlas sources live under
  `art/overworld/source/generated/map_objects/distinct/`.
- `scenes/overworld/OverworldMapView.gd` resolves resource and encounter
  placements through object-specific map-object mappings before falling back to
  shared resource/default sprites.

## Validation Contract

The repository validators must prove:

- 386 authored map objects are covered after combining the 200 decorative
  foundation mappings, 8 preexisting unique non-decoration assignments, and 178
  new generated map-object assignments.
- The 178 new mappings are one-to-one and all referenced assets exist.
- Runtime sprites use the 512x512 object canvas and have import sidecars.
- Generated source atlases and trimmed source sprites are present.
- Generated assets record the no-HoMM3-art import policy.
