# Basalt Wardens H3 movement

`unit_neutral_basalt_wardens`: 20 observed source frames 40–78 every second frame, at 70 ms each (1,400 ms). Both armored boots exchange forward contact and passing. The shield-side boot emerges beneath the pavise while the opposite foot lifts behind; the mace remains lowered in its original grip. The roughly 1,667 ms source cycle is deliberately accelerated for travel. No reverse poses, duplicate padding, interpolation or whole-body warping are used.

The first accepted `attack_v1_0` ready painting supplies both video endpoints. Earlier repeated-leg walking artwork remains unpublished. `reference.json` preserves the original crop, alpha threshold, anchor and hashes. Input scale is 1.0 on a 960×544 canvas at (480,475); extraction stays at 0.59, matching the accepted ready body. Changing pose bounds do not control individual scale or alignment.

The local MiniMax H3 graph used seed 2026092417, 20 steps, 124 frames at 24 fps and pure-green background. Generation took approximately 136 seconds. The FFV1 original preserves every decoded RGB frame; original MP4, guides, prompt, workflow, hashes and generation history retain provenance. `produce.py process` reconstructs all transparent frames, `review` reconstructs chronological sheets, and `build` reconstructs the candidate handoff. Do not resubmit or overwrite the original job.

Review covered all 124 chronological source frames, enlarged light/dark alpha/anatomy samples and the native Godot battle overview. The original face, hair, copper shield bands, rigid pavise shape and mace remain consistent. Continuous playback is not claimed: the local browser preview route was previously blocked by browser URL policy and no workaround was attempted. No manual game playtest, Linux execution or full suite is claimed. The source handoff remains a pending rebuild recipe; published acceptance and focused checks are recorded in runtime provenance and the progress tracker.

Retain the original video, art/provenance and 20 selected RGBA frames. Unselected extractions, temporary review/render/import files and hash-verified duplicate server outputs are rebuildable and removed after delivery.
