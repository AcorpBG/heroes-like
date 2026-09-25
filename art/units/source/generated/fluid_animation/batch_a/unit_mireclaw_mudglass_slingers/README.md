# Mudglass Slingers H3 source motion

Complete reviewed action set: movement20 at83ms, melee20 at50ms, ranged42 at55ms,
hit18 at55ms, physical support17 at65ms, defense12 at65ms with a140ms terminal
hold, death25 at65ms and its final corpse. Preserve original idle8 at240ms and
byte-exact overworld artwork. All154 selected H3 frames retain original pixels,
one fixed scale0.8 and anatomical ground anchor[480,480].

Identity: adult human slinger, long brown ponytail, green face scarf, olive
leather, yellow reeds, pale belt charms and brown boots. Image-left hand owns
one two-cord leather sling; image-right hand is free to load, punch and brace.
The runtime owns the flying projectile; no duplicate projectile is painted.

configure.py records original guides. Submitted take folders are immutable.
Older painted guides use fixed scale1.03 to match the accepted idle body.
stage_video.py preserves the original video latent, releases large models,
then decodes separately. batch_stage.py also supports grouped sampling/decoding.
MiniMax H3:960x544,124 frames at24fps,20 res_multistep/simple steps; tiled VAE
256/64 spatial and16/4 temporal. Corrected v2 takes record the standard VRAM
profile with dynamic VRAM disabled. Preserve videos, latents, prompts, guides,
workflow histories, original RGB hashes and matte recipes, including rejections.

Rebuild each required matte with `produce.py process TAKE`, then each selected
packet with `produce.py build TAKE`, and the combined packet with `produce.py
assemble`. The selected matte PNGs ship as original source; unselected mattes
are rebuildable from original_lossless.mkv. Comfy output/input duplicates are
removed after verified archival; do not resubmit completed generations to
recover them. Guide-key removal protects32 units of original olive chroma,
checks corner uniformity and retains confidently painted connected components.

Selections/timing are explicit in selection.json. Hit/support/death shorten
settled holds. Walking uses40..78 every second original frame and an inspected
78-to40 seam. Melee keeps the sling lowered while the free fist punches.
Defense lowers into a held forearm guard. Ranged uses original loading0..24,
corrected throw selected10..92, then original recovery70..118. The extra winding
revolution32..74 is condensed at equivalent raised-hand poses. delivery.json
records every segment/frame and release contact; no invented bridging frames,
reversed motion, interpolation or per-frame anatomical normalization is used.

Rejected footage stays excluded: move_v1 repeats one leading leg; attack_v1
switches sling hands; ranged_v1 overhead34..68 duplicates the sling; defend_v1
cycles background colors. Its calibrated chroma trial still left colored edges.
Preserve these original generations and rejection recipes, not disposable mattes.

Review was autonomous: all chronological originals, enlarged hands/cords/alpha,
joins/seams and every packed phase in offscreen Godot at128px reference height.
No continuous video playback or manual game playtest is claimed. The full action
set uses compact original-pixel atlas storage,2752x2532/26.58MiB RGBA, preserving
all source offsets and reducing memory from the prior partial atlas33.84MiB.

Validation:553 full-candidate focused checks; three deterministic compact-packing
pixel/anchor/gutter/limit regressions;190 legacy-grid runtime checks. The imported-live run passed576 checks, including actual shell attack/recovery,
normal/Fast/reduced-motion clocks and unchanged simulation/save. Its initial
sampling failure was resolved by deferring PNG encoding until after playback;
the requirement to observe every attack frame remains intact. All other231 battle/map rows, accepted
pixels/timing, the original idle PNG and final-death corpse were verified exact.
No full repository suite or Linux runtime run.
