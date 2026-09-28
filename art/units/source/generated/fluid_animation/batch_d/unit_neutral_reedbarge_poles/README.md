# Reedbarge Poles H3 animation delivery

Six accepted actions replace the legacy short clips. The original eight articulated idle poses remain unchanged in battle and on the overworld.

| Action | Take | Selected frames | Gameplay duration |
|---|---|---:|---:|
| Move | move_h3_v2 | 20 | 1000 ms loop |
| Attack | attack_h3_v3 | 32 | 1280 ms; contact at 640 ms |
| Hit | hit_h3_v2 | 20 | 640 ms |
| Defend | defend_h3_v1 | 16 | 672 ms; hold final guard |
| Physical support | cast_h3_v1 | 23 | 1150 ms; peak at 400 ms |
| Death | death_h3_v1 | 26 | 1352 ms; retain final corpse |

The walk alternates both legs through contact and passing. Attack lowers the pole, commits the knee and torso into a forward lunge, then recovers. Hit recoils backward; defense lowers into a held crosswise guard. Support is a nonmagical two-handed pole salute. Death kneels and rolls onto the forearm, with both legs and the single hooked pole resting beside the body.

Originals use a fixed 960x640 camera, anatomical anchor [416,560] and scale 0.5. No per-frame resizing, root stabilization, interpolation, reverse poses or duplicate padding. Selection files preserve source indices, timestamps and deliberate gameplay retiming. Final atlas is 3936x3952; 137 new frame references plus the retained idle fit within the existing 4096 texture bound.

The support source shifts from a flat blue to flat cyan background. Its extraction_settings.json records a measured blue-red key axis: original opaque foreground maximum 41, protected band 43. Corner uniformity and strong chroma separation remain mandatory. Boundary-only cyan despill preserves the teal cloth; enlarged light/dark previews and native output were reviewed. The original extraction failure is retained as history, not hidden.

Rejected originals remain preserved: move_v1 and hit_v1 have unsafe changing backgrounds; attack_v1 has hard cuts between guides; attack_v2 lacks a committed thrust. One forward-lunge guide fixes the final attack without the earlier multiple-guide cuts. The hit_v2 driver stopped after sampling when VRAM release was delayed; decode_recovery.json records resuming the exact saved latent without resampling.

Validation: all 124 source frames of each accepted take reviewed chronologically, enlarged anatomy/grips/hook/alpha checked, and every selected native Godot phase inspected. 218 focused candidate checks and 232 live checks passed, including Normal/Fast/reduced-motion, complete timed attack/recovery, persistent corpse and unchanged committed simulation. The earlier three-action candidate passed 72 checks. Godot import passed. Windows root-certificate and GLES3 MSAA warnings were non-failing; no Linux run, continuous-video playback or manual playtest is claimed.

Source verification proved 1,240 original RGB frames from ten lossless videos, 17 guides, 69 selected provenance records and exact runtime source pixels/anchors. All other 231 unit rows are unchanged. The eight original idle frames, timing and offsets, and every overworld-idle pixel are preserved. Roster core coverage is 166/232; the overall goal remains active.

Rebuild with produce.py: process each accepted take, build it, then assemble the delivery.json list. stage_video.py preserves the original sampler latent before model release and a separate VAE decode. Runtime publication uses tools/publish_fluid_creature_animation.py with move/attack/hit/defend/cast/death and --preserve-reviewed idle. Original videos, latents, guide images, exact prompts, graphs and hashes are retained; task-owned review copies and unselected rebuildable mattes are disposable.
