# Lanternet Throwers H3 animation delivery

Seven accepted actions replace the legacy short clips. The original eight articulated idle poses remain pixel-identical in battle and on the overworld. Human anatomy, olive cloth, leather armor, gathered lantern-weight rope net and belt lantern are preserved.

| Action | Selected take | Frames | Gameplay timing |
|---|---|---:|---|
| Move | move_h3_v2 | 20 | 1000 ms loop |
| Melee | attack_h3_v4 | 22 | 920 ms; contact 320 ms |
| Hit | hit_h3_v4 | 25 | 750 ms |
| Defend | defend_h3_v1 | 16 | 672 ms; hold final guard |
| Physical support | cast_h3_v3 | 33 | 1155 ms; signal 280 ms |
| Death | death_h3_v1 | 25 | 1300 ms; final frame is corpse |
| Ranged | ranged_h3_v4 then ranged_h3_v3 | 50 | 1500 ms; release 450 ms |

The walk includes both leg contacts and passing phases. Melee is a short empty-fist punch while the opposite hand holds the gathered net low. Hit flexes the knees and recoils the shoulders without distorting the net. Defense crouches behind raised forearms. Support raises an empty palm as a physical signal. Death lowers through the knees and rolls onto a grounded forearm with the net resting beside the body.

Ranged uses the compact two-handed chest-toss windup and release from v4, then the clean belt reload from v3. The join is v4 original 54 to v3 original 56: both use the same original empty-handed follow-through guide, scale and anatomical anchor. From v4 original 44, the fully detached projectile is separated across an inspected empty vertical gap at x640. The builder asserts that no character component crosses that gap. Every hand, body and held-equipment pixel remains; the complete projectile pixels remain in the original matte/video. The existing game renderer owns projectile flight. The malformed earlier v3 release and later v4 floating duplicate are excluded.

Melee original 25-33 contains an unwanted detached impact burst. The selection trims that part of the contact hold, retaining original 24 at maximum reach and 34 during the short fist withdrawal. Dense originals 21-24 preserve the jab. The native transition and complete recovery were reviewed. No source painting was erased or synthesized to hide these defects.

Video originals use a fixed 960 x 640 canvas, anchor [416,560] and scale 0.5; ranged uses 960 x 768, anchor [416,688] and the same scale, adding 128px of headroom without changing anatomy. Original key-pose masters have documented whole-source scale registration. No per-frame resizing, stabilization, interpolation, reversed motion or duplicate padding. Selection files retain source indices, timestamps, clip timing and excluded intervals. The final atlas is 2496 x 3000, containing 191 new frame references plus preserved routes, within the 4096 texture bound.

Two built-in imagegen masters provide the empty-fist melee contact and compact ranged windup. Exact prompts, original output paths, reference hashes and source-scale reasons are in melee_contact_v1.generation.json and ranged_windup_v1.generation.json. H3 remains the animation generator. Original videos, sampled latents, workflow graphs, guides and failed-take decisions are retained for all 19 takes. Failed footage includes unsafe changing backgrounds, stretched/clipped nets, an incoming weapon, a stiff red-edged hit prop and incompatible projectile/reload motion; those intervals are not published.

Validation: all 124 chronological frames of the selected takes, enlarged anatomy/grips/alpha and all selected native Godot phases were reviewed. The final candidate passed 673 focused checks and the published unit passed 687, including Normal/Fast/reduced-motion, complete timed attack/recovery, persistent corpse and unchanged committed simulation. Isolated Godot import passed. Windows root-certificate and GLES3 MSAA warnings were non-failing. No continuous-video playback, manual playtest or Linux run is claimed; no full suite ran.

Source verification proved 2356 original RGB frames across 19 lossless videos, 33 guides, 96 selected provenance records and exact runtime frame pixels/anchors. The other 231 unit rows are unchanged; idle timing, all eight idle paintings and every overworld-idle pixel are preserved. Core roster coverage is 167/232, with 65 remaining; the overall goal stays active and production remains solo.

Rebuild with produce.py: process each selected take, build its selection, then assemble delivery.json, including its ranged clip_sequences. The v3 ranged extract_ranges.json deliberately limits extraction to the reviewed recovery. stage_video.py saves the sampler latent before unloading large models and decoding separately. Publish move/attack/hit/defend/cast/death/ranged with --preserve-reviewed idle. Keep original/provenance files and selected mattes; unselected mattes, duplicate Comfy outputs and task-owned review/test exports are rebuildable disposable outputs.
