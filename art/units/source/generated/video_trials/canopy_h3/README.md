# Canopy Rammers: heavy walk and chest salute

Published both selected local H3 takes for `unit_thornwake_canopy_rammers`:

| Action | Take | Original frames | Runtime timing |
| --- | --- | --- | --- |
| Support | cast_v1 | 12-80 every 2, 35 poses | 50ms, 1750ms gesture; contact index15 |
| Move | move_v1 | 42-80 every 2, 20 poses | 70ms, 1400ms loop |

Support raises the far fist to the upper chest, holds the physical salute, then returns to ready. The near fist stays low and both root feet remain planted. Walking alternates near-leg contact, passing, opposite contact and return, with modest opposing arm swing, lifting root toes and a stable horn crown. No invented weapon or spell. Original source intervals span approximately 2917ms and 1667ms; both are deliberately retimed for gameplay. These are observed frames, without reversed poses, interpolation or per-frame normalization.

The original batch_b Canopy paintings supply every guide. Support uses cast_v1 poses00/02 at the already established .55 body scale, with chest guides at42/58 and ready at86. Walking uses the first move_v1 contact at .57, calibrated to the existing approximately192px standing silhouette, repeated at endpoints and41/82. Reciprocal gait was verified from the video rather than inferred from the old sheet. Input scales equal the original source scale divided by .6; extraction uses fixed .6 at ground anchor480,475. Exact crops, alpha cutoff, anchors and guide/source hashes are recorded in reference.json. Source facing remains right.

Both complete original 960x544, 124-frame, 24fps FFV1/MP4 pairs are retained, with all248 decoded RGB hashes, exact prompts, workflow graphs, inputs, job history and matte recipes. Models: MiniMax H3 int8_convrot, Qwen3VL32B nvfp4_awq and H3 video VAE int8_convrot,20 res_multistep/simple steps. Support seed2026092451 took128.171 seconds; walking seed2026092452 took121.829 seconds. Fifty-five selected transparent frames are retained.

The initial magenta unmix left a reddish fringe around horns and moss. The selected extraction refines alpha in the four-pixel uncertain edge band using the nearest confidently opaque interior color and the measured background as a local RGB mixture. It then unmixed the original observed pixels and removes residual magenta spill. Interior anatomy is not repainted or warped, and the core erosion is only for foreground-color estimation, not silhouette erosion. Dark/light enlarged review confirmed the thin horn and moss tips remain intact. Each produce.py and matte.json contains the reproducible recipe.

Autonomous review covered all248 ordered original frames, enlarged fist/root-leg/horn anatomy and alpha, selected walk seam80/82/42 and actual Godot gameplay-scale rendering. Candidate145 and published159 focused Windows checks passed, including Normal/Fast/reduced-motion. Candidate/live atlas hashes match. All32 poses in the five previously accepted actions and the persistent corpse retain exact pixels, offsets and timing. Overworld idle PNG is byte-identical; other creature catalog and map metadata rows are unchanged. This is ordered-frame/native-render/runtime review, not continuous browser playback, a manual playtest, Linux execution or a full-suite run.

Canopy Rammers now have all seven required actions accepted. Live roster coverage is105 complete,2 partial and125 without accepted coverage;127 remain incomplete.

Rebuild matte frames with each take's produce.py process, review sheets with review and selected recipes with build. assemble.py combines the selected clips and builds a pending candidate against the published source recipe, preserving the accepted idle. Rebuilding intentionally resets review to pending. Explicit publication uses tools/publish_fluid_creature_animation.py after autonomous visual review.

Cleanup removed473 exact task-owned disposable files, recovering172739363 bytes (164.7MiB): previews, native outputs/logs/test profiles, unselected RGBA and hash-verified duplicate Comfy PNG/MP4/input exports. They are rebuildable from retained source/tooling. Original art, videos, prompts, provenance,55 selected RGBA, caches, saves, backups and unrelated work remain. The queue was empty, no Godot process was active, and models were unloaded while the service remained available.
