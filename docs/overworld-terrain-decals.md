# Overworld ground detail decals (v4)

Slice: `art-overworld-terrain-decals-v4-20261008` (owner request, 2026-10-08: "completely rework decals: different decals for each ground type, more variety, more seamless integration, more varied placement").

## Problem with the old decals

The old system drew one of 16 painted clusters on roughly every fifth tile, at half a tile, from a single 4x4 atlas. Grass, forest and swamp had their own four clusters, but rough, rock, underground, dirt, sand and ash all shared four "grey granite with green meadow grass" clusters, which looked like stickers or pickups on dirt, sand and lava. Each cluster was a self-contained vignette with a hard rounded outline, drawn on top of the ground per tile.

## Art

- One generated 4x4 sheet per land ground: grass, plains, forest, swamp, dirt, sand, rough, rock, ash, lava, underground, snow and ice (13 sets, 208 decals). Rows 1-2 are tiny details, row 3 medium, row 4 large flat features. Each sheet was generated with that ground's own material from `ground_materials_v3.png` as its only reference, with soft edges, no outlines and no ground disc. Sources and prompts: `art/overworld/source/generated/terrain/decals_v4/` (`manifest.json`).
- `tools/prepare_overworld_terrain_decals.py` packages the sheets reproducibly (`--check` verifies): it cuts each decal from its cell (dropping neighbour fragments), grades its colours 12% toward the ground's mean tone and never raises its contrast above the source, feathers the alpha lightly, bleeds colour into transparent pixels (no dark mip fringes), and packs a 2048x2048 atlas of 128 px cells (`art/overworld/runtime/terrain_tiles/detail/terrain_decals_v4.png`).
- Water (water, coast, shore) has no set and stays clean.

## Rendering

Decals are scattered by the ground shader (`scenes/overworld/overworld_ground_surface.gdshader`, `decal_layer`), so they share the ground's light and blend instead of sitting on top:

- A jittered grid of candidate points (one per `cell_tiles`, 1.0 tile). Each point takes the ground under it, a size class (tiny 52%, medium 32%, large 16%), a random decal of that class and a mirror.
- Density per set (`art/overworld/terrain_decals_v4.json`) is modulated by slow noise, so decals cluster into patches with clearings between them instead of an even sprinkle.
- No decals on roads (the lookup texture's blue channel marks road tiles), unexplored tiles or water. A decal fades with its ground's final share of the border blend (`docs/overworld-ground-borders.md`), so none crosses a biome border.
- Mip levels are explicit (`textureLod`), since implicit derivatives are undefined inside the scatter loop. The ground's local brightness lightly modulates each decal.
- Presentation only: no gameplay, saves or collision. `OverworldMapView._terrain_decal_payload` reports a tile's set for tests.

## Tuning

`art/overworld/terrain_decals_v4.json`: `cell_tiles` (spacing), `opacity`, and per set `density` and `material_slots`. Sizes per class are in `decal_layer`. Rebuild the atlas after changing a source sheet: `python tools/prepare_overworld_terrain_decals.py`.

## Validation

Before/after captures on the owner's map (dirt, lava, snow, grass, swamp, rough, sand) were reviewed; `tests/validate_repo.py` checks the manifests, source hashes, atlas, set coverage of every land ground and the shader contract; `tests/random_map_live_overworld_render_move_report.tscn` checks every explored tile's decal payload on a generated map.

The old atlases (`terrain_detail_decal_atlas*.png`) remain on disk as provenance; the authored Ninefold smoke test still references the v3 atlas and is archived with the authored scenarios.
