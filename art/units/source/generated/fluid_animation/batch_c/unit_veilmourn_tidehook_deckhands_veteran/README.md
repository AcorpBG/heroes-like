# Mooring Talons H3 production

Published seven dedicated actions for `unit_veilmourn_tidehook_deckhands_veteran`. The hooded human retains the charcoal leather coat, rope harness, burgundy sash, two arms, two legs and exactly one bronze boarding hook in each hand.

| Action | Original frames | Frame duration | Behavior |
|---|---:|---:|---|
| idle | 31 | 110 ms | Both forearms raise and lower the paired hooks with planted boots |
| move | 18 | 70 ms | Reciprocal two-step gait with opposing arm swing |
| attack | 26 | 35 ms | Hook windup, forward far-hand thrust and recovery |
| hit | 25 | 30 ms | Backward recoil with raised arms, then balance recovery |
| defend | 17 | 35 ms | Lowered wide brace with both hooks held ready |
| cast | 21 | 50 ms | Physical raised-hook boarding signal and return to ready |
| death | 24 | 45 ms | Knees buckle, torso falls forward and the corpse settles |

The terminal death original supplies the persistent corpse. Overworld idle uses the same 31 reviewed originals. The battle atlas is 3344 x 4080, 54,574,080 uncompressed RGBA bytes. Contact indices and exact original timestamps are recorded in the handoff and selections.

Local MiniMax H3 ordinary int8 generated 124 original frames per take at 24 fps, with 20 res_multistep/simple steps. Original sampler latents were saved before releasing the encoder/denoiser and performing tiled VAE decoding. Every lossless FFV1 decoded RGB frame was verified against the original ComfyUI PNGs. The normal canvas is 960 x 544; support uses 960 x 640 for overhead hook clearance, with the same anatomical scale and bottom margin. Extraction uses one fixed 0.5 scale, without per-frame normalization, warps, interpolation or reverse frames.

Built-in image generation supplied original guard and boarding-signal key poses from the existing identity. Their exact prompts, source hashes and generated masters remain in `keys/`. All seven original H3 takes are retained. Long opening, held-action and closing intervals were shortened for gameplay; the rapid melee strike retains every original through source frames 44-48. Walking uses a reviewed complete reciprocal cycle from source 8 through 42, with the matching next passing phase at 44. No artificial poses pad the sequence.

Autonomous visual review covered all 124 chronological originals in every take, enlarged anatomy/grips/alpha edges on dark and light backgrounds, loop endpoints and every selected native battle phase. Published battle and actual overworld-shader renders were inspected. Continuous video playback, a manual game playtest and Linux validation were not performed. No full suite ran.

Focused Windows Godot checks passed: candidate 230, published 234. All 162 selected original pixels and anchors match the live atlas; all 163 live clip poses including the corpse match the candidate. All 31 map-idle frames match, 84 provenance hashes and 7 takes/13 guide references verify, and the other 231 unit/map entries remain unchanged. Roster after publication: 158/232 complete, 74 remaining.

Rebuild using `produce.py`, `stage_video.py`, `run_batch.py`, retained configs/selections and `delivery.json`. Original videos and latents, generated keys, selected RGBA frames, prompts and provenance are retained. Unselected mattes can be rebuilt from the lossless originals; temporary review/test outputs and verified duplicate Comfy files are disposable.
