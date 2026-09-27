# Bellwake Oars video animation source

Six dedicated MiniMax H3 actions, 173 selected original frames. Original eight-frame articulated idle (240 ms per frame) and overworld idle pixels are preserved.

| Action | Original takes | Frames | Frame duration |
|---|---|---:|---:|
| Move | move_v1 | 32 | 40 ms |
| Attack | attack_thrust_v3, then attack_v1 recovery | 43 | 35 ms |
| Defend | defend_v1 | 15 | 45 ms |
| Physical support | cast_v1 | 22 | 55 ms |
| Hit | hit_v2 | 29 | 30 ms |
| Death | death_v1 | 32 | 45 ms |

The attack contacts at selected index 24. Defense holds its final crouched guard; dead uses the final grounded death frame. The melee support gesture lifts the oar and bell without inventing magic. Hit briefly releases the lower hand, as in the original recoil guide, then regrips; the upper hand retains the oar throughout.

Each take retains exact prompts, original-pose guide crops and hashes, seed, API workflows, sampler latent, lossless decoded video, original RGB hashes and matte recipe. Generation uses the local FL2VA int8 model, Qwen3-VL 32B NVFP4 encoder and int8 VAE: 960 x 544, 124 frames at 24 fps, 20 res_multistep/simple steps. Sampling saves the latent and unloads large models before tiled VAE decoding (256/64 spatial, 16/4 temporal). Extraction uses one fixed 0.6 scale and [480, 480] ground anchor; no per-frame normalization, invented inbetweens, reverse playback or duplicated padding.

`selection.json` files identify chronological source frames and deliberate compact action timing. `delivery.json` combines the clean attack approach with the matching first-take contact/recovery. `produce.py process`, `build` and `assemble` rebuild mattes and handoffs from retained originals; `stage_video.py` records the generation route. Runtime publication uses the repository's existing selected-clip publisher.

## Corrections and exclusions

- attack_v1: reject broken/detached shaft and bell during windup 19-24. Only clean recovery 90, 94-106 is published.
- attack_v2: reject unintended overhead movement and spinning recovery. Preserve its original source, publish none of it.
- attack_thrust_v3: changed control to ready/contact endpoints instead of another full-cycle prompt. The continuous shaft, two grips and matching recovery join were reviewed.
- defend_v1: periodic black plates are excluded in `extract_ranges.json`; selected uniform-blue originals cover the full crouch transition. No black pixels are interpreted as transparency.
- hit_v1: reject background failures spanning recoil. hit_v2 uses magenta and an original recoil midpoint. Exclude its unwanted opening projectile/effect; only the clean recoil/recovery beginning at frame 24 is published.

## Verification

Reviewed all chronological original phases, enlarged selected anatomy/equipment and light/dark alpha edges, fixed-anchor boundaries, and every selected frame in the native 128 px Godot battle overview. Focused candidate checks: 602 passed; published checks: 616 passed. Verified every selected source pixel/anchor, timing/contact/held poses, provenance hashes, candidate-to-live per-clip pixels, exact idle preservation and all other 231 creature entries unchanged. Candidate and publisher pack clips in different orders; comparison follows each clip's indices rather than assuming identical atlas layouts. Final atlas: 3772 x 2340, within the 4096 limit.

Continuous playback and a manual game playtest were not performed. Windows Godot checks only; no Linux or full-suite claim. Temporary review images, check outputs, unused rebuildable mattes and verified ComfyUI duplicates are disposable; original art, video, latent, selected source frames and provenance are retained.
