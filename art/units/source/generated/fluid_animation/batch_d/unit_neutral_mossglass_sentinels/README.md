# Mossglass Sentinels H3 animation

Six dedicated H3 actions are published with 193 selected original frames. The original eight-frame articulated idle (240 ms/frame) and overworld strip are preserved exactly. Original body scale 1.0, fixed 0.5 extraction, 960x544 canvas, ground anchor [480,480], original local anchor [256,236]. Green/bronze armor initially used magenta key with protected foreground chroma 40; measured opaque source magenta excess at most 34. Corrections use pure blue with protected foreground chroma 100, above the original opaque blue excess maximum of 95.

| Action | Selected take | Frames | Frame duration |
|---|---|---:|---:|
| Move | move_h3_v4 | 36 | 42 ms |
| Attack | attack_h3_v1 | 36 | 40 ms |
| Defend | defend_h3_v2 | 26 | 40 ms |
| Hit | hit_h3_v3 | 31 | 35 ms |
| Support | cast_h3_v2 | 26 | 50 ms |
| Death | death_h3_v1 | 38 | 45 ms |

The final death frame is the persistent corpse; defense holds its final brace. Attack contact is source48, selected index21. Support is a physical rally; this melee creature receives no invented spell or ranged weapon.

The selected attack omits the oversized, smeared mallet head in source frames 41-42. Death keeps the knee buckle, right-arm brace, side fall, yielding elbow and grounded shield/corpse. Defense v2 keeps the mallet low through a shield-led crouch. Support v2 is a physical mallet rally, not a spell. Long source holds are condensed by selecting chronological original frames; there is no duplicated, reversed or synthesized motion.

Rejected sources are retained. Walk v1 turns to the wrong view and reverses the shield. Walk v2 fixes the mallet and backdrop but still reverses the shield during alternating steps. Walk v3's dense original gait guides hold and jump between poses. Reassessment identified mismatched original ready/walking upper-body views and missing matched reciprocal poses. Built-in image generation supplied the two original walking keys in `walking_guides_v1.png`; exact prompt, source references and hashes are adjacent. One source-wide scale of 200/687 matches their body height to the original. Walk v4 uses one opposing-leg midpoint and preserves the shield front, low mallet, camera and reciprocal gait in cycle6-41. Its uniformly blue/green backdrop switches are recorded in extraction_settings.json. Original opaque green excess89 is below protected100; all61789 solid control pixels remain opaque when keyed. Enlarged dark/light review and native scale inspection confirm armor and fine edges remain intact.

Defense v1 invents scenery and an overhead attack; hit v1 and support v1 change backdrop into armor colors and were rejected. Hit v2 has instantaneous entry/recovery switches; hit v3 adds a planted guard as the recovery intermediate instead of a repeated recoil hold. Selected hit omits smeared source6-7.

Windows Godot focused checks passed: 259 candidate and 273 published checks, no assertion failures. Complete native128px phase overview and published battle/map idle renders inspected. All193 new original-frame pixels/anchors/timings verified, all202 candidate/live poses identical,70 provenance hashes verified,13 immutable takes and36 guides verified. Atlas4032x3960 respects4096 limit. The other231 creatures and map catalog/strip are unchanged. Live roster:152 complete,80 remaining. Engine emitted the existing root-certificate-store and unsupported GLES3 2D-MSAA warnings; import/render and focused assertions succeeded.

Review covered chronological originals, enlarged phases, gait seam and native-scale renders. Continuous video playback was unavailable; this does not claim continuous playback, a manual game playtest, the full suite, or Linux validation.

Originals, guides, prompts, latents, rejected takes and provenance are retained. Coordinator owns review and publication.
