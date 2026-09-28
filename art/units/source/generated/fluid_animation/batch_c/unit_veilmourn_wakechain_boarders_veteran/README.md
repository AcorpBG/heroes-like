# Gravetide Anchors H3 production

Published seven dedicated actions for `unit_veilmourn_wakechain_boarders_veteran`, preserving the ivory hood and torn tabard, navy-black coat, brass ship-wheel buckle, two arms and legs, and one linked-chain iron grapnel.

| Action | Selected original frames | Frame duration | Contact index |
|---|---:|---:|---:|
| idle | 31 | 110 ms | - |
| move | 20 | 75 ms | - |
| attack | 25 | 60 ms | 16 |
| hit | 15 | 35 ms | - |
| defend | 16 | 45 ms | - |
| cast | 18 | 70 ms | 9 |
| death | 24 | 65 ms | - |

The final death original supplies the persistent corpse. Overworld idle uses the same 31 selected originals. The battle atlas is 2752 x 3260, 35,886,080 uncompressed RGBA bytes.

## Generation and review

Local MiniMax H3 ordinary int8 produced 124 original frames per take at 24 fps, using 20 res_multistep/simple steps and no Turbo LoRA. The sampled latent was preserved before releasing the encoder/denoiser and decoding with the tiled VAE. Lossless FFV1 decoded RGB pixels were verified against the ComfyUI originals. The baseline canvas is 960 x 640; the corrected melee source uses 1152 x 832 to retain grapnel swing clearance above and below the character. Its anatomical anchor is translated with the added padding; body size is unchanged. Extraction uses a fixed 0.5 scale without per-frame normalization, interpolation, reverse frames or geometry warping.

Attack v1 is rejected and preserved: its grapnel reached the bottom edge in original 20 and the top edge in original 46, and it added an unwanted impact flash. Attack v2 replaces it with increased canvas clearance. The retained v1 selection records an intermediate review only and is excluded from the delivery.

Built-in image generation supplied guard and physical boarding-signal guides. Their original masters, exact prompts and source references are retained in `keys/`. Original battle poses supply the other guides, with exact crop and anchor lineage. Every generated original, including unused footage, remains preserved with its model settings, seed, latent, prompt and source hashes.

Autonomously reviewed all 992 chronological H3 originals across eight takes, enlarged action details, and every selected native battle phase. Accepted seven distinct actions with visible forearm/grapnel idle, reciprocal grounded gait, connected-chain melee windup/contact/recovery, recovering recoil, held braced guard, physical raised-chain support and grounded collapse. Rejected attack v1 for canvas clipping; the enlarged-canvas v2 preserves body scale and full weapon clearance. Excluded v2 originals 40-41 where the hanging chain loop briefly separates, retaining a short overhead-to-contact transition. All 149 selected originals have safe opaque canvas margins. Trimmed stationary holds without reversed/interpolated or duplicate padding. Review used chronological originals and native phase rendering; no continuous playback, manual game playtest or Linux validation is claimed.

**attack_h3_v1:** Reviewed all 124 chronological originals and enlarged grips, chain and swing clearance. One attached grapnel swings back, passes overhead, extends to contact and retracts to ready. Excluded generated impact-flash frames 49-51 and trimmed near-stationary windup/contact holds. Selected 26 original phases retimed to a readable 1.56-second action; contact is original 52 at selected index 17. No painted repair, reversal, interpolation or duplicate padding.

**attack_h3_v2:** Reviewed all 124 chronological originals and enlarged swing/grip details. Increased canvas retains the whole grapnel above the hood and around the body, without changing anatomical scale. Selected connected-chain windup, forward strike and full recovery; excluded originals 40-41 where the hanging chain loop briefly separates, and trimmed stationary holds. The short 39-to-42 source interval retains overhead-to-contact motion. Twenty-five original frames over 1.5 seconds; contact at original 42, selected index 16. No effect flash, duplicate padding, reversal, interpolation or painted reconstruction.

**cast_h3_v1:** Reviewed all 124 original phases and enlarged hands, chain and hood edges. Near arm raises the connected chain above the hood for a physical boarding signal while the far hand retains the single grapnel; the arm then lowers naturally to ready. No invented magic or extra equipment. Trimmed long initial and raised-signal holds to 18 original phases over 1.26 seconds; support contact is original 48, selected index 9.

**death_h3_v1:** Reviewed all 124 chronological originals and enlarged collapse anatomy. Knees yield, body folds forward, arms lower the linked grapnel, and both body and equipment settle onto the ground. Trimmed the initial unchanged ready hold and final long corpse hold; retained 24 original collapse and cloth-settling phases over 1.56 seconds. Final original 84 provides a grounded persistent corpse. No duplicated, reversed or interpolated frames.

**defend_h3_v1:** All 124 originals and enlarged hand/weapon details reviewed. The creature widens its footing, raises the single linked grapnel, and bends into a distinct low held guard. Two arms and stable grips persist throughout. Selected the 16 original transition phases over 720 ms and omitted the long static terminal hold; the last authored guard is held by the runtime.

**hit_h3_v1:** All 124 originals reviewed with enlarged body and equipment inspection. Clear torso recoil, knee flexion and lowered arms followed by a return to ready; one linked grapnel and two hands persist. Removed long unchanged recoil hold and selected the actual transition/recovery over 525 ms. Fifteen original phases, no reversal or interpolation.

**idle_h3_v1:** Reviewed all 124 original frames chronologically and enlarged equipment/limb edges on light and dark backgrounds. Both forearms visibly lift the retained grapnel and linked chain, then lower into matching ready endpoints; two planted boots remain registered. Original flukes and chain remain connected. Selected every fourth original for a relaxed 3.41-second loop, without reversed, interpolated or duplicate padding frames.

**move_h3_v1:** Reviewed all 124 chronological originals and enlarged reciprocal foot contacts. Selected a complete gait cycle with alternating near/far boots, stable two-handed chain and grapnel grip, and matching passing phases around frames 10 and 50. Twenty original frames; no reversed, interpolated or duplicate padding.

## Validation and rebuild

Focused Windows Godot checks passed: candidate 516, published 520. All 149 selected source frames retain their exact original pixels and anatomical anchors in the live atlas. All 150 live clip poses including the corpse match the candidate. The 31 map-idle frames match, 84 provenance hashes and 8 takes/17 guide references verify, and the other 231 unit/map entries remain unchanged. The atlas fits the 4096px limit. No full suite, continuous playback review, manual game playtest or Linux validation is claimed. Roster: 159/232 complete, 73 remaining.

Rebuild using `produce.py`, `stage_video.py`, `run_batch.py`, retained configs/selections and `delivery.json`. Lossless originals rebuild unselected mattes. Temporary review/test exports and verified duplicate ComfyUI outputs are disposable; source masters, original videos/latents, selected RGBA frames, prompts, lineage and caches are retained.
