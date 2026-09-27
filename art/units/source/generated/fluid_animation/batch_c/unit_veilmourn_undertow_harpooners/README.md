# Undertow Harpooners video animation source

Seven dedicated MiniMax H3 battle actions are published with 221 selected original frames. The reviewed original eight-frame articulated idle at 240 ms and the overworld idle are preserved.

Identity: right-facing humanoid harpooner with ivory beaked mask, teal tricorn and armor, thin brass helmet twigs, ragged ivory/navy cloak, brass waist netting, pointed boots and violet hip lantern. Exactly two arms and two legs. One rigid brass/teal harpoon launcher with central rope drum, right rear trigger hand, left foregrip and one barbed point. Ranged discharge may leave an empty muzzle; the engine owns the flying projectile.

Every take preserves original guide crops/hashes, exact prompt, seed, sampling/decoding API workflows, sampler latent, original lossless video and decoded RGB hashes. Local FL2VA int8 / Qwen3-VL 32B NVFP4 / int8 VAE; 960 x 544, 124 frames at 24 fps, 20 res_multistep/simple steps. Large encoder/denoiser models unload before tiled VAE decode (256/64 spatial, 16/4 temporal). Use uniform green because teal armor and violet glass must survive extraction. Scale0.65 and anchor[480,480] are fixed throughout; never normalize individual frames.

Exact frame selections and gameplay timing live in selection.json, and delivery.json records accepted clips or segmented joins. produce.py process/build/assemble rebuild extraction and delivery; stage_video.py preserves sampling separately from decoding and retains unsafe original footage for manual review rather than applying an automatic plate fallback.

Review uses every chronological original phase, enlarged details on light/dark backgrounds, fixed-anchor boundaries and native Godot renders. Continuous playback, a manual playtest, Linux validation and the full repository suite are not claimed. Original videos, latents, guides and provenance remain even for rejected takes; temporary previews and verified duplicate outputs are disposable after review.

## Reviewed source decisions

- Original idle20-27 visibly articulates the arms and launcher, with cloak follow-through. Preserve its exact8 frames and240ms timing.
- move_v1: select first full reciprocal24-frame gait0-23; intact launcher, two-handed grip, complete boots and matching contact boundary.
- attack_v1:29-frame physical jab with contact at selected index13. Exclude41-51 unwanted shot/spark effects after the jab; source40-to52 joins the same lunged stance and intact harpoon before clean recovery. No source effect pixels are painted out.
- ranged_v1: retain the loaded aim through source39 and clean empty-muzzle recoil48,51-60. Exclude the discharge effects40-47 and detached ground fragments49-50. The full take is rejected because its later reload bends the point and produces loose arrows. A separate reload take starts with an explicitly empty muzzle; the runtime owns the flying projectile.
- defend_v1: select the first complete planted crouch0,8-26, keeping both grips and holding the final guard. The later redundant crouch is omitted.
- cast_v1: select the physical fist salute and regrip, with the left foregrip balancing the launcher. No magical action is introduced for this ranged physical creature; omit the long peak hold.
- hit_v1: select backward impact, free-arm recoil and regrip recovery. Exclude source26 for a briefly elongated muzzle and compress the long held recoil. Selected native Godot phases passed visual review.
- ranged_reload_v2: the empty muzzle loads one attached point along its rail, then lowers through horizontal to ready. Both grips remain stable. Its first pose matches ranged_v1 source60 at the fixed anatomical anchor; its last selected pose matches ready. The combined action contains 54 frames, with release at index13 and deliberate 45 ms aim/recoil plus 40 ms reload timing.
- death_v1: rejected. Source29-30 snaps into a kneel, source36 bends the muzzle and69-70 snaps into a smeared side fall. All original footage and provenance are preserved.
- death_v2: original ready/corpse endpoints only, with no timed intermediate guides. Gradual knee lowering, lateral loss of support and shoulder/hip landing; wrists rotate the launcher into its grounded final position. The barrel briefly foreshortens against the legs/cloak but retains the point. Select36 phases and trim long endpoint holds.

## Published actions and verification

| Action | Frames | Timing |
|---|---:|---|
| Move | 24 | 40 ms, looping |
| Melee | 29 | 45 ms, contact index 13 |
| Ranged | 54 | 24 x 45 ms + 30 x 40 ms, release index 13 |
| Defend | 20 | 45 ms, hold final guard |
| Support | 26 | 45 ms, peak index 9 |
| Hit | 32 | 40 ms |
| Death | 36 | 45 ms, persist final corpse |

All 221 selected frames were inspected in the native 128px Godot overview after chronological source, enlarged anatomy/alpha and fixed-anchor join review. Candidate 754 and imported-live 768 focused checks passed. Verified exact source pixels/anchors, clip timing/contact/loop/held states, provenance hashes and candidate-to-live per-clip pixels. Atlas 3456 x 3072, 42,467,328 RGBA bytes, remains below the 4096 texture bound. All other 231 creature records are unchanged. Live roster: 141 complete, 91 remaining; the overall production goal remains active.

The original eight-frame idle and its 240 ms timing are exact. Retain the original overworld PNG and original-source record in retained_overworld.json. Generic battle-atlas extraction normalized one invisible RGB pixel with alpha zero; all visible pixels matched, but the original strip/record were restored to preserve exact bytes. Rebuilding map idle with pack_overworld_creature_idle.extract and move_v1/accepted_baseline.json reproduces its recorded SHA-256 exactly. Battle-only publication must retain that original map result rather than replace its source with the new battle atlas.

Existing Windows certificate-store and GLES3 MSAA messages did not fail the checks. No continuous playback, manual playtest, Linux validation or full repository suite was claimed. Original videos, latents, guides, failed takes and all provenance are retained; temporary previews/check outputs, unused reproducible mattes and hash-verified ComfyUI duplicates are cleaned after review.
