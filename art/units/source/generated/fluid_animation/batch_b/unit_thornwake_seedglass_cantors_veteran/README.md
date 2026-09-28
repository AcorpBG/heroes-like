# Blossomchoir Cantors H3 animation delivery

Completed eight dedicated actions for `unit_thornwake_seedglass_cantors_veteran`. The 234 selected original video frames replace the sparse baseline poses and reused movement/support/defense routes. Battle and overworld use the original body scale and ground anchors. The previous atlas and metadata remain in `art/animation/source/fluid/unit_thornwake_seedglass_cantors_veteran/`.

| Action | Selected original frames | Runtime duration | Motion |
|---|---:|---:|---|
| Idle / overworld | 31 | 3410 ms loop | Near wrist/forearm plucks and raises across the lyre, then returns |
| Move | 24 | 1008 ms loop | One reciprocal root-foot contact/passing cycle |
| Melee | 31 | 1600 ms | Drawn-back palm strike, contact and recovery |
| Ranged | 35 | 1800 ms | Lyre strum and forward release, then recovery |
| Hit | 25 | 920 ms | Backward shoulder recoil and upright recovery |
| Defense | 22 | 1100 ms, held | Lyre tucked in, open palm guarding, feet widened |
| Support | 31 | 1910 ms | Near arm rises above shoulder into invocation and returns |
| Death | 35 | 1750 ms, final corpse held | Kneel, sideways fall and grounded body/lyre |

Two bark arms, two root feet, pale face, layered leaf robe, blossom mantle, hanging seedpods, back flower pipes and the single wooden lyre are retained. The far hand supports the lyre while the near hand articulates. Fast strikes and the fall retain dense consecutive originals. Retiming shortens long generated holds; exact source indices, times, anchors and runtime holds are in each selection and the assembled handoff. No interpolated, reversed or duplicated frames were used to inflate action coverage.

## Corrections and exclusions

- `support_guard_v1.png` had a third low plucking arm and was rejected. The built-in image-tool correction `support_guard_v2.png` removes that entire extra arm and supplies the two-hand guard/invocation guides. Both masters, exact prompts and generation provenance remain.
- Move V1 changes its background from blue to green and back. Only the reviewed stable green interval 14-110 is extracted; the complete gait uses originals 24-47. Strict corner spread, separation and alpha thresholds remain unchanged, with a reviewed protected foliage chroma band of 20. Changing-background intervals are excluded.
- Cast V1 changes from blue to lime-green on 25-47 and 73-96. A reviewed interval-specific matte still left color contamination at fingers, leaves and lyre gaps. It is rejected, with originals and its attempted extraction recipe preserved. Cast V2 uses the same approved guides, a new seed and a constant-blue instruction; the replacement retains a clean blue plate throughout.

## Source and reproduction

Local MiniMax H3 ordinary int8 with Qwen32b NVFP4 and the int8 video VAE generated 124 frames at 24 fps per take, using 20 `res_multistep` / `simple` steps. The canvas is 960x704, anatomical anchor [448,628], and extraction scale 0.5. The sampler latent is saved before unloading the encoder/denoiser; tiled VAE decode runs separately. Model/settings provenance is in `runtime_profile.json` and the per-take graphs/history. FFV1, MP4, latent, reference guides and prompts remain, including rejected material.

`produce.py process <take>` rebuilds mattes, `review` rebuilds chronological previews, and `build` reconstructs selected handoffs. `produce.py assemble` combines the eight takes listed in `delivery.json`. `run_batch.py` reuses recorded job IDs and preserved samples instead of duplicating generation. Only the selected source mattes are retained after cleanup; all others are reproducible from preserved lossless originals.

## Review and focused validation

Reviewed complete chronological originals, enlarged articulation/equipment/alpha boundaries, every selected phase at native 128 px battle reference height, the rendered battle contact scene and live overworld shader output. This is frame-sequence and rendered-phase review, not a claim of continuous video playback or a manual game playtest.

Windows Godot 4.6.2: 788 full candidate checks and 792 published-live checks passed. These cover authored holds, contact/projectile timing, Normal/Fast/reduced motion, actual battle-shell recovery, grounding, mirrored presentation and unchanged simulation/save state. The isolated import passed. The host still reports its existing certificate-store and unsupported GLES3 2D-MSAA messages; the focused checks have no failures. No Linux execution or full repository suite was run.

Verification matched all 234 handoff frames and 235 runtime clip references (including the persistent corpse) between source, candidate and live atlases. All 231 other unit rows and map entries are unchanged. The overworld strip matches published idle pixels. All 1116 decoded RGB originals across nine takes, 20 reference guides and 97 handoff provenance hashes were verified. The bounded atlas is 3196x3208 (41,011,072 decoded RGBA bytes).

The complete-roster goal remains active: live manifest core-action coverage is 163/232, leaving 69 without a complete accepted seven-core-action set. This count does not waive relevant ranged-action quality checks.
