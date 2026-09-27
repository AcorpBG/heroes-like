# Cinderseal Bombardiers H3 animation

Published 227 original MiniMax H3 frames across seven dedicated actions. The original accepted eight-frame, 240 ms idle and overworld strip remain byte-exact.

| Action | Original frames | Frame duration | Contact |
|---|---:|---:|---:|
| move | 26 | 65 ms | - |
| ranged | 34 | 45 ms | 13 |
| defend | 18 | 50 ms | - |
| cast | 31 | 45 ms | 14 |
| death | 34 | 45 ms | - |
| attack | 52 | 40 ms | 34 |
| hit | 32 | 35 ms | - |

## Review and corrections

Original red hood, red/gold coat, two arms/legs, right shoulder cannon and separate left-hand igniter remain consistent. Walking alternates support legs. Support raises and lowers the igniter in a physical readiness signal. Death lowers onto the knees, tips onto the side and leaves both props grounded; dead uses its last frame.

Melee joins the valid attack_v1 preparation/recovery around attack_extension_v2. The original first take snapped into full extension. The correction adds elbow lift and wrist rotation before the rapid thrust; its brief foreshortened frame 90 resolves the same baton at 91. Fixed-scale joins were inspected.

Ranged_v1 emitted unwanted effects; ranged_v2 supplies clean aim, shoulder recoil and recovery with the muzzle dark. Defend_v1 and v2 cut between guide poses. Defend_v3 removes middle conditioning and uses a shallower endpoint (reviewed death_v1 frame 48, guide only) to produce a continuous dedicated crouch.

Hit_v1 and the opening of hit_v2 emitted unwanted effects. A separately conditioned hit_recoil_v3 supplies the initial response; only the clean reviewed hit_v2 recovery is used afterward. Original failed footage remains preserved and is excluded from delivery.

## Rebuild and provenance

`delivery.json` defines the selected source intervals, contact indices and timing. Run `produce.py assemble` to reconstruct the combined handoff; the shared publisher packs selected clips while preserving reviewed idle. The publisher refreshes map strips automatically, so retain the original accepted map record/PNG when rebuilding this idle-preserving delivery. No interpolated, reversed or painted replacement frames are used. Long generated holds are shortened through explicit source-index selection.

Every take retains its original FFV1 video, preview MP4, sampler latent, prompts, seed, submitted graphs, guide hashes, history, frame timestamps and matte recipe. Sources use one fixed 0.65 extraction scale and ground anchor [480,480]. The flat green plate is measured, with corner spread<=10 and foreground chroma protection 20. No quality threshold was loosened for failed takes.

## Validation

Reviewed all chronological original phases, enlarged grip/anatomy/alpha details, fixed-anchor joins and offscreen Godot phases at native battle scale. Focused candidate (307 checks) and live (321 checks) pass; source pixels/anchors/timing and provenance hashes match publication; all other 231 creature entries, all map records and the original idle pixels remain unchanged. Continuous video playback, a manual playtest, Linux execution and the full repository suite were not performed.

Runtime texture RGBA allocation: 62,908,160 bytes.
