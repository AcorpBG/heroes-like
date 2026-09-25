# Fordhook Cadets H3 originals

Six deficient actions for `unit_embercourt_fordhook_cadets`; retain the eight
accepted articulated idle poses and their overworld playback. Young red-coated
human soldier, red/brass helmet, steel shoulder plates, brown gloves and boots,
brass shin straps. Left arm holds one round wooden shield with brass rim/boss;
right hand holds one brown-shafted hooked steel spear. Two arms and two legs,
fixed right-facing camera. Support is a physical rally salute, not invented magic.

Original ready, gait, attack continuity corrections, brace, recoil and death
paintings are located by the existing `packing.json` rectangles and anchors.
One source scale per original is divided by fixed extraction scale0.8, with
video root(480,475). No per-frame resizing, synthetic articulation, interpolation
or duplicate-frame padding. Preserve detached shield/spear pixels during death.

Local MiniMax H3 FL2VA int8 ConvRot, Qwen3-VL32B NVFP4 AWQ and H3 video VAE;
960x544,124 frames at24fps,20 res_multistep/simple steps. Every take retains
prompt, registered guide hashes, seed, exact model names/API graph, submission
and history, original MP4, lossless FFV1 and every decoded RGB frame hash.

Green is absent from the cadet palette. Measured uniform-plate unmix/despill
removes the background; alpha>=8 components containing opaque alpha>=128 pixels
are retained, including detached equipment. Corner spread must remain<=10 and
chroma separation>=80. This matte operation cannot repair invented body parts.

Rebuild with `produce.py process TAKE`, `build TAKE` and `assemble`.
Selections preserve exact source indices and timestamps; timing changes are
recorded in selection.json. Review uses every chronological original, enlarged
grips/anatomy/alpha boundaries, cycle seam and native Godot battle phases.
Continuous playback/manual playtesting is not claimed. Focused offscreen
checks only. Keep all originals/provenance; remove disposable previews and
hash-verified duplicate Comfy exports after delivery.

## Selected actions

| Action | Take | Frames | Playback | Contact |
| --- | --- | ---: | ---: | ---: |
| Move | move_v2 | 24 | 2040 ms | Complete reciprocal cycle |
| Attack | attack_v1 | 28 | 1344 ms | 624 ms, original frame 52 |
| Defend | defend_v1 | 17 | 850 ms | Held final shield brace |
| Hit | hit_v1 | 20 | 880 ms | Recoil and recovery |
| Support | cast_v1 | 17 | 1105 ms | 520 ms spear salute |
| Death | death_v2 | 24 | 1320 ms | Grounded final corpse |

130 selected original frames. Preserve all eight articulated idle poses,
their timing and anatomical offsets. The support action raises the right
hand and spear toward the shoulder; it does not give this melee unit magic.
Long generated holds are condensed. Contact transitions retain dense original
frames. The initial 137-frame selection exceeded the atlas limit; seven
redundant samples were removed and durations adjusted without resizing the
creature or modifying original pixels.

move_v1 is rejected for repeated same-leg lifts and held passing poses.
move_v2 removes those periodic guides and supplies a clean alternating gait.
death_v1 is rejected because its reclining middle guide and final corpse face
opposite directions. death_v2 removes that incompatible guide: knees buckle,
the body falls forward onto its left side, then both legs and equipment settle.
All 124 chronological frames of every take were reviewed, followed by enlarged
anatomy, grips, matte boundaries, critical transitions and the selected loop.
Native Godot phases show readable motion at battle scale. No continuous
video playback or manual playtest is claimed.

Focused Windows Godot validation passed: 202 candidate and 216 live checks,
including Normal/Fast/reduced-motion and presentation/simulation invariants.
Published phases were inspected at native battle scale. Candidate/live atlas
hashes match; atlas 4092x4004, 65,537,472 decoded RGBA bytes. All eight retained
idle images, offsets and timing match the baseline exactly, the overworld PNG
is byte-identical, and all other units' catalog rows are unchanged. No Linux
run is claimed. Live roster after this delivery: 113 complete, 1 partial,
119 remaining of 232. The overall animation goal remains active.
