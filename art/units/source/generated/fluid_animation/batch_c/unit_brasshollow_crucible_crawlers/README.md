# Crucible Crawlers H3 animation source

Published seven actions with 201 original MiniMax H3 video frames. Original eight-frame idle at 260 ms and overworld PNG remain exact.

| Action | Take | Frames | Frame ms |
|---|---|---:|---:|
| Move | move_v1 | 31 | 50 |
| Melee | attack_v2 | 25 | 45 |
| Ranged | ranged_v3 | 29 | 30 |
| Defend | defend_v1 | 29 | 35 |
| Support | cast_v2 | 30 | 45 |
| Hit | hit_v1 | 29 | 30 |
| Death | death_v1 | 28 | 55 |

Each selection.json records original chronological frame IDs, contact timing and review notes. Move retains a full reciprocal claw-leg cycle. Guard ends lowered; death ends in a cold grounded wreck matching the original corpse reference. Support articulates the furnace nozzles and piston. Ranged selects only the clean second recoil at 53-81, with contact at source54; earlier fireball frames are excluded whole. Melee excludes effect-contaminated frames37-47; the36-to48 contact join was reviewed with fixed registration. No subject pixels were erased or synthetic poses inserted.

Rejected attack_v1 fires instead of striking; ranged_v1 changes the chroma background and failed the strict matte check; ranged_v2 enlarges/telescopes the nozzle; cast_v1 snaps at interior guide boundaries. All original videos, latents, prompts, workflows and provenance are retained, including rejected takes. Selected transparent source frames remain; other matte frames and review renders are rebuildable and removed after verification.

Generation uses 960x544, 124 frames at24fps,20 steps, res_multistep/simple, staged lossless FFV1 collection, protected chroma extraction and fixed0.6 scale/480,480 source anchor. Rebuild with produce.py process/build/assemble and stage_video.py as appropriate; publication recipe lives under art/animation/source/fluid/unit_brasshollow_crucible_crawlers.

Review covered all124 chronological phases per take, enlarged selected frames, fixed-anchor joins and all selected phases in native Godot128px renders. Windows Godot4.6.2 candidate694 and live708 focused checks passed. All201 packed source-frame pixels/anchors, provenance hashes, eight preserved idle poses, overworld PNG and231 unrelated records verified. Atlas3892x2956. No continuous video playback, manual game playtest, Linux execution or full-suite claim.
