# Lantern Sappers H3 originals

Six deficient actions for `unit_embercourt_lantern_sappers`, preserving eight
accepted articulated idle poses and their overworld playback. Young human woman,
ivory-and-teal head scarf, ivory cloth, brass plates, teal sash, brown gloves
and boots. The near hand carries a coiled iron chain with one hooked end; the
far hand holds a crook suspending one brass lantern. Two additional lanterns
remain attached to the wooden backpack. Keep two arms, two legs, all three
lanterns and the original right-facing camera. Support signals with the lantern.

Original guides come from the existing pose packing recipe. Fixed extraction
scale 0.8 and ground anchor (480,480); each source uses its original anatomical
scale. No per-frame resizing, invented articulation, interpolation or padding
with duplicated frames. Retain thin chain links and grounded detached equipment.

Local MiniMax H3 FL2VA int8 ConvRot, Qwen3-VL32B NVFP4 AWQ, H3 video VAE;
960x544, 124 original frames at 24 fps, 20 res_multistep/simple steps. Each take
retains original MP4 and lossless FFV1, every decoded RGB hash, exact workflow,
model names, seed, prompt, registered guides, submission and generation history.
Uniform green plate removal measures background color and unmixes alpha with
edge-only spill suppression. Keep alpha>=8 connected components containing
alpha>=128 source pixels, including separate chain/hook/lantern details.

Rebuild using `produce.py process TAKE`, `build TAKE`, then `assemble` from
delivery.json. Exact selected original indices and timing live in selection.json.
Review covers every chronological original, enlarged anatomy/grips/alpha,
critical transitions, loop seam and native Godot phases at battle scale.
Continuous video playback and manual playtesting are not claimed. Focused
offscreen checks only; originals and provenance are retained after cleanup.

## Published selection

| Action | Take | Original frames | Duration |
| --- | --- | ---: | ---: |
| Movement | move_v1 | 24 | 2040 ms |
| Chain-hook attack | attack_v1 | 28 | 1260 ms |
| Guard | defend_v1 | 16 | 880 ms |
| Hit and recovery | hit_v1 | 19 | 855 ms |
| Lantern support signal | cast_v1 | 19 | 1140 ms |
| Fall and lantern extinction | death_v1 | 25 | 1625 ms |

131 selected original H3 frames. Attack contact is frame 17 (original 48),
765 ms into the clip. Death and defense hold their final dedicated poses.
Movement retains a complete reciprocal two-step cycle; support gathers the
chain hand and raises the suspended lantern, then returns to ready.
The fall keeps dense consecutive original frames through ground contact,
settles the boots and equipment, and extinguishes all three lanterns.

Native Godot 4.6.2 Windows rendering passed 195 candidate and 209 live focused
checks. Every native phase was inspected at 128-pixel reference height.
Published atlas is 3440x3808 (52,398,080 decoded RGBA bytes), byte-identical to
the reviewed candidate. Eight accepted idle poses, offsets and timing are exact;
the overworld PNG is byte-identical, and other creature catalog rows are unchanged.
The complete roster is now 114 complete, one partial and 118 remaining of 232.
No full repository suite or manual playtest was run. Existing Windows certificate
store and GLES3 2D MSAA warnings did not fail the focused renderer checks.
