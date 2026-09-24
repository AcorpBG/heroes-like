# Millstone Slingers: movement, recoil and rally

Published three H3 clips for `unit_neutral_millstone_slingers`:

| Action | Selected take | Original frames | Runtime timing |
| --- | --- | --- | --- |
| Move | move_guided_v3 | 42-80 every 2 (20 poses) | 60ms, 1200ms loop |
| Hit | hit_guided_v2 | 0-56 every 2 (29 poses) | 30ms, 870ms recoil |
| Support | cast_guided_v2 | 14-88 every 2 (38 poses) | 50ms, 1900ms rally |

The walk alternates near-leg contact, passing, far-leg contact and return, with a modest shoulder turn, short held sling and stable clothing. Hit bends the knees, opens the free hand and recoils through the shoulders before recovering with the sling coiled in the other fist. Support raises the free palm overhead while the loaded sling stays low and both feet remain registered. Original source intervals span approximately 1667/2417/3167ms respectively and are deliberately retimed for the game. No reversed poses, synthetic interpolation or per-frame normalization.

The four previously accepted actions (idle, attack, defend, death; 28 poses) and the existing four-frame ranged route retain exact pixels, offsets and timing. Overworld idle PNG is byte-identical. Other creature catalog rows are unchanged. This unit remains partially complete: its **ranged animation is not accepted**. Overall roster coverage remains 103 complete, 4 partial and 125 without accepted coverage.

All twelve original takes are retained as 960x544, 124-frame, 24fps FFV1/MP4 pairs, with every decoded RGB hash, exact prompt, workflow, guides, seed, job history and extraction recipe. The local models are recorded in each graph: MiniMax H3 int8_convrot, Qwen3VL32B nvfp4_awq and H3 video VAE int8_convrot, 20 res_multistep/simple steps. Accepted move/hit/support generation took 122.759/126.916/125.659 seconds. Seeds are 2026092446/45/44 respectively.

Original ready/support/recoil paintings are in the batch_d Millstone source folder. Image-generated key guides and exact prompts are preserved under key_guides, with generation.json lineage. The generated walk pair repeats the same leading leg; only its left contact is used as a reference. Its .245 runtime scale matches the original body height, with anchor406,958. Original hit ready uses .59, recoil .55, support .6. All guide scales are divided by .6 for video input; output extraction uses fixed .6 at ground anchor480,475. Each reference.json records the exact crop, input scale, runtime scale and hashes. Colored RGB behind zero alpha in original generated images is not a visible background.

Rejected takes remain excluded:

- ranged_v1 stretches/clips the sling; ranged_guided_v2/v3 still inflate its cup/cord around release despite better guides.
- After those repeated failures, a new original compact loaded-sling key was generated. ranged_compact_v4 preserves length but its dense guide schedule produces hard pose cuts. ranged_compact_v5 restores motion with fewer guides but expands the sling into a large closed loop and changes background colors. **The remaining gap is a continuous, anatomically coherent short-sling release and recovery.** Do not repeat unchanged prompts or mark it accepted.
- move_v1 and move_guided_v2 change background color and have contaminated motion/edges or excessive rotation. The shorter third prompt with the same contact guides produces the selected stride.
- hit_v1 invents an incoming weapon and an oversized sling during recovery. The corrected physical-flinch prompt and recovery guides eliminate those additions.
- cast_v1 has coherent motion but cycling magenta/yellow/cyan plates leave contaminated edges even after measured-plate unmix. That extraction experiment is preserved only for provenance; the selected second take uses the ordinary verified magenta matte.

Autonomous review covered the complete ordered frame sequences, enlarged anatomy and light/dark alpha edges, the selected movement seam80/82/42, and the native Godot battle-scale candidate. Candidate173 and published187 focused Windows checks passed, including Normal/Fast/reduced-motion. Candidate and live atlas SHA256 match. This is ordered-frame/native-render/runtime review, not continuous browser playback (preview route unavailable), a manual playtest, Linux execution or a full-suite run. Routine review and publication are autonomous per owner direction.

Rebuild a take's transparent frames with its produce.py process, chronological review with review, and selected clip recipe with build. Run assemble.py to combine the three selected clips and produce a pending candidate against the currently published source recipe. Review before explicit publication through tools/publish_fluid_creature_animation.py. The root handoff records the actual accepted delivery; rebuilding it resets review to pending intentionally.

Cleanup removed 2448 exact task-owned disposable files, recovering 820657758 bytes (782.6MiB): previews, native test outputs/profiles/logs, unselected RGBA frames and hash-verified duplicate ComfyUI PNG/MP4/input exports. These are rebuildable from the preserved source/tooling. Twelve original video pairs, all original art/prompts/provenance, 87 selected RGBA frames, caches, saves, backups and unrelated work remain. Generation queue was empty, no Godot process was active, and task-loaded models were unloaded; the ComfyUI service stays available.
