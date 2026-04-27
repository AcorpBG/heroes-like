# Animation Overworld Object State Contract Report

Status: implementation evidence.
Slice: `animation-overworld-town-object-cue-hooks-10184`.
Schema: `overworld_object_state_contract_v1`.

## What Changed

- Added bounded overworld object cue entries in `content/animation_event_cues.json` for idle, active, blocked, guarded, route-open, route-closed, and ambient-loop state contracts, plus a shared `town_captured` hook where the town surface uses the same object-state capture contract.
- Added `AnimationCueCatalog.overworld_object_state_contract_report(...)` to validate overworld object state family coverage, representative event ids, `map_object` / `resource_site` / shared `town` subject coverage, producer refs, fallback coverage, cue playback policy selection, and content-class context.
- Added focused report coverage in `tests/animation_overworld_object_state_contract_report.gd` and `tests/validate_repo.py --animation-overworld-object-contract-report`.

## State Coverage

The contract validates these required state families:

- idle
- active
- visited
- depleted
- captured
- blocked
- guarded
- route-open
- route-closed
- ambient-loop

Representative events:

- `overworld_object_idle`
- `overworld_object_active`
- `overworld_object_visited`
- `overworld_object_depleted`
- `overworld_object_captured`
- `overworld_object_blocked`
- `overworld_object_guarded`
- `overworld_route_open`
- `overworld_route_closed`
- `overworld_object_ambient`

The shared town hook is `town_captured`; it is included only as a town/object-state capture contract and does not broaden this slice into town UI polish.

## Boundaries

- No save migration or `SAVE_VERSION` bump.
- No final sprite, VFX, or audio import.
- No renderer asset pipeline work.
- No final playback runtime.
- No broad UI polish or dashboard surface.
- No battle troop contract changes beyond validation compatibility.
- `wood` remains canonical.
