# Keelbreaker Lancers H3 production

Published eight dedicated actions for `unit_veilmourn_undertow_harpooners_veteran`. Preserve the dark teal hood and naval coat, dark iron armor, ivory net bundles, fixed bronze back winch, two arms and legs, and one compact forked harpoon launcher.

| Action | Selected originals | Frame duration | Contact index |
|---|---:|---:|---:|
| idle | 31 | 110 ms | - |
| move | 24 | 50 ms | - |
| attack | 26 | 50 ms | 12 |
| ranged | 26 | 55 ms | 14 |
| hit | 16 | 35 ms | - |
| defend | 15 | 45 ms | - |
| cast | 21 | 65 ms | 9 |
| death | 15 | 70 ms | - |

The final death original supplies the persistent corpse. Overworld idle uses the same 31 selected originals. The battle atlas is 2880 x 3420, 39,398,400 uncompressed RGBA bytes.

## Generation and review

Local MiniMax H3 ordinary int8 generated 124 originals per take at 24 fps with 20 res_multistep/simple steps and no Turbo LoRA. Sampling latents are preserved before releasing encoder/denoiser models and tiled VAE decoding. Every FFV1 original is verified against decoded RGB hashes. The 960 x 704 guide canvas uses anatomical anchor [448, 628] and fixed 0.5 extraction scale; no per-pose normalization, reversed footage, interpolation or invented geometry.

Original battle poses supply ready, raised weapon, ranged, recoil and corpse guides. Built-in image generation supplies melee, braced guard and physical rally-signal guides. Initial generated v1 guides were rejected for oversized weapons; corrected v2 masters retain the compact launcher. Both versions, exact prompts, source crop lineage and generation metadata are preserved.

Autonomously reviewed all 1,240 chronological H3 originals across ten takes, enlarged equipment/anatomy details, loop boundaries and every selected native battle phase. Accepted eight distinct actions: articulated forearm/launcher idle, reciprocal gait, continuous short bayonet thrust, aimed ranged release with recoil/recovery, hit recovery, held braced guard, physical raised-fist support and grounded collapse/corpse. Rejected attack v1 for abrupt pose switching and ranged v1 for a generated glowing projectile. Excluded brief effect-contaminated intervals in hit v1 and ranged v2; selected footage retains clean anatomy and equipment with safe opaque canvas margins. All 174 selected poses are original frames at one fixed anatomical scale, without reversed/interpolated frames or duplicate padding. Review used chronological originals and native phase rendering; no continuous playback, manual game playtest or Linux validation is claimed.

**attack_h3_v1 rejected:** Nearly unchanged ready footage jumps abruptly between originals 34-35 into a wide lunge, then snaps back at 92-93. The generated guide is usable identity art but this motion is not fluid. Replace the take using the closer original extension pose and a continuous action instruction.

**attack_h3_v2:** Reviewed all 124 chronological originals and enlarged grips, shoulders, knees and tip clearance. The closer original extension guide produces continuous arm/torso motion: draw the shaft inward, bend into preparation, extend both arms into a short bayonet thrust, then draw back and recover to ready. It avoids v1's abrupt wide-lunge pose changes and contains no projectile or flash. Selected 26 original phases over 1.3 seconds; contact is original 56, selected index 12. No reversed footage, duplicate padding, interpolation or per-frame scaling.

**cast_h3_v1:** Reviewed all 124 chronological originals and enlarged hand/equipment transitions. Near hand releases the rear grip, folds the arm and raises one closed fist as a physical boarding signal; far hand supports the launcher at the hips. The raised arm then lowers and reacquires its original grip. Exactly two hands, no magic or additional equipment. Selected 21 original phases over 1.365 seconds and trimmed long static holds; support contact at original 27, selected index 9.

**death_h3_v1:** Reviewed all 124 chronological originals and enlarged collapse anatomy and launcher edges. Knees buckle under the coat, the torso tips onto its side and the retained launcher lowers with the arms to the ground. Selected the continuous 43-54 collapse plus initial ready and cloth/weapon settling phases; trimmed long unchanged ready and corpse holds. Fifteen originals over 1.05 seconds; original 60 supplies the grounded persistent corpse. No shrinking, dissolving, reverse frames or duplicate padding.

**defend_h3_v1:** Reviewed all 124 chronological originals and enlarged hands, launcher and leg registration. The lancer widens its footing, lowers then raises the launcher across the chest, and settles into a bent-knee held guard. Two arms, stable grips and the attached winch/net bundles persist. Selected 15 original transition phases over 675 ms, trimming the long terminal hold; runtime holds original 64. No reversed frames, interpolation or duplicate padding.

**hit_h3_v1:** Reviewed all 124 chronological originals and enlarged grips, recoil and recovery. Excluded originals 12-17 containing an unwanted flash and trimmed long stationary holds. The brief 11-to-18 impact transition leads into retained backward torso/arm recoil, bent supporting knee and full recovery to ready. Sixteen original poses over 560 ms; no flash in selected footage, reversed frames, duplicate padding or painted reconstruction.

**idle_h3_v1:** Reviewed all 124 chronological originals and enlarged grips and edges on light/dark backgrounds. Both forearms lift and lower the single forked harpoon launcher; two boots stay planted and the coat and net bundles follow subtly. Selected every fourth original for a 3.41-second ready loop with matching endpoints. No duplicate padding, reverse frames, interpolation or per-pose scaling.

**move_h3_v1:** Reviewed all 124 chronological originals and enlarged foot contacts, grips and equipment. Selected the first complete 24-original reciprocal gait: near boot lifts and passes forward while the far leg supports, then weight and leg positions exchange back to ready. One launcher stays in both hands and the fixed back winch stays attached. Retimed one complete cycle to 1.2 seconds without reversed or duplicate padding frames.

**ranged_h3_v1 rejected:** Originals 45-52 add a glowing projectile/flash. Removing them loses the useful recoil interval. Preserve the take but replace it with a dedicated unpowered mechanical operation and recoil guide.

**ranged_h3_v2:** Reviewed all 124 chronological originals and enlarged aiming, grip and recoil details. The launcher raises, levels into aim, kicks back through a pronounced torso/arm recoil, then returns to ready. Excluded originals 48-51 with an unwanted flash and stray effect fragments, retaining a sharp 47-to-52 release transition and the clean recoil/recovery. Selected 26 originals over 1.43 seconds; release contact at original 52, selected index 14. The runtime supplies the projectile separately. No effect pixels in the selection, reversed frames, duplicate padding or painted repair.

## Validation and rebuild

Focused Windows Godot checks passed: candidate 599, live 603. All 174 selected source poses match exact live pixels and anatomical anchors; all 175 live poses including the corpse match the candidate. The map idle matches, 95 provenance hashes and 10 takes/22 guide references verify, and all other 231 unit/map entries are unchanged. Atlas dimensions fit the 4096 limit. No full suite, continuous playback, manual game playtest or Linux validation is claimed. Roster: 160/232 complete, 72 remaining.

Rebuild with `produce.py`, `stage_video.py`, `run_batch.py`, configs, selections and `delivery.json`. Retained lossless originals rebuild unused mattes. Temporary review/test exports and hash-verified duplicate ComfyUI outputs are disposable; preserve masters, original videos/latents, selected RGBA frames, prompts, lineage and caches.
