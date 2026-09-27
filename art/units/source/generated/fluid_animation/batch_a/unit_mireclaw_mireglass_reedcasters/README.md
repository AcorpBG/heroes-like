# Mireglass Reedcasters H3 animation

Published 222 original MiniMax H3 frames across seven dedicated actions. The original eight-frame, 240 ms idle and overworld strip remain exact.

| Action | Original frames | Frame duration | Contact index |
|---|---:|---:|---:|
| move | 33 | 55 ms | - |
| attack | 38 | 40 ms | 17 |
| ranged | 42 | 40 ms | 19 |
| defend | 17 | 65 ms | - |
| cast | 32 | 55 ms | 12 |
| hit | 31 | 35 ms | - |
| death | 29 | 50 ms | - |

## Review and corrections

The olive leaf mantle, pointed hood, two hands/legs, rigid reedwood staff, three corded green glass globes and separate belt bottle remain readable. Walking alternates foot support; melee draws in and shoves the staff forward; ranged lifts, aims, pulses and recovers; casting extends the staff through the green-lit invocation; defense braces into a held guard; hit recoils and returns; death falls onto the side and grounds the released staff/globes. Dead uses the final collapse frame.

Attack_v1 is rejected for changing background colors, an emitted trail and top-edge clipping. Attack_v2 uses a compact two-handed shove and a blue plate. Ranged_v1 is rejected for background color pulses. Ranged_v2 retains the clean aim and recovery, excluding frames 63-79 where an excessive swing stretches a globe. The fixed-anchor 62-to-80 join was inspected enlarged and at native size: torso/staff retain their extended position while the globes make a small settling displacement. No deformed globe frames are published.

Native review exposed a legacy scale mismatch: the original ready painting is 211 px high, while the accepted later idle paintings are 174-178 px. Every new action receives the same 0.83 anatomical correction, giving a 0.5395 source extraction scale. This matches idle body size without per-pose resizing; guide/config originals remain unchanged.

## Rebuild and provenance

`delivery.json` and each `selection.json` define the original indices, timings and contact moments. Run `produce.py assemble` to rebuild the combined handoff with its uniform runtime correction. Publish the seven selected actions with the shared publisher and preserve reviewed idle. Restore the original accepted map record/PNG after the publisher refreshes that route automatically.

Each of the nine takes retains original FFV1 video, MP4, sampler latent, exact prompt, seed, submitted workflows, guides/hashes, source timestamps and matte recipe, including rejected footage. Extraction measures flat magenta (move/defend) or blue (other accepted actions) plates with corner spread<=10 and chroma separation>=80. All valid opaque components and thin prop cords are retained. No interpolation, reversed frames or painted repairs are used. Redundant holds are shortened with explicit original-frame selections.

## Validation

All chronological source phases, enlarged anatomy/grips/edges, selected joins and every selected Godot phase at native 128 px battle reference scale were inspected. The imported battle and map idle were also inspected. Candidate 757 / live 771 focused checks pass. All 222 source frames, anchors, timings, candidate/live pixels and provenance hashes match. The other 231 creature records, all map records and original idle pixels remain unchanged. Runtime atlas 3368x2492 uses 33,572,224 RGBA bytes.

Continuous video playback, manual gameplay, Linux execution and the full repository test suite were not performed. This completes one creature; the overall animation goal remains active.
