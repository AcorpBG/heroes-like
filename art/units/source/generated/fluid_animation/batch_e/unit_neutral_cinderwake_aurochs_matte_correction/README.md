# Cinderwake death extraction correction

Original death RGB footage already contains detached foreign fragments at video frames 58–77. Fixed semantic alpha retained them; the complete connected horn and body remain correct. The final grounded corpse at video frame 123 contains no detached fragment.

`derive.py` excludes only 23 explicitly recorded detached components in 17 selected death frames: 2,893 alpha pixels. Every RGB byte, connected body pixel and other RGBA pixel remains unchanged. `extraction_recipe.json` records exact original/derived hashes and component geometry. Original lossless video, all original mattes, prompts and guides stay in the original batch_d directory.

The corrected chronological 43-phase death retains its original anchors, timing and terminal corpse. All 162 other authored/idle poses, map idle pixels and the other 231 catalog rows remain exact. `verify_sources.py --live` reconstructs and compares every selected original/derived packed pose. `run_stage.py live` refreshes only the two selected textures and checks exact Godot RGBA import and focused normal/reflected native fixtures. `compact_death.py` exposes whole native cells without resampling for personal review. Completion details and cleanup measurement are in `completion.json`.
