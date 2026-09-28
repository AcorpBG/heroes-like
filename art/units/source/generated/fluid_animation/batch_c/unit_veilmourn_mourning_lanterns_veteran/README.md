# Lastlight Keepers H3 production

Published eight dedicated actions for `unit_veilmourn_mourning_lanterns_veteran`, retaining the hooded human, charcoal and ivory robes, two arms, one rigid staff and one attached blue-over-amber lantern housing.

| Action | Original frames | Frame duration | Behavior |
|---|---:|---:|---|
| Idle | 31 | 90 ms | Near hand lifts to steady the lantern, then relaxes |
| Move | 31 | 70 ms | Reciprocal walking under the robes with staff and ribbon motion |
| Attack | 33 | 35 ms; one 70 ms interval | Two-handed backswing, forward staff-butt strike and recovery |
| Ranged | 34 | 35 ms | Staff aims forward with open-hand release cue, then recovers |
| Defend | 18 | 40 ms | Two-handed upright staff guard with lowered shoulders |
| Hit | 27 | 35 ms | Backward recoil, lifted front boot and balance recovery |
| Support | 23 | 40 ms | Physical open-hand vigilance signal, without added magic |
| Death | 27 | 35 ms | Kneeling collapse into a grounded side corpse |

The final death original supplies the persistent corpse. Overworld idle uses the same 31 reviewed originals. The battle atlas is 3200 x 3336, 42,700,800 uncompressed RGBA bytes. Melee contact is index 12, ranged release 17 and support signal 10.

Production used local MiniMax H3 ordinary int8, 124 original frames per take at 24 fps, 20 res_multistep/simple steps, staged latent preservation and tiled VAE decoding. Thirteen original takes are retained. The baseline canvas is 960 x 544. Attack and guard v2 use 960 x 640 with 96 pixels of added headroom; anatomical scale and ground margin are unchanged. The unit collector preserves configurable canvas dimensions and verifies every lossless decoded RGB frame against ComfyUI's original PNGs. Extraction uses a fixed 0.5 scale, without per-frame normalization, warps, reversed frames or interpolation.

Built-in image generation supplied melee, guard and hit key poses. Exact prompts and original reference hashes remain in `keys/`. The v1 attack and guard clipped staff tips and remain unpublished. The taller guard correction is clean. Attack v2 originals 34-35 still clipped during the high overshoot; these whole frames are excluded. Clean originals 33 and 36 retain the adjacent swing angles, with a 70 ms interval at 33. The transition and complete staff were inspected at native scale; missing tips were not repainted.

Ranged v1 had hard pose cuts and was replaced by separate guided approach/recovery takes. Hit v1 changed its background through orange, magenta, red and yellow: only the clean green-plate recoil through frame 20 is used. A separately generated recovery starts from that exact extracted original. Rejected videos, latents, guides, prompts and extraction records are preserved.

Autonomous review covered every chronological original in selected takes, enlarged anatomy/grips/alpha edges, loop endpoints and every selected native 128px battle phase. Published battle and actual overworld-shader renders were inspected. Continuous video playback, a manual game playtest and Linux validation were not performed. No full suite ran.

Focused Windows Godot checks passed: candidate 749, published 753. All 224 selected original pixels/anchors match the live atlas; all 225 live clip poses including the corpse match the candidate. All 31 map-idle frames match, 121 provenance hashes and 13 takes/24 guide references verify, and the other 231 unit/map entries remain unchanged. Godot emitted the known Windows certificate-store and GLES3 MSAA warnings; no animation assertions failed. Roster after publication: 157/232 complete, 75 remaining.

Rebuild with `produce.py`, `stage_video.py`, `run_batch.py`, retained configs/selections and `delivery.json`. Lossless MKVs rebuild unselected mattes. Temporary review/test exports and verified duplicate Comfy outputs are disposable; source masters, original videos/latents, selected mattes, prompts and provenance remain. The pre-existing `idle_cast_v1.prompt.txt` is unrelated and untouched.
