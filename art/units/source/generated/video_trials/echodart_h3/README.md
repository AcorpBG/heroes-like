# Echodart Casts: articulated idle and reciprocal walk

Published both selected H3 takes for `unit_neutral_echodart_casts`:

| Action | Take | Original frames | Runtime timing |
| --- | --- | --- | --- |
| Idle | idle_v1 | 0-98 every 2, 50 poses | 83ms, 4150ms loop |
| Move | move_v1 | 42-80 every 2, 20 poses | 60ms, 1200ms loop |

Idle lowers the crossbow through both elbows, adjusts the wrist angle and raises it back to ready while the boots stay planted. The walk alternates near-leg contact, passing, opposite-leg contact and return, with restrained shoulder, ponytail and scarf motion. Both grips, rigid crossbow limbs, cyan details and original equipment remain readable. Original source intervals span approximately 4167ms and 1667ms respectively; movement is deliberately retimed for gameplay. No reversed poses, synthetic interpolation or per-frame size normalization.

Both videos use the original batch_d Echodart paintings. Idle uses the full first idle cell so the crossbow tip is retained. Walking uses the fourth original movement cell as its contact guide at the endpoints and frames41/82; that old sheet repeats the leading leg, so reciprocal motion was verified from the new video itself. Exact crops and hashes are in reference.json. Original .4 runtime body scale is retained through .9 input scale and .4/.9 extraction, with fixed video ground anchor480,475 and left-facing source orientation.

Two complete original 960x544, 124-frame, 24fps FFV1/MP4 pairs are retained, with all248 decoded RGB hashes, exact prompts, workflow graphs, input guides, generation histories and matte recipes. Models are MiniMax H3 int8_convrot, Qwen3VL32B nvfp4_awq and H3 video VAE int8_convrot, using20 res_multistep/simple steps. Idle seed2026092449 took115.888 seconds; movement seed2026092450 took121.624 seconds. Seventy selected transparent frames are retained. Matte extraction uses a verified uniform green plate, alpha unmix, despill and connected-component noise removal; it does not alter anatomy.

Autonomous review covered all248 ordered original frames, enlarged hands/weapon/anatomy and light/dark alpha edges, loop seams98/100/0 and80/82/42, and actual Godot battle-scale and overworld renders. Candidate186 and published190 focused Windows checks passed, including Normal/Fast/reduced-motion. Candidate and live atlas hashes match. All40 previously accepted attack/ranged/hit/defend/cast/death poses retain exact pixels, offsets and timing. Other creature catalog and overworld metadata rows are unchanged. Overworld idle now uses the new50-frame clip. This is ordered-frame/native-render/runtime review, not continuous browser playback, a manual playtest, Linux execution or a full-suite run.

Echodart now has all eight required actions accepted. Overall live roster coverage is104 complete,3 partial and125 without accepted coverage;128 remain incomplete.

Rebuild transparent frames with each take's produce.py process, review sheets with review, and selected recipes with build. assemble.py combines the selected clips and creates a pending candidate against the existing published recipe. Rebuilding resets root review to pending intentionally. Explicit publication uses tools/publish_fluid_creature_animation.py after autonomous review.

Cleanup removed455 exact task-owned disposable files, recovering132766262 bytes (126.6MiB): temporary previews, native check outputs/profiles/logs, unselected matte frames and hash-verified duplicate ComfyUI PNG/MP4/input exports. They are rebuildable from preserved source/tooling. Original art, videos, prompts, provenance, selected RGBA frames, caches, saves, backups and unrelated work remain. The generation queue was empty and no Godot process was active; models were unloaded while ComfyUI remained available.
