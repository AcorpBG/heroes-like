# Evergraft Colossus H3 production

Accepted and integrated seven battle actions, the final grounded corpse and matching overworld idle for `unit_thornwake_worldroot_bastion_veteran`. This melee guardian has no ranged attack. The roster animation goal remains in progress.

Original identity retains two braided-bark arms, two broad root legs, a stern trunk face, layered olive-green flowering canopy, two ivory shoulder lookout structures, amber shoulder seedpods and the central amber heart. Near arm is screen-left; far arm is screen-right in ready view. Guides derive from the original 512x256 pose cells, preserving anatomical scale. No weapon or new magical effect is introduced.

Local MiniMax H3 generated twelve preserved takes of 124 frames at 24 fps, using 20 res_multistep/simple steps, a 960x704 blue canvas, fixed ground anchor [448,628] and extraction scale 0.5. Each take retains guides, prompts, graphs, seeds, settings, sampled latent and verified lossless decoded originals. Sampling and tiled VAE decoding run separately to fit the GPU. Delivery uses 194 unique original frames across 206 action references; the corpse reuses the last death frame. The packed 3520x3496 atlas uses 49,223,680 uncompressed RGBA bytes without shrinking the creature.

| Action | Frames | Timing | Accepted motion |
|---|---:|---:|---|
| Idle | 31 | 110 ms/frame | Far forearm raises, wrist turns, fingers open and close, arm lowers; near arm flexes |
| Move | 26 | 65 ms/frame | Reciprocal root gait with opposing arms and matching contact loop |
| Attack | 31 | 55 ms/frame | Far-arm preparation, punch contact and recovery |
| Hit | 29 | 35 ms/frame | Clean pre-collapse recoil followed by matching recovery |
| Defend | 22 | 50 ms/frame | Two raised fists transition into a held guard |
| Support | 37 | 50 ms/frame | Physical open-palm rally and recovery |
| Death | 30 | 55 ms/frame | Recoil, folding root knees, torso fall and grounded side corpse |

`delivery.json`, per-take selections and `handoff.json` record source indices, timestamps, contacts and deliberate gameplay retiming. Hit combines death V1 frames 0-10 and 16 with hit V1 frames 72-104 every second frame. Both use the original recoil reference; enlarged fixed-anchor and native-scale review checked the join. These are forward original intervals, not reversed or interpolated frames. The hard cut in hit V1 is excluded.

Rejected originals remain preserved: idle V1 changes to a grey plate; attack V1 includes white fades, hard pose changes and an invented flash; hit V1 has a hard cut at frames 27/28; defense V1 changes to white; support V1 introduces a cyan/white backdrop glow; hit V2 has a black plate intersecting bark. Corrected idle/attack/defense/support V2 preserve the blue background and coherent action. Hit V2 is wholly excluded; only the explicitly selected recovery interval of hit V1 is used.

Review covered every chronological original frame, enlarged anatomy and keyed edges on light/dark backgrounds, loop/recoil joins, the complete native 128px battle overview and live battle/map renders. This is frame-sequence and native-render review, not continuous-video playback or a manual game playtest. Focused Windows checks passed: 61 partial candidate, 696 complete candidate and 700 live checks. Original-pixel verification covered selected runtime frames, all 1,488 lossless RGB source frames, 21 guides, 78 provenance records, map-idle pixels, baseline preservation and unchanged entries for the other 231 units. No full suite or Linux execution is claimed.

Original sources and reproducible recipes are retained. Temporary review images, logs, isolated profiles, unused reproducible mattes and verified ComfyUI duplicates are disposable after delivery verification; caches are preserved.
