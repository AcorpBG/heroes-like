# Kilnwall Wardens animation source

Forty-eight original painted poses replace seven clips: idle 8, attack 8, hit 4,
defend 4, support 8, death 8 and movement 8. The support clip is a physical poker signal,
not an invented spell. Both crew members, the rigid three-slot furnace pavise
and the right crew member's poker remain identifiable through each action.

`prepare.py` rebuilds `handoff.json` from original pixels with explicit body
seeds, detached dropped-poker seeds, ground anchors and one anatomical scale
per source. The original reference is an unscaled crop; its lineage is recorded
in `identity_reference.json`. `generation.json` retains every original master,
exact prompt and reference hash, including rejected proposals.

`move_step_together_v1.png` supplies all eight movement poses. The crew use a
deliberate heavy-load shuffle: a leading foot advances, the trailing foot catches
up, both transfer the load in a narrow feet-together stance, then step out again.
This is a step-together carrying gait, not a reciprocal marching cycle. It keeps
the original shield and low carrying stance with articulated knees, ankles and
load-bearing elbows. The fixed source scale is 0.71; no per-pose resizing is used.

All other `move*.png` files are **unaccepted proposals**, excluded from the
handoff. They repeat an extended leg, look like hopping or fail to preserve
the requested leg ownership. Preserve these original masters and prompts as
production provenance; do not count them as additional accepted frames.

All seven clips were reviewed using the focused Godot battle-128/map-64
render workflow, including the overworld idle strip. No full suite or gameplay
change is part of this content batch.
