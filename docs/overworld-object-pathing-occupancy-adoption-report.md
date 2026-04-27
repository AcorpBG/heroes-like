# Overworld Object Pathing Occupancy Adoption Report

Status: implementation evidence.
Date: 2026-04-27.
Slice: `overworld-object-pathing-occupancy-adoption-10184`.

## Adopted Semantics

Runtime pathing now consumes authored `body_tiles` and `approach.visit_offsets` for placed resource objects that have linked `map_object` metadata. The adopted convention is:

- scenario placement `x,y` is the footprint anchor;
- `footprint.anchor: "bottom_center"` places the local footprint rectangle above the anchor, centered horizontally;
- `body_tiles` are local offsets inside the visual footprint and are the only authored object tiles that block pathing;
- `approach.visit_offsets` are computed separately from body tiles and remain pathable visit/interaction tiles;
- objects without authored `body_tiles` keep their prior compatibility behavior.

This intentionally does not infer rectangular blocking from `footprint.width` and `footprint.height`.

## Representative Proof Object

`object_brightwood_sawmill` is the bounded representative object. It has a `5x3` visual footprint with a non-rectangular `10` tile blocking body mask and one separate interaction tile. The placed `brightwood_sawmill` resource node in `ninefold-confluence` proves:

- a body tile such as `16,3` blocks movement;
- the interaction tile `16,4` is inside the visual footprint but not blocked;
- a visual footprint tile outside the body mask, such as `18,4`, remains pathable;
- entering the interaction tile visits/captures the resource node;
- movement from the interaction tile into a body tile is rejected.

Focused proof lives in:

- `tests/overworld_object_pathing_occupancy_report.gd`
- `tests/overworld_object_pathing_occupancy_report.tscn`

## Deferred

No renderer sprite import, production asset migration, save migration, `SAVE_VERSION` bump, broad production JSON migration, route-effect adoption, AI behavior switch, town footprint migration, neutral encounter pathing migration, or editor placement enforcement was performed.

Economy policy remains unchanged: `wood` is canonical, no alternate wood-resource alias was introduced, and rare resources remain staged/report-only.
