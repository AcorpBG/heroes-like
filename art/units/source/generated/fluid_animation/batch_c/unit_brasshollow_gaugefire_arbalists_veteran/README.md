# Datumline Piercers animation source

Eight clips contain 56 frames: idle, move, melee attack, ranged, physical support
and death have eight each; hit and defense have four each. The support action
is an open-hand signal, with the arbalist supported by the other arm. Melee uses
the same weapon for a two-handed shove; ranged has separate aim/release/recoil.

`prepare.py` records original-pixel crops, ground anchors, fixed anatomical scale
per master, and timing. Reference height remains 256 and standing crest-to-sole
height approximately 234 pixels. No per-pose deformation or size normalization
is used. The nine masters and exact prompts are retained in `generation.json`,
with hashed references. Both reference crops are unscaled and have crop lineage.

The gait combines reviewed far-leg poses from `move_v1.png`, foreground contact
and support from the second/third poses of `move_near_v1.png`, and an original
foreground reach from `move_reach_v1.png`. Unused repeated-leg proposals remain
in the original masters but are excluded from the handoff.

The last two paintings in `ranged_v1.png` grew taller and are excluded. Its final
recovery instead uses two matching original lowered-weapon idle paintings.
These are distinct within the ranged clip: six action poses plus two recovery
poses, with no aliases or duplicate-frame padding. Cross-clip ready-pose sharing
does not count as additional unique paintings.

Native Godot battle/map renders were visually reviewed. Focused checks cover
frame timing, contact, grounding, Fast/reduced motion and unchanged simulation.
No full repository test suite is part of this batch.
