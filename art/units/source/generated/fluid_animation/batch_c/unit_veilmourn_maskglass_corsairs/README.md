# Maskglass Corsairs video animation source

Six dedicated MiniMax H3 battle actions are published with182 selected original frames. The reviewed original eight-frame articulated idle at 240 ms and the overworld idle are preserved.

Identity: right-facing human female corsair with a silver half-mask, brown tied-back hair, muted grey-green scarf and cloth strips, ivory sleeves, charcoal trousers and brown boots. The right hand holds one complete curved silver saber with a brass basket hilt; the left forearm holds a dark round buckler with brass rim, spokes and boss. Exactly two arms and two legs; fixed anatomical scale and ground registration.

Each take preserves its exact prompt, original-pose guide crops and hashes, seed, API sampling/decoding workflows, sampler latent, original lossless decoded video, RGB frame hashes and matte recipe. Local FL2VA int8 / Qwen3-VL 32B NVFP4 / int8 VAE; 960 x 544, 124 frames at 24 fps, 20 res_multistep/simple steps. Release encoder/denoiser before tiled VAE decode (256/64 spatial, 16/4 temporal). All extracted frames use scale 0.65 and anchor [480,480]. No frame-wise normalization, invented inbetweens, reverse frames or duplicate padding.

`selection.json` records the exact observed frames and deliberate gameplay timing. `produce.py process`, `build` and `assemble` rebuild transparent frames and the selected delivery. `stage_video.py` preserves sampling separately from decoding; an unsafe plate records an extraction failure and retains the original for review instead of using an automatic fallback.

Review covers every chronological source phase, enlarged details on light/dark backgrounds and fixed-anchor boundaries. Every selected phase was inspected in the native128px Godot overview, with published battle/map renders also reviewed. Continuous video playback, manual playtesting, Linux validation and the full suite are not claimed.

## Source decisions

- Original idle14-21 has clear saber/shield elbow articulation; preserve all eight original frames and timing exactly.
- move_v1: first32-frame complete reciprocal gait, with both grips and the blade clear of the legs.
- attack_v1: preserve only ready-to-windup0,28-35 and contact-to-ready92-108. Full attack is rejected because42-52 lose/shorten the blade and create a crescent. attack_cut_v2 uses raised/contact endpoints and a controlled rigid-blade cut. Its selected4-44 interval retains the blade through the forward-facing foreshortening; no crescent or detached trail. Fixed-anchor joins match the retained windup and recovery.
- defend_v1: knees widen into a brace, buckler lifts toward the mask and holds; complete saber remains outside the knees.
- cast_v1: rejected for blue-to-green background drift through the active gesture, including low-chroma intervals unsafe for the foreground-preserving key. cast_v2 adds an original raised-saber salute guide and constant-blue instruction.
- hit_v1: backward torso/head recoil and coherent recovery. The rotated buckler exposes its brown inner face; both grips remain intact.
- death_v1: knee buckle, one-knee landing, sideways loss of support, brief fall, shoulder/hip contact and settled corpse. Saber and buckler land flat. Long kneeling and corpse holds are trimmed.

Original art, videos, latents, prompts, guides and provenance are retained, including rejected takes. Unused matte frames can be regenerated from the lossless originals; temporary previews, check outputs and verified ComfyUI duplicates are disposable after review.

## Published actions and verification

| Action | Source | Frames | Frame duration |
|---|---|---:|---:|
| Move | move_v1:0-31 | 32 | 40 ms |
| Attack | attack_v1 anticipation/recovery + attack_cut_v2 cut | 39 | 35 ms |
| Defend | defend_v1 | 21 | 42 ms |
| Support | cast_v2 | 28 | 50 ms |
| Hit | hit_v1 | 28 | 40 ms |
| Death | death_v1 | 34 | 45 ms |

Attack contact is selected index29; support peak index14. Defense holds its final brace and dead uses the final grounded death frame. Durations deliberately trim/accelerate the original video for gameplay; exact selections and joins are recorded in delivery.json and per-take selection.json.

cast_v2 retains blue anticipation0,21-34 and uniform-green recovery51-63. Reviewed extraction ranges0-44 and50-68 preserve source geometry and use protected foreground chroma20, corner spread<=10 and separation>=80. Unsafe or redundant background transitions remain excluded; no automatic arbitrary-color fallback is used.

Candidate254 and published268 focused checks passed. Verified all182 selected source-frame pixels/anchors, timing/contact/held poses, provenance hashes and candidate-to-live per-clip pixels; all other231 creature entries remain unchanged. Original8-frame idle at240ms and overworld PNG remain exact. Atlas3960x3796,60,128,640 RGBA bytes, fits4096 bound. Existing certificate-store and GLES3 MSAA warnings are non-failing. No continuous playback, manual playtest, Linux validation or full-suite claim.
