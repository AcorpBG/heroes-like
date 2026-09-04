# Overworld Raster Terrain And Visible Blocker Mass Requirements

Task: #10231
Slice: `ux-overworld-raster-terrain-and-visible-blocker-mass-10231`
Phase: Phase 6 - Production Alpha Layer
Status: completed 2026-09-04

## Owner Direction

The generated Overworld must stop looking sterile, tiled, and unfinished. Ground texture needs natural raster variation rather than repeated vertical scratches, and every blocked area must visibly communicate its physical cause through trees, rocks, ridges, mire, water, or another biome-appropriate original asset.

## Diagnosed Baseline

- `OverworldMapView` draws five deterministic line pairs over every non-water tile. Repeating this per-tile procedural microtexture creates the conspicuous scratch/streak grid seen in the live Medium capture even when raster base tiles load successfully.
- Native-package `package_block_tiles` are correctly adopted as authoritative body/collision cells, but presentation marks only one to three body members per source object as visual anchors. Non-anchor body cells explicitly return as successfully drawn without drawing anything, so legitimate collision can appear invisible.
- Existing generated decorative-body art is manifest-backed original raster content. The failure is primarily resolution and coverage, not missing map identity: sparse anchor selection suppresses the physical mass that the package already owns.

## Required Outcome

1. Normal play must not draw procedural terrain scratches, ColorRect/Polygon stand-ins, debug icons, or generic fallback geometry over the Overworld surface.
2. Terrain presentation must resolve through original raster assets and use deterministic large-scale variation that does not restart an identical visual motif on every tile. Variation may alter presentation only; authoritative terrain ids, road records, passability, and package payload stay exact.
3. Every authoritative generated blocker body cell must be visually covered by a manifest-backed raster member appropriate to its biome. Neighboring members should overlap as one readable forest, rock, ridge, mire, or water mass rather than isolated tokens.
4. Raster blocker presentation may extend visually around its owned cell for cohesion, but may not add collision, remove collision, invent interaction, obscure a route entrance, or change action/body coordinates.
5. Visual choice, scale, offset, and layer ordering must be deterministic from existing package/body identity and stable across redraw, camera movement, save/load, Linux, and Windows.
6. Any normal-play body cell without raster coverage or any missing manifest mapping must fail focused validation instead of silently returning success with no visual.
7. If new art is required, it must follow the existing generated/source/runtime/provenance pipeline, use original raster imagery only, and remain within the unchanged package ceiling. No copyrighted reference pixels or names may enter the product.

## Validation

- Focused Godot runtime report for exact authoritative body-cell-to-raster coverage, zero procedural normal-play ground marks, deterministic composition, and unchanged collision/action/package identities.
- Deterministic Medium generated-package case and inspected captures at 1920x1080 and 1280x720.
- Existing generated decorative sprite, distinct object art, live object art coverage, movement/pathing, and native-package adoption checks.
- `python3 tests/validate_repo.py`
- `git diff --check`
- Matching Linux and Windows release export/package startup and generated Overworld entry below 250000000 bytes.

## Non-Goals

- Native RMG count, topology, terrain generation, roads, placement, object selection, density, rewards, guards, retries, gates, or final-payload tuning.
- New collision, changed body/action tiles, movement/pathing/interaction rules, balance, AI, save-schema, Town/Battle UI, signing, publication, whole-game validation, or release-readiness claims.
- Copied Heroes assets, maps, names, DEFs, pixels, or protected visual expression; procedural geometric substitutes for missing art.
