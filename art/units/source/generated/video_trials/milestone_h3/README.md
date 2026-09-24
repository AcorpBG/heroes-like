# Milestone Bucklers: walk, spear salute and collapse

Published three local H3 clips for `unit_neutral_milestone_bucklers`:

| Action | Take | Observed source frames | Runtime timing |
| --- | --- | --- | --- |
| Support | cast_v2 | 16-86 every 2, 36 poses | 50ms, 1800ms; contact index13 |
| Move | move_v1 | 42-80 every 2, 20 poses | 60ms, 1200ms loop |
| Death | death_v1 | 0-86 every 2, 44 poses | 45ms, 1980ms; final pose becomes corpse |

Support rotates the original short spear upright, holds a rally salute and lowers it, with a stable grip, shield and planted boots. Walking alternates heel contact, loading, passing and opposite-leg extension while holding the shield securely and the spear clear of the legs. Death buckles to the knees, slumps, falls onto the shield side and settles on the ground. The spear arm follows the roll upward briefly before relaxing onto the ground; the final body and equipment remain still. Original source intervals span approximately3000/1667/3667ms and are deliberately retimed for gameplay. No reversed poses, synthetic interpolation or per-frame normalization.

All references come from the original batch_d Milestone paintings. Source scales are .61 for ready/support, .64 for walking and .46 for collapse/corpse, preserving the existing approximately220px body. Each input scale is the original scale divided by .65; extraction uses .65 and a shared video ground anchor480,475. Standing anchors were corrected to original boot contacts: cast00 y377, cast02 y765 and move00 y334. Kneeling/corpse retain the original ground reference, without scaling the fallen body to standing height. Source orientation remains right.

The old broad sheet rectangles included detached fragments from neighboring poses. The initial cast_v1 job was interrupted after those fragments were noticed in its guide; it produced no video and is excluded. Its exact prompt, inputs, graph, interruption history and rejection are retained. The selected guides use tools/refine_fluid_frame_crops.py body_rectangles at cutoff8, selecting original connected pixels through recorded body seeds. This removes foreign fragments without repainting or altering the original art. Exact crops, anchors, source hashes and guide hashes are in reference.json.

Support uses ready endpoints, the upright spear at42/58 and ready at86. Movement repeats the contact at endpoints and41/82, with reciprocal gait verified from the generated footage. Death uses ready first, kneeling at42 and a grounded corpse at86 and the last frame. Three complete960x544,124-frame,24fps FFV1/MP4 pairs and all372 decoded RGB hashes are retained, alongside exact prompts, workflows, guides, job histories and matte recipes. Models are MiniMax H3 int8_convrot, Qwen3VL32B nvfp4_awq and H3 video VAE int8_convrot,20 res_multistep/simple steps. Selected support/move/death seeds are2026092456/54/55; generation took124.591/122.201/122.328 seconds. One hundred selected RGBA frames are retained.

Plain magenta alpha unmix and edge-only despill preserve the armor and cloth colors. The local-edge refinement copied from the foliage creature was visually unsuitable for this unit's metal/cloth palette and was excluded before publication. Background extraction does not modify geometry. No unsafe background plate or neighboring fragment enters the selected footage.

Autonomous review covered all372 ordered original frames, enlarged face/grip/shaft/shield/boot/death anatomy and dark/light alpha, selected gait seam80/82/42 and native Godot gameplay-scale rendering. Candidate182 and published196 focused Windows checks passed, including Normal/Fast/reduced-motion. Candidate/live atlas hashes match. All24 poses in the four previously accepted idle/attack/hit/defend actions retain exact pixels, offsets and timing. Overworld idle PNG is byte-identical; other creature catalog and map metadata rows are unchanged. This is ordered-frame/native-render/runtime review, not continuous browser playback, a manual playtest, Linux execution or a full-suite run.

Milestone Bucklers now have all seven required actions accepted. Overall live roster coverage is106 complete,1 partial and125 without accepted coverage;126 remain incomplete.

Rebuild transparent frames with each selected take's produce.py process, chronological sheets with review and selected recipes with build. assemble.py combines the three selected clips and creates a pending candidate against the published source recipe while preserving the accepted idle. Rebuilding intentionally resets root review to pending. Explicit publication uses tools/publish_fluid_creature_animation.py after autonomous review.

Cleanup removed685 exact task-owned disposable files, recovering206817333 bytes (197.2MiB): previews, native outputs/logs/test profiles, unused RGBA and hash-verified duplicate Comfy PNG/MP4/input exports. They are rebuildable from retained source/tooling. Original art, three video pairs, all prompts/guides/provenance,100 selected frames, caches, saves, backups and unrelated work remain. The queue was empty and no Godot process was active; models were unloaded while ComfyUI remained available.
