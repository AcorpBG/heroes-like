# Mourning Lanterns video animation source

Seven dedicated MiniMax H3 actions are published with 209 selected original frames. The original articulated eight-frame idle at 240 ms and overworld idle are preserved.

Identity: right-facing human lantern bearer in muted grey-green cloth, charcoal coat and brown leather. Two hands retain one upright staff with two hanging amber lanterns and a separate brass hand-lantern. Preserve the silver mirror plates, cloth strips, boot contacts and complete equipment.

Each take retains its exact prompt, source-pose guide crops/hashes, seed, API workflows, original sampler latent, lossless decoded video, original RGB hashes and reproducible matte settings. Local FL2VA int8 / Qwen3-VL 32B NVFP4 / int8 VAE; 960 x 544, 124 frames at 24 fps, 20 res_multistep/simple steps. Large models unload before tiled VAE decoding (256/64 spatial, 16/4 temporal). One extraction scale 0.65 and ground anchor [480, 480] apply throughout. No frame-wise size normalization, invented inbetweens, reverse frames or duplicate padding.

`selection.json` records exact observed source frames and deliberate gameplay timing. `produce.py process`, `build` and `assemble` rebuild matte frames and delivery. `stage_video.py` preserves sampling separately from decoding. Temporary review images and verified duplicate decoded frames are disposable; original videos, art, latents, prompts, guides and provenance remain.

Review uses all chronological source phases, enlarged anatomy and light/dark edges, fixed-anchor boundaries and focused native Godot renders. Continuous playback, a manual game playtest, Linux validation and the full repository suite are not claimed.

## Published actions

| Action | Original takes | Frames | Frame duration |
|---|---|---:|---:|
| Move | move_v2, second cycle | 28 | 40 ms |
| Melee | attack_push_v2 approach + attack_v1 recovery | 39 | 40 ms |
| Ranged | ranged_v1 | 25 | 50 ms |
| Defend | defend_v2 | 17 | 45 ms |
| Support | cast_v1 | 30 | 55 ms |
| Hit | hit_v1 | 30 | 35 ms |
| Death | death_v2 | 40 | 45 ms |

Melee contact is selected index25, ranged release index11, support peak index15. Defense holds its final crouch. Dead uses the final grounded death frame.

## Corrections and exclusions

- move_v1: rejected backward-reading boot extensions and unwanted bright cloth changes. move_v2 uses original opposed contacts, selecting second-cycle68-122; the first cycle has stray ground specks and is excluded.
- attack_v1: projectile31-39 and altered lamp during initial thrust are excluded. Only clean contact/recovery54-68 is used. attack_push_v2 changes control to ready/contact endpoints, preserving the lamp through a physical push. Its final contact matches the selected first-take recovery.
- ranged_v1: omit32-40, which add an unwanted detached projectile during held aim. Source31-to41 retains the extended arm and planted feet while settling lamp orientation. Runtime supplies the actual projectile; no effect pixels are painted out.
- defend_v1: rejected black background8-122 covering the movement. defend_v2 has a uniform green interval. Explicit reviewed key ranges extract original magenta ready0/3 and green9-28, with protected foreground chroma20, corner spread<=10 and separation>=80. Color-transition and redundant held intervals are excluded. Enlarged edges preserve the cloth, three lamps, silver plates and staff.
- death_v1: rejected bending staff66-75 and changing backdrop. death_v2 adds original side-fall pose17 and a rigid-shaft instruction; the body and complete staff settle onto the ground. No generated inbetweens or per-frame resizing are used.

## Verification

All chronological original phases and selected enlarged anatomy/equipment/edges were reviewed, including fixed-anchor loop/contact joins. Every selected phase was inspected in the native128px Godot overview; published battle/map previews were also inspected. Candidate checks:283 passed; published checks:297 passed. Verified all209 original frame pixels/anchors, timing/contact/held poses, provenance, candidate-to-live per-clip pixels, exact original idle preservation, unchanged map PNG and all other231 creature entries unchanged. Final atlas3808x3380 (51,484,160 RGBA bytes), within4096 limit.

Continuous playback, manual playtesting, Linux checks and the full suite were not performed. Existing Godot certificate-store and GLES3 MSAA warnings did not fail the focused checks. Temporary previews, check profiles/logs, unused rebuildable mattes and hash-verified ComfyUI duplicate outputs are cleaned; original sources and caches remain.
