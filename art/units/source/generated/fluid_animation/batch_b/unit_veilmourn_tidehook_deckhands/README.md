# Tidehook Deckhands H3 animation

Published six dedicated actions containing 187 selected original video frames; retained the original eight-frame articulated idle at 240 ms and the exact overworld idle catalog/strip.

| Action | Accepted take | Frames | Frame duration | Behavior |
| --- | --- | --- | --- | --- |
| Move | move_v3 | 32 | 50ms | One complete reciprocal walking cycle; two planted support phases and clear foot passing |
| Attack | attack_v3 | 30 | 40ms | Compact draw/lift, forward hook contact at index 12, recovery |
| Defend | defend_v2 | 30 | 32ms | Raise rigid hook, flex knees, hold the final guard |
| Hit | hit_v1 | 25 | 35ms | Backward recoil and original ready recovery |
| Support | cast_v3 | 33 | 50ms | Physical bell signal at index 11, settle and lower; no invented spell |
| Death | death_v1 | 37 | 50ms | Kneel, continuous side collapse, grounded final corpse |

The runtime atlas is 3920x3248. All 196 candidate/live clip poses, 187 selected source-frame pixels/anchors/timings, 66 selected provenance hashes and other 231 creature records were verified. Dead uses the final death frame. No gameplay/simulation or save changes.

## Identity and extraction

One lean blue hooded spectral sailor, two arms and two wrapped shins with bare blue feet. Right hand retains one rigid J-shaped steel boarding hook; left hand retains one short bronze chain and one brass bell with its original cyan flame. Original coat/hair wisps remain.

Older action reference paintings use a fixed 0.875 anatomical scale; the later accepted idle paintings use 1.0. H3 guides are 960x544 with ground anchor [480,490] and fixed 0.5 extraction. No per-frame scale normalization, body warping, generated interpolation, reversed motion or duplicated-frame padding. Green-key extraction protects measured original foreground chroma 57 and retains every opaque connected component, including thin wisps and loose death props. Timing compresses redundant holds while retaining dense actual transitions; exact source indices/timestamps are in each selection/handoff.

## Corrections and rejected originals

- move_v1 repeated one leading step. Two image-guide attempts in walk_guide_v1 and walk_guide_v2 failed to change the leading leg and remain rejected. Their originals, exact prompts and reference hashes are preserved.
- move_v2 improved reciprocal gait but invented a cyan crescent under the bell fist. move_v3 uses original accepted idle 14 as a clearer hand/chain reference and restrained carry; the extra object is absent.
- attack_v1 stretched the hook into a long straight blade at 33. attack_strike_v2 preserved the hook but added detached slash arcs. attack_v3 changes the action to a compact draw and forward thrust, keeping the rigid hook; brief attached transition blur is preserved, not painted out.
- defend_v1 added a detached cyan blade trail. defend_v2 uses a slow dedicated brace with an intermediate guard and retains both original grips.
- cast_v1 invented a second dangling cyan wrist object. cast_v2 removed it but jumped between mixed reference families at 30-31 and 100-101. cast_v3 uses matching idle 14/17 guides with one midpoint and has a continuous two-arm signal and return.
- hit_v1 retains its clean first recoil and recovery; matching leaning poses 50 and 80 omit the redundant second sway. death_v1 preserves its continuous descent and settled equipment.

All 13 generated original videos, lossless originals, sampler latents, 31 guide images, seeds, exact prompts, workflows, source RGB hashes and failed takes remain. Selected mattes are retained; unused mattes and Comfy duplicates can be rebuilt from the originals. Image-guide originals and prompts are in their versioned directories; no rejected guide is used in production.

## Review and rebuild

Review covered all chronological original frames, enlarged identity/equipment/alpha details, loop endpoints, every selected native Godot phase and live battle/map idle renders. Continuous video playback, manual playtesting and Linux execution are not claimed. The agent owns routine acceptance and publication.

Focused final candidate checks: 253 passed. Focused published checks: 267 passed. Godot import succeeded; only the known Windows certificate-store error and GLES3 2D MSAA warning appeared. No full repository suite was run. Roster 149/232 complete, 83 remaining at this publication.

Use produce.py process/review/build/assemble to rebuild preserved mattes and handoffs. stage_video.py retains sampler latents before releasing large models and performs tiled VAE decode; run_batch.py samples/decodes pairs. Do not overwrite submitted takes. delivery.json selects only accepted clips. Runtime output: art/animation/runtime/fluid/unit_veilmourn_tidehook_deckhands.png; live metadata: content/unit_animation_manifest.json.
