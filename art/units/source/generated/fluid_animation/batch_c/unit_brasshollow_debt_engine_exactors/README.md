# Debt-Engine Exactors H3 animations

Published six reviewed actions: move26 (1300ms), attack34 (1428ms, contact588ms), defend29 (957ms), support29 (1218ms, contact546ms), hit23 (690ms), death40 (2000ms, final persistent corpse). 181 original H3 frames; original eight-frame260ms articulated idle and overworld PNG preserved exactly.

Ten takes preserve the right-facing two-arm/two-leg brass automaton, unequal piston gauntlets, furnace, parchment and seals. Rejected move_v1 doubled boots, attack_v1 changing gauntlet silhouette and hit_v1 pose cuts. Death uses only death_v1 descent17..65 followed by death_settle_v2 forward collapse; the first take's backward flip is excluded. Larger fixed-scale reference and fewer interior guides improved the corrections. Attack retains brief source motion blur during its fast punch; no generated interpolation or per-frame resizing was applied.

Review covered all chronological source frames, enlarged selected anatomy/edges, fixed-anchor gait/death joins and final native Godot phases at battle128px and map64px ground scale. No continuous video playback, manual game playtest, Linux validation or full-suite claim. Focused Windows checks: candidate247 and published261 passed. All181 source pixels/anchors/provenance match; other231 unit records unchanged. Runtime atlas3848x3900 (60,028,800 RGBA bytes).

## Rebuild

Use H:/ai/envs/minimax-h3/python.exe. Each take retains config, prompts, original guides, sampling/decode workflows, original latent, FFV1 lossless video, preview MP4, extraction recipe and review. Selected transparent source frames and cross-take guides are retained. Rebuild discarded intermediate mattes with `produce.py process TAKE`; build take packets with `produce.py build TAKE`; assemble the reviewed selection with `produce.py assemble`. Publish through tools/publish_fluid_creature_animation.py with move, attack, defend, cast, hit, death and preserved idle. The published source folder retains the original baseline.

stage_video.py saves the original sampler latent, releases models, then decodes with the VAE separately. It does not invent frames. Rejected original generations remain for provenance; temporary reviews, isolated test profiles and verified duplicate Comfy outputs are disposable and removed after validation.
