# Pale Meridian Pilots H3 production

Published seven dedicated actions for `unit_veilmourn_wakeglass_navigators_veteran`. Preserve two arms and two booted legs, silver mask and hood, tattered grey/navy robes, near-hand rigid crescent staff with suspended weights, and separate far-hand brass-rimmed glass navigation compass.

| Action | Original frames | Duration per frame | Contact index |
|---|---:|---|---:|
| idle | 31 | 110 ms | - |
| move | 24 | 55 ms | - |
| attack | 29 | 50 ms; contact held 100 ms | 12 |
| hit | 19 | 40 ms | - |
| defend | 15 | 50 ms | - |
| cast/support | 21 | 65 ms | 9 |
| death | 27 | 55 ms | - |

The final death frame supplies the persistent corpse. Overworld idle uses the same 31 originals. The atlas is 4032 x 4088 (65,931,264 uncompressed RGBA bytes), within the 4096 texture limit.

## Generation and review

Local MiniMax H3 ordinary int8, 124 original frames per take at 24 fps, 20 res_multistep/simple steps, no Turbo LoRA. Original sampler latents are preserved before models are unloaded and tiled VAE decoding runs. The 960 x 704 guide canvas has anchor [448, 628] and fixed 0.5 extraction scale. No per-frame normalization, reversed footage, interpolation or duplicate padding.

Original battle poses supply identity and ready/attack/recoil/corpse guides. Built-in image generation supplies braced guard, raised compass, waist-level compass and kneeling collapse key poses. Masters, prompts, lineage, videos, sampler latents and failed takes are retained.

Autonomously reviewed all 1,240 chronological original frames, enlarged anatomy/equipment, loop boundaries and every selected native battle phase. The idle visibly lowers/tilts the compass then returns it to the chest; the support action raises it to eye level. The walk alternates supporting legs. The attack draws in, extends the staff diagonally and recovers; guard widens the stance and tucks the compass. Recoil recovers to ready. Death folds the knees and robe, tips to the side and settles as a grounded corpse.

Rejected idle v1 for insufficient arm articulation, attack v1 for staff/crescent deformation during the overhead wrist roll, and death v1 for a truncated lower robe that appeared to sink before falling. Their corrected v2 takes are selected. Hit originals 25-26 and death v2 original 61 are excluded for transient hanging-weight/crescent distortion; neighboring clean originals retain the impact transitions. Selections record all exact indices and timings.

The initial focused shell check skipped the 50 ms attack contact pose. Holding that original pose for 100 ms makes impact readable; all remaining attack frames stay at 50 ms, for a 1.5-second action. The revised candidate and installed clip both show every attack/recovery phase in the focused shell check. No validator exemptions or runtime changes were made.

## Validation and rebuild

Focused Windows Godot checks: candidate 249 passed; installed 253 passed. Exact pixels and anchors verified for all 166 selected source poses and 167 candidate/live poses including the corpse. Overworld strip pixels match the extracted accepted idle. All 89 provenance hashes, 22 guides and 1,240 lossless original RGB frames verify; other 231 unit/map entries remain unchanged. Native battle and overworld render outputs reviewed. No continuous playback, manual game playtest, Linux validation or full suite is claimed. Roster: 161/232 complete, 71 remaining.

Rebuild with `produce.py`, `stage_video.py`, `run_batch.py`, per-take configs/selections and `delivery.json`. Retained lossless originals rebuild unselected mattes. Temporary review/test outputs and verified duplicate ComfyUI outputs are disposable; preserve original art, selected RGBA frames, provenance, videos/latents and caches.
