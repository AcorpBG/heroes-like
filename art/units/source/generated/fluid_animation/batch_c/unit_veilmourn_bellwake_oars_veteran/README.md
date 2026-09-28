# Knellwake Wardens H3 production

Published seven dedicated actions for `unit_veilmourn_bellwake_oars_veteran`, retaining the original hooded human, near-forearm shield, wooden oar and attached bell.

| Action | Selected original frames | Frame duration | Behavior |
|---|---:|---:|---|
| Idle | 31 | 90 ms | Both hands adjust the oar, with elbow, cloth and bell motion |
| Move | 31 | 60 ms | Two slow reciprocal walking cycles beneath the cloak |
| Attack | 32 | 35 ms | Corrected paddle approach, contact at index 15, retained clean recovery |
| Defend | 18 | 35 ms | Planted knee bend into a held shield/oar brace |
| Hit | 24 | 30 ms | Backward shoulder recoil, front-boot lift, return to ready |
| Support | 24 | 40 ms | Near hand salutes at chest, then regrips the oar |
| Death | 34 | 35 ms | Knees buckle, body falls sideways, equipment settles |

The corpse uses the final death frame. Overworld idle uses the same 31 accepted idle originals. The compact battle atlas is 3264 x 3044 (39,742,464 uncompressed RGBA bytes), within the 4096 dimension limit.

Production used local MiniMax H3 ordinary int8, 960 x 544, 124 source frames per take at 24 fps, 20 res_multistep/simple steps, staged sampling and tiled VAE decode. Eleven original takes are preserved. Missing guard, salute and recoil keys were generated with the built-in image tool; exact prompts, masters and reference hashes are in `keys/`. Selection compresses long source holds without inventing or reversing frames. One anatomical scale per guide and the fixed extraction scale preserve body proportions.

Rejected material remains available as original video/latent/provenance: the first guard key moved the shield to the wrong arm; the first melee onset reversed/distorted the paddle; hit v1 invented effects; hit v2 inherited a swapped shield from the old flinch pose; support v1 clipped the paddle. The hit reference was reassessed and replaced before v3 generation. Attack uses the corrected v2 approach and only the clean v1 recovery. Individual `selection.json` files identify every retained original frame and timestamp through their handoffs; `delivery.json` assembles the final set.

Review covered complete chronological source sequences, enlarged anatomy/grips/alpha edges and every selected native 128px battle phase. Published battle and actual overworld-shader renders were also inspected. Continuous video playback, a manual game playtest and Linux validation were not performed. No full repository suite ran.

Focused Godot checks passed: candidate 651, published 655. Pixel/anchor verification matched all 194 selected originals to the live atlas and all 195 live clip entries (including corpse) to the candidate. All 31 map-idle frames matched, 98 provenance hashes and 18 guide references were checked, and the other 231 units and map entries were preserved. Roster acceptance after this unit: 155/232 complete, 77 remaining.

Rebuild with `produce.py prepare/verify`, `run_batch.py <take names>`, then `produce.py process/review/build` and `produce.py assemble` using the retained selections. Retained lossless MKVs rebuild unselected mattes. See the shared animation skill for candidate checks and selected publication. Temporary review/test exports and hash-verified Comfy duplicates are disposable; original guides, videos, latents, accepted mattes, prompts and provenance are retained.
