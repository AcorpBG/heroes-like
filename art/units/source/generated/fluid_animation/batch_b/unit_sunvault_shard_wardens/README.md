# Shard Warden animation sources

Target `unit_sunvault_shard_wardens`, a Sunvault melee guard. Preserve the
reviewed eight-pose idle (240 ms): right elbow lifts and lowers the mace, left
arm adjusts the shield, head and shoulders follow, and both boots stay planted.
Six dedicated MiniMax H3 actions replace deficient battle clips.

Identity: short brown hair, exposed human face, white/gold plate, blue scarf and
split tabard, violet gems, two arms and two legs. The right hand carries one
short-shafted cylindrical mace; the left forearm carries one tall blue/white/gold
kite shield. No spells, extra weapons or mirrored hand swaps. Support is a
physical rally salute. The corpse lies head-left with both pieces of equipment.

`configure.py` records exact original poses and anatomical anchors. Guides use
one fixed 1.25 magnification, then extraction uses 0.8 to recover the original
scale. The original opaque art's maximum green excess is 24; a protected band
of 32 separates its palette from the uniform green plate. Review the fine blue
crystal, gold rim and mace edges on both light and dark backgrounds.

`stage_video.py` preserves each sampled latent before unloading the large
models and decoding in a separate tiled VAE job. Original videos, prompts,
graphs, seeds, guides, hashes and exact timestamps are retained. Selections
require complete chronological, enlarged and native-scale review before
publication; generation success does not establish acceptance.

## Accepted delivery

Autonomous chronological original-frame review, enlarged identity/alpha/limb review, gait seam and attack joins, and native Godot phase inspection completed. 124 selected H3 frames: move 17, attack 32, defend 14, hit 16, physical support 20, death 25. Original articulated idle 8 at 240 ms preserved. Corrected physical strike replaces the first take magical flash; four death frames exclude only verified disconnected background specks with original-pixel rectangles. Candidate checks: 190 passed. Final live checks: 213 passed, including every attack phase, contact/recovery, interruption and simulation-state checks. The initial 45 ms impact was missed by the live contact snapshot; its original frame now holds 90 ms, with the other 31 frames at 45 ms, total 1485 ms. No reversed/interpolated frames, continuous video-player review or manual playtest claimed.

Original lossless videos and sampled latents, guides, seeds, workflows and hashes
are retained for all seven takes, including rejected attack footage. Unselected
mattes and disposable review/test exports can be rebuilt. Only the six reviewed
actions are replaced; all other creatures and overworld idle pixels are unchanged.
