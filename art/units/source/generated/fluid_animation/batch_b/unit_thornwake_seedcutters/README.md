# Seedcutters H3 production animations

Published 144 original extracted frames: move 25, attack 29, defend 17, hit 21,
physical support 22 and death 30. The reviewed original eight-frame idle (240 ms)
and overworld PNG are preserved exactly. Dead holds the final grounded death pose.

The right hand retains its sickle, the left its tied leafy bundle, and the loaded
basket stays strapped to the back. Fixed guide scale and extraction anchors retain
anatomical size; no per-frame normalization, interpolation or painted motion.
Selections and deliberate timing/hold trims are recorded per take.

All 744 chronological source frames of the six selected takes were inspected,
with enlarged grips, reciprocal gait, loop seam and hold joins, followed by every
selected phase at native battle scale and the retained battle/map idle. Continuous
video playback and a manual game playtest were not performed.

The first movement, attack and support takes changed their magenta background
through colors shared by clothing and equipment. They are rejected and preserved.
Their v2 replacements use stable blue plates in all 124 frames per take, with a
measured protected foreground chroma band. Guard, hit and death retain stable
magenta originals. Original videos, sampler latents, guides, prompts, seeds,
workflow/history records, matte recipes and hashes are retained for all nine takes.
Only selected extracted mattes are retained; others can be rebuilt with produce.py.

Focused Windows Godot checks: candidate 210/210; published live 224/224.
All 144 selected source pixels and anchors, provenance hashes and retained idle
pixels were verified; the other 231 unit/map rows were unchanged. Existing root
certificate and GLES3 MSAA warnings appeared. No full suite or Linux run claimed.

Rebuild selected handoffs with produce.py build <take>, then assemble. Matting
can be reproduced from preserved lossless videos using produce.py process <take>.
Do not resubmit generation or recollect deleted Comfy duplicate outputs to rebuild.
