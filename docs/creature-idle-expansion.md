# Expanded creature idle loops

All **160 creatures** now use reviewed eight-pose idle loops in both battle
and overworld. This delivery repaints 155 loops with 1,240 original drawings;
the other five retain their previously reviewed eight-pose artwork.

## Motion direction

Armed creatures use visible elbow bends, wrist turns, grip adjustments and
equipment movement at normal game size. Their heads and planted feet stay
comparatively quiet. Creatures without hands use motion appropriate to their
anatomy: wingbeats, claw curls, foreleg weight shifts, tail sweeps or articulated
mechanisms. Siege crews work their controls without firing.

Preserve identity, limb ownership, equipment, stance and a continuous loop.
No attack, walking cycle or transformed still substitutes for painted poses.
Most armed loops use 240 ms per frame, heavy creatures 260 ms, and the final
flying creatures 200 ms.

## Production and runtime

The built-in image-generation tool painted the original poses; it exposes no
model ID. Exact prompts, reference hashes, source hashes and review notes live
under `art/animation/source/poses/<unit_id>/idle-v2/`.
`hands-generation.json` identifies the selected artwork. Original and
superseded sources remain preserved, including anatomy and clipping corrections.

`hands-prepare.json` and `tools/prepare_idle_pose_alpha.py` clear only inspected
alpha noise at 0-8, preserving RGB and stronger alpha. Packing recipes record
explicit source rectangles, one uniform scale and anatomical anchors.
Stepped boundaries retain long weapons and tails without neighboring fragments.
Flying bodies and moving forepaws use stable anatomical origins so their motion
does not recenter the whole sprite. Each loop retains all eight paintings.

`tools/integrate_unit_idle_poses.py` appends candidate poses while checking every
previous frame's pixels, then registers matching battle and overworld clips.
Integration alone does not grant acceptance. Retained previous recipes make
refinement repeatable. Production packers remain `tools/pack_unit_pose_art.py`
and `tools/pack_overworld_creature_idle.py`.

Both surfaces play the same paintings. Existing action clips, independent idle
phase, reduced motion, fog and ground anchors are preserved. The Heliograph
Ballista's missing source-facing metadata was corrected after inspecting its
original action paintings; both battle sides now aim toward their opponent.

Restart the client to load the new artwork on existing maps and saved battles.
Map regeneration is unnecessary.

## Focused validation

All 1,240 new drawings were inspected at small and larger sizes. Twenty-eight
Windows playback cohorts covered all 155 changed units on the real 1280x720
battle board in both facings and the overworld shader at 74px extent.
A further single-unit run verified the ballista facing correction.

The 29 focused runs passed 344-444 checks each: eight rendered frames,
independent timing, reduced motion, fog, cached drawing and unchanged saved
simulation. Two selected Python registration/acceptance checks also pass.
Every delivery preserved previous action pixels and non-idle clip metadata.
The final 41 atlases rebuilt byte-identically; all 576 prior frames in that
delivery matched their previous pixels.

Per-unit acceptance hashes and scope are recorded in
`battle-unit-animation-acceptance.json`. No full suite, Linux export,
package build or full-match playtest was run. Successful Windows runs had the
known certificate-store and GLES3 MSAA warnings, with no script/shader failures.

Task-owned captures, logs, contact sheets and isolated profiles are removed
after review under the owner retention policy. Original art, recipes,
provenance, source and rebuild tooling remain available.

To reproduce a selected loop, prepare its alpha, run the main packing recipe,
then extract the overworld strip. For focused playback, pass one to six unit IDs
to `tests/overworld_creature_idle_regression.py --godot <executable>
--output <task directory> --units <unit IDs>`.
