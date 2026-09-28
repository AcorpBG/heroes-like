# Hearthbow Carriers H3 animation

Seven dedicated actions are published; the original articulated eight-frame battle/overworld idle is preserved exactly. 187 selected original H3 frames, fixed0.5 extraction scale and ground anchor[480,490]. The packed runtime atlas is3600x4012.

| Action | Original frames | Frame time |
|---|---:|---:|
| move | 16 | 65ms |
| attack | 44 | 35ms |
| defend | 21 | 40ms |
| hit | 14 | 45ms |
| cast | 22 | 50ms |
| death | 30 | 50ms |
| ranged | 40 | 40ms |

Original reference: `art/animation/runtime/poses/unit_neutral_hearthbow_carriers.png`,512x256 cells with local anchor[256,244]. Identity: brown hood/leather, red cape, auburn hair, two arms/legs, one wooden bow in the left hand, quiver and belt lantern. Blue key with protected foreground chroma20 preserves the warm art.960x544,124frames at24fps,20steps, FL2VA int8 ConvRot/Qwen3VL32B NVFP4/VAE int8. Preserve sampled latent before unloading models and tiled decoding.

Selected source intervals and timing are recorded in each `selection.json`; `produce.py assemble` rebuilds the production handoff. Long static holds are shortened; no duplicated, reversed, interpolated or repainted poses are used. Melee includes a visible empty-hand shoulder flourish and bow shove. Hit selects only clean recoil/recovery; its generated incoming projectile and impact sparks25-29/31-39 are excluded. Ranged releases at source81; airborne-arrow frames82-83 are excluded because the game owns projectile presentation. Deathv2 adds the missing guided side-fall before the elbow gives way and the body/bow settle.

Rejected v1 melee/hit/death originals remain with named defects: invented arrow/shot and abrupt kneel-to-corpse transition. Deathv2 uses a documented original-pixel guide excluding the disconnected duplicate bow tip in legacy pose15. All original MP4s, lossless decoded videos, latents, guides, prompts, workflows, seeds, hashes and selected mattes are retained. Unused mattes and exact Comfy duplicates are rebuildable and cleaned.

Review: all124 chronological frames in each selected take, enlarged hands/bow/boots/alpha edges, gait seam, complete native128px phase overview and live battle/map-idle renders. Continuous video playback was unavailable; no continuous playback, manual game playtest, full-suite or Linux run is claimed.

Focused Windows checks:267 candidate and281 published assertions passed. Exact-pixel/anchor/timing comparison verified all187 H3 frames, the eight retained idle poses,196 candidate/live clip poses including corpse,77 selected provenance hashes, all231 other creature records, and byte-identical overworld catalog/strip. All10 immutable takes and25 original guide hashes verified. Existing certificate-store/MSAA diagnostics did not fail the focused checks.

This delivery advances the live roster to151 complete /81 remaining; the overall animation goal remains in progress.
