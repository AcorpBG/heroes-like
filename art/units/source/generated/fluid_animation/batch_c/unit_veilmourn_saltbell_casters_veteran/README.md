# Echo-Salt Slingers H3 production

Published eight dedicated actions for `unit_veilmourn_saltbell_casters_veteran`, preserving the masked hooded human, ragged teal cloak, two short cord bells and teal ribbons.

| Action | Original frames | Frame duration | Behavior |
|---|---:|---:|---|
| Idle | 31 | 90 ms | Elbows and wrists lift the bells, then ease back to ready |
| Move | 31 | 70 ms | Three reciprocal walking cycles with suspended bell motion |
| Attack | 25 | 35 ms | Far-hand single-bell backswing, contact and recovery |
| Ranged | 39 | 35 ms | Low paired-bell backswing, forward cast and recovery |
| Defend | 18 | 35 ms | Knees bend and forearms rise into a held guard |
| Hit | 23 | 30 ms | Shoulder recoil, front-boot lift and return to ready |
| Support | 29 | 40 ms | Both arms raise the bells for a physical signal, then lower |
| Death | 34 | 35 ms | Kneeling collapse into a grounded side corpse |

The final death frame supplies the persistent corpse. Overworld idle uses the same 31 reviewed idle originals. The battle atlas is 3120 x 3556, with 44,378,880 uncompressed RGBA bytes, below the 4096 dimension limit. Melee contact is index 13, ranged contact 23 and support signal 11.

Production used local MiniMax H3 ordinary int8, 960 x 544, 124 original frames per take at 24 fps, 20 res_multistep/simple steps, staged sampling and tiled VAE decode. Ten original takes are retained. Built-in image generation supplied dedicated melee, guard and hit keys, with exact prompts and hashes in `keys/`. Selected source intervals compress long holds without invented, reversed or interpolated frames; one anatomical scale per guide and fixed extraction preserve proportions.

The v1 ranged windup clipped a bell at the top of the canvas and was rejected. The clean v1 recovery follows a new low-side v2 approach; the native contact join was reviewed. The first support video's background drifted from green through cyan to blue and back, making full extraction unsafe. Only original frame 61 on its fully blue plate was safely extracted as a pose guide. Its recipe remains in `cast_h3_v1/extraction_settings.json` and `extract_ranges.json`; v2 uses that reviewed pose on a constant green plate and replaces the whole action. Rejected originals remain preserved.

Review covered all chronological originals, enlarged anatomy/grips/alpha edges and every selected phase at native 128px battle reference height. Published battle and actual overworld-shader renders were inspected. Continuous video playback, a manual game playtest and Linux validation were not performed. No full repository suite ran.

Focused Godot checks passed: candidate 767, published 771. Pixel and anchor verification matched all 230 selected originals to the live atlas and all 231 live clip entries, including the corpse, to the candidate. All 31 map-idle frames matched; 109 provenance hashes, 10 original takes and 17 guide references were verified. The other 231 unit and map entries were preserved. Roster acceptance after publication: 156/232 complete, 76 remaining.

Rebuild using `produce.py prepare/verify`, `run_batch.py <take names>`, `produce.py process/review/build` and `produce.py assemble` with the retained configurations, recipes and selections. Lossless MKVs rebuild unselected mattes. Temporary review/test exports and verified duplicate Comfy outputs are disposable; source guides, generated keys, accepted mattes, original videos and latents, exact prompts and provenance remain retained.
