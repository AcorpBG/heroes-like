# Foundry Saint H3 source

Six published MiniMax H3 actions contain151 original frames. The reviewed original eight-frame idle at260ms and overworld PNG remain exact.

| Action | Take | Frames | Frame ms |
|---|---|---:|---:|
| Movement | move_v2 |22|60|
| Melee | attack_v1 |34|40|
| Defense | defend_v1 |16|45|
| Support | cast_v1 |24|50|
| Hit | hit_v1 |21|35|
| Death | death_v1 |34|55|

Original identity: brass/steel humanoid living furnace, spiked rigid halo, white cloth and red seals, two armored legs and arms. Screen-right hand keeps its forging hammer; screen-left hand keeps tongs holding one orange billet. Preserve fixed anatomical scale and ground anchor.

Movement keeps a full alternating boot cycle0-42, trimming the second partial step and idle tail. Attack retains every rapid downswing phase30-36 and recovery78-88; source32 is contact. Defense folds into a chest guard held at the final frame. Support presents the billet with a hammer salute, then lowers both tools; peak source35. Hit begins in clean recoil at30 and returns to ready70: whole19-29 explosion/particle frames excluded, no pixels erased. Death retains every fall/tool-settling phase34-47, with cold grounded body and tools at65 used for persistent corpse. Each selection.json records exact chronological source IDs and timing.

The first green-background movement take changes its plate to black and was rejected by strict matte validation; its original sources are preserved. The blue replacement and remaining blue-background takes keep a uniform plate. Original videos, latents, guides, prompts, workflows, timestamps and hashes are retained, including the failed movement take. Unselected mattes and review outputs are rebuildable and removed after verification.

Recipe: local H3 FL2VA int8convrot, Qwen3VL32B NVFP4, VAEint8;960x544,124 frames at24fps,20 res_multistep/simple steps. Save sampling latent, release large models, tiled VAE decode256/64/16/4, collect FFV1 with all decoded RGB hashes verified. Fixed extraction scale0.6 and480,480 anchor; protected blue chroma20, strict uniform-corner checks, alpha8 regions retained when containing opaque128 pixels. See produce.py and stage_video.py, plus published source recipe under art/animation/source/fluid/unit_brasshollow_foundry_saint.

Review: all124 chronological source phases per take; all selected frames enlarged on light/dark backgrounds; fixed-anchor joins; all selected phases at native Godot128px scale and live battle/map routes. Windows Godot4.6.2 candidate217/live231 focused checks pass. All151 packed source-frame pixels/anchors, provenance hashes, original idle8, exact overworld PNG and231 unrelated catalog/map records verified. Atlas3840x3920 within4096, no rescaling to fit. No continuous playback, manual playtest, Linux execution or full-suite claim.
