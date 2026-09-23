# Kilnwall Wardens animation source

Forty original painted poses replace six clips: idle 8, attack 8, hit 4,
defend 4, support 8 and death 8. The support clip is a physical poker signal,
not an invented spell. Both crew members, the rigid three-slot furnace pavise
and the right crew member's poker remain identifiable through each action.

`prepare.py` rebuilds `handoff.json` from original pixels with explicit body
seeds, detached dropped-poker seeds, ground anchors and one anatomical scale
per source. The original reference is an unscaled crop; its lineage is recorded
in `identity_reference.json`. `generation.json` retains every original master,
exact prompt and reference hash, including rejected proposals.

The five `move*.png` masters are **unaccepted proposals**, excluded from the
handoff. They fail to show consistent alternating leg ownership for both crew
members; some repeat an extended leg or look like hopping. The last two sheets
explore carrying the shield higher for foot visibility but still do not solve
the reciprocal gait. Do not count these frames or the legacy movement alias as
completed movement. A complete eight-pose two-person walk remains required.

Six selected clips were reviewed using the focused Godot battle-128/map-64
render workflow, including the overworld idle strip. No full suite or gameplay
change is part of this content batch.
