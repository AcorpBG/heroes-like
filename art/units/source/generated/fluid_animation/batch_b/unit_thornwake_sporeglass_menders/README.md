# Sporeglass Menders H3 production animations

Published 209 original extracted frames: move 40, melee attack 36, ranged 33,
defend 22, hit 23, support 23 and death 32. The original reviewed eight-frame
240 ms articulated idle and overworld PNG remain pixel-exact. Dead holds the
final grounded death frame. The 3584 x 3968 atlas uses 56,885,248 RGBA bytes.

The medic retains two arms/legs, split ivory coat, green scarf/tunic, medicine
pouches, single brass/amber sprayer, connected hose and strapped reservoir.
Melee frees the right fist while the left hand supports the weapon, then regrips.
Ranged aims and recoils with both grips intact. Support calmly raises and checks
the instrument without firing. Defense ends in a one-knee protective guard;
hit recoils and recovers; death kneels and collapses into a grounded corpse.

Reviewed all 868 chronological frames of the seven selected videos, enlarged
hands/equipment, loop seam, contact/collapse phases and trimmed hold joins,
then every selected phase plus original idle in native Godot battle rendering.
A preliminary shorter walking selection was rejected as a half-cycle; the final
40-frame cycle retains both near/far legs through complete support phases.
The first ranged video generated a bright projectile during meaningful recoil;
it is rejected intact. A dry mechanical drill prompt corrected that behavior in
ranged_v2. The game retains sole ownership of projectile rendering.

All eight takes retain original MP4/FFV1 videos, sampler latents, guides, prompts,
seeds, workflow/history records and original frame hashes. Matting uses a stable
blue plate with foreground chroma protection, original coordinates and one fixed
anatomical scale. No painted motion, per-frame alignment or interpolation.
Selections record exact source indices and deliberate gameplay retiming/hold trims.
Unselected mattes and duplicate Comfy output are rebuildable and removed after review.

Focused Windows Godot checks passed: candidate 283/283, published live 297/297.
All 209 selected source pixels/anchors and provenance hashes verified; original
idle and map PNG exact; other 231 unit/map rows unchanged. Existing root certificate
and GLES3 MSAA warnings appeared. No continuous video playback, manual game playtest,
full repository suite or Linux execution is claimed.

Rebuild mattes from preserved lossless originals with produce.py process <take>,
then produce.py build <take> and assemble for reviewed selections. Do not resubmit
sampling or recollect deleted Comfy duplicates to rebuild preserved source pixels.
