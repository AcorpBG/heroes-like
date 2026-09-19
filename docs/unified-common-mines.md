# Unified common mines

Owner direction: 2026-09-19; option B, Stonework Guilds, selected on 2026-09-20. All twelve legacy common sites now resolve to three original, biome-neutral buildings. Existing site IDs remain valid for maps and saves.

| Resource | Shared identity | Daily production while controlled | Moving parts |
| --- | --- | ---: | --- |
| Wood | Sawmill | 2 | Rotating flywheel and circular saw |
| Ore | Ore Mine | 2 | Traveling cart, lifting bucket and winding drum |
| Gold | Gold Mine | 1,000 | Lifting bucket and winding drum |

Each chimney emits a continuous plume of overlapping, rising billows. Ash-grey cores and darker soft edges keep it visible against both vegetation and pale terrain at normal map scale. Lanterns independently brighten and dim their glass and the surrounding doorway stonework, with placement-specific timing. Walls, roofs and foundations stay stationary. The existing reduced-motion setting freezes machinery and lights and removes smoke. GPU animation runs in cached scenery batches without changing simulation or saved state; every painted cell, including smoke, is clipped to explored fog.

## Ground footprint and compatibility

All three mines occupy three columns by two rows. The south-middle cell is the entrance; the other five cells block movement. `CommonMineRules.gd` supplies this shared geometry to gameplay occupancy, interaction and rendering. The entrance remains at the placement's existing visit tile; authored and generated runtime footprint overrides cannot shrink the new building.

The approved building art renders at 75% of its initial size, uniformly scaled around the same ground anchor. Its painted height is approximately two and a quarter tile rows instead of three; the roof keeps its original proportions. Machinery, lights and chimney smoke use the same transform. This visual adjustment does not change the six-cell gameplay footprint and applies to existing maps when reloaded.

This is an explicit game-level geometry override for owner-selected common mines. Native generator placement rules and source package masks remain immutable. Existing placements are not relocated or regenerated. This slice does not claim native RMG parity or guarantee that every historical map reserved this new shape without neighboring overlap.

Only sites marked `common_mine_resource` use these rules. Supporting producers, loose reward references and rare mines remain separate. The native bridge translates four historical common object IDs to rare resources; rendering now prioritizes that live rare site identity over the historical object painting.

## Art and rebuild

The approved source paintings and full image-generation prompts are in `art/overworld/source/generated/mines/stonework_20260920/`. Neutral masonry, timber and metal have transparent surroundings, with no required river, grass mat, sand plate or snow bed. The earlier A/B/C proposal originals are retained as provenance.

Run `python tools/pack_unified_mines.py` with Pillow to rebuild the three building bases, machinery atlases, static previews and `art/overworld/common_mines.json`. It crops, scales and registers the painted layers. `OverworldMine.gdshader` animates those detached parts, anchored smoke and lights. Both Windows and Linux use the same resource paths and Godot canvas shader.

## Focused verification

`tests/unified_mines_regression.py --godot <executable> --output <temporary directory inside repo>` checks all twelve aliases, controlled daily production, ownership, five solid cells plus entrance, runtime-mask precedence, rare-site routing, immutable package/save state, fog clipping, cached drawing, moving pixels in every mechanism and lamp, chimney smoke, stationary foundations and reduced motion. Smoke contrast and lamp variation must cover a visible area, not merely change a pixel. The gallery uses actual grass, sand and snow textures, including 58- and 36-pixel tiles. The 75% scale revision passes 181 focused checks and was visually inspected at those scales; the number of per-cell fog checks follows the rendered area. It uses a short isolated render scene and disposable settings profile; it does not launch a full playtest or run the full repository suite. Generated captures and logs are disposable after visual review.
