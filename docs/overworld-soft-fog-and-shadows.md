# Overworld soft fog and object shadows

Slice: `art-overworld-soft-fog-shadows-20261014` (owner choice from comparison sheets, 2026-10-14: "Fog E but shadow B").

## Problem

Fog of war was drawn per tile in the state layer: an opaque rectangle plus a veil slice for every unexplored tile and a feather inside explored frontier tiles. Its edge followed the tile grid in stair steps. Map objects had no shadows, so trees, mines and creatures looked pasted onto the ground.

## Soft fog (`scenes/overworld/overworld_fog.gdshader`, `OverworldFogSurface.gd`)

- **Fog-edge tiles**: the ground lookup's green channel is 255 for explored, 128 for unexplored tiles touching explored land in any of eight directions, and 0 deeper (`OverworldGroundSurface.sync_lookup`). The ground shader paints fog-edge tiles' ground, which may blend with explored neighbours. Deeper tiles stay identity-silent, and decals still need explored tiles. Objects are never drawn on unexplored tiles.
- **Surface**: one full-board ColorRect above the state layer (objects) and below the dynamic layer (moving hero, path). It follows the ground surface: same rectangle, same world mapping, same lookup texture, so panning needs no upload.
- **Edge**: explored share around each point is a cubic B-spline over the surrounding 4x4 tiles (0.5 on a straight tile edge). It is bent by four octaves of rotated value noise (`warp_tiles` 0.38) and faded over `band_tiles` 0.7. The fade straddles the explored boundary, so it thins over the painted fog-edge ground and lightly veils the outer rim of explored land.
- **Never leaks**: a second ramp completes the fade before painted fog-edge ground ends, so corners never show a step. Deep-fog tiles are always fully covered.
- **Look**: the existing cartographic veil (`unexplored_cartographic_veil_rich.png`) over the unexplored underlay colour, mapped once over the whole map.
- The per-tile veil and frontier feather remain only for the HoMM3 tile renderer and when the ground surface cannot draw (`_soft_fog_active`).

## Object shadows (`scenes/overworld/OverworldObjectShadow.gdshader`)

- Every map object drawn by the state layer (living scenery, scenery icons, pickups, mines, sites, creatures, control flags) also lays its own silhouette on a render item drawn behind the state layer's content.
- The silhouette is softened by a 5x5 gaussian (`OBJECT_SHADOW_BLUR_PX` 6 px). It is slanted up and to the right (`OBJECT_SHADOW_SHEAR` -0.75) and squashed onto the ground (`OBJECT_SHADOW_SQUASH` 0.42) about a foot point 6% above the sprite's bottom, as if lit from in front and to the left. Strength is `OBJECT_SHADOW_ALPHA` 0.36, scaled by the turn-actor dimming.
- A painting drawn as per-tile slices (forest formations, mines, flags) casts the whole painting once per frame, so slices never cast rectangles.
- Only explored parts cast, and only onto explored ground: the shader masks by the ground lookup at the casting texel (`VERTEX`) and where it lands (`MODEL_MATRIX`). A forest running into the fog therefore never shadows its hidden trees.
- Towns cast none: their art carries its own ground plane. Ground decals (single trees and bushes painted by the ground shader) cast none. The hero moving in the dynamic layer casts none while it walks.

Presentation only: fog rules, exploration, gameplay and saves are unchanged.

## Tuning

Fog: `band_tiles`, `warp_tiles` in `overworld_fog.gdshader`. Shadows: the `OBJECT_SHADOW_*` constants in `OverworldMapView.gd`, `tone` in the shadow shader.

## Validation

Comparison sheets of five fog variants and four shadow variants on generated maps were reviewed by the owner. `tests/overworld_sandy_shore_regression.py` (fog-edge tiles paint their ground; deeper fog stays identity-silent; pan stability) passes. The game was run once on a land map and an island map, and the core suite passes.
