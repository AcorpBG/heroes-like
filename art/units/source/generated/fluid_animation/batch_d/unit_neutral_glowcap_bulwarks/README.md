# Glowcap Bulwarks H3 action production

Completed solo. Six H3 actions supply 156 selected original frames. The existing eight articulated idle poses remain pixel-identical: elbow and spear lifts, shield counter-motion and return, with both boots grounded. Battle and overworld idle pixels and timing are preserved.

Identity: a stout grey-bearded dwarf, green scarf/tabard, brown leather armor and wrapped boots. Exactly two arms and two legs. The right hand at screen left holds one wooden spear with one metal head; the left arm at screen right supports one layered grey-lilac mushroom shield. Cyan-blue caps remain on the helmet, shoulders and shield. Elevated three-quarter camera, screen-right combat orientation.

Six action-specific H3 takes cover reciprocal gait, spear anticipation/thrust/recovery, recoil/recovery, a held shield guard, a physical spear salute, and continuous collapse to a grounded corpse. No ranged weapon or magic is invented. Existing sources and sparse action paintings provide identity/key poses.

Guide registration: older original paintings use their recorded whole-source scale times 0.84 to match the later accepted idle anatomy. Every decoded frame uses canvas 960 x 640, anchor [416,550] and scale 0.5. No per-frame normalization, stabilization, reverse padding or synthetic articulation. The original guide foreground measured maximum green chroma 24; a protected band of 26 retains the olive costume while separating the uniform green studio plate. Each generated plate still requires independent review.

Run run_batch.py with explicitly selected take names. stage_video.py preserves original sampler latents before releasing large models and decoding with the VAE. produce.py preserves and verifies every lossless RGB frame, extracts transparent mattes, makes chronological review sheets, and builds a pending handoff from explicit selections. Original source videos, latents, guides, exact prompts/workflows and provenance remain immutable. Candidate/runtime previews and duplicate Comfy outputs are disposable after validation.

Selected actions:

| Action | Take | Frames | Duration | Contact |
|---|---|---:|---:|---:|
| Move | move_h3_v1 | 21 | 1050 ms loop | alternating boot contacts |
| Attack | attack_h3_v2 | 29 | 1160 ms | 440 ms |
| Hit | hit_h3_v3 | 26 | 780 ms | recoil and recovery |
| Defend | defend_h3_v2 | 15 | 630 ms | held shield brace |
| Support | cast_h3_v2 | 24 | 1080 ms | 450 ms |
| Death | death_h3_v1 | 41 | 1435 ms | final grounded corpse |

Every selected take's 124-frame chronology and enlarged equipment/feet transitions were reviewed, followed by all 156 native Godot phases and battle phase renders. This is frame-by-frame review, not a continuous-playback or manual-playtest claim. Selected frame indices, deliberate retiming and review notes are in each take's selection.json. No reversed or interpolated frames are used.

Rejected originals are retained: attack v1 distorts the spear during the overhead turn; hit v1 invents an incoming beam; hit v2 collapses the spear shaft during the forward duck; defend v1 changes its green backdrop to black; cast v1 adds a tip flash and pointed butt. Corrections use compact thrust, backward recoil with upright spear, a constant plate and an upright support salute. No rejected take is published.

The candidate passed 237 focused checks and the published delivery passed 251; the isolated headless import also succeeded. The source/pixel verifier confirmed all 1,364 original RGB frames, 20 original guide hashes, all 156 published frame pixels and anchors, unchanged idle/map pixels, and unchanged other 231 units. The runtime atlas is 3872 x 4080, within the 4096 limit. No full repository suite or Linux execution claim.

Original lossless videos, MP4s, sampled latents, guides, prompts, workflows and provenance are retained, including rejected takes. Only selected mattes are retained; produce.py process rebuilds the remaining mattes from the preserved lossless video. Disposable previews, test profiles and verified duplicate Comfy outputs are removed after validation.
