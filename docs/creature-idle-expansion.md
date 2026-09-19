# Expanded creature idle loops

Full-roster production is **in progress**, covering both battle and overworld.
86 of 160 units have reviewed eight-pose idles; 74 still retain two-pose loops.
The earlier six-creature delivery did not complete the requested roster.

## Motion direction

Armed creatures need visible elbow bends, wrist turns, grip adjustments and
movement of their equipment at normal game size. Heads, hips and planted feet
stay quiet. Extra frames of head movement alone do not meet this requirement.
Preserve limb ownership, continuous chains, rigid equipment and identity.
No attack, firing or walking motion belongs in the idle loop.

Eighty-one armed units now use this direction: River Guard, Ember Archer,
Citadel Pikeward, Blackbranch Cutthroat, Mire Slinger, Bog Brute, Shard Guard,
Prism Harrier, Mirror Skirmisher, Roadwardens; Embercourt Fordhook Cadets,
Lantern Sappers, Bargebow Crews, Ash-Oath Bailiffs, Beacon Lectors and Charter
Colossus; Mireclaw Reedsnare Kin, Mudglass Slingers, Bogplate Maulers,
Ferrychain Lashers and Sporewake Chanters. Most use 240 ms per frame;
the colossus, mauler, furnace pavis team and Bogbell Mauls use 260 ms for heavier motion.

The expanded roster also includes Sunvault Shard Wardens, Prism Adepts, Mirror
Duelists, Resonant Choristers and Noonfacet Sentinels; Thornwake Seedcutters,
Thornwhip Carriers, Sporeglass Menders and Dawnseed Bolters; Brasshollow Scrip
Haulers, Furnace Pavis Teams and Gaugeplate Bailiffs; Veilmourn Bellwake Oars,
Mourning Lanterns, Maskglass Corsairs, Undertow Harpooners, Obituary Scribes,
Mirror-Keel Reavers and Tidehook Deckhands; Embercourt Cinderseal Bombardiers;
Mireclaw Mireglass Reedcasters; and neutral Hearthbow Carriers, Mossglass
Sentinels and Cliffhawk Wardens.

Neutral production now also covers Windglass Slingers through Bogbell Mauls
(the 36 neutral entries in that manifest range). These include two-person
crossbow crews, polearms, slings, jarriers, shields and pack adjustments.
Reedbarge hooks and Snowglass bow tips use explicit stepped boundaries to
preserve their complete silhouettes without neighboring weapon fragments.

The other five expanded creatures retain their previously reviewed loops:
Fenhound Runners, Sunscale Lanternmoths, Fenmirror Gallowshells,
Rootcrown Knotstags and Gloambell Wake Mantas. Remaining creatures need motion
appropriate to their anatomy, including articulated wings, paws or mechanisms.

## Production and runtime

The built-in image-generation tool paints original poses. Exact prompts,
reference hashes, source hashes and selection notes live under
`art/animation/source/poses/<unit_id>/idle-v2/`. The tool exposes no model ID.
`hands-generation.json` identifies the selected arm-motion artwork; originals
and superseded head-dominant attempts remain preserved. Shard Guard uses one
separately generated correction for a reversed sword wrist in frame four.
Bellwake Oars uses a corrected sheet that preserves the complete oar blade.

`hands-prepare.json` and `tools/prepare_idle_pose_alpha.py` clear only inspected
alpha noise at 0-8, preserving RGB and stronger alpha. `hands-packing.json`
records explicit source rectangles, one uniform scale and anatomical anchors.
Long weapon tips use stepped crop boundaries to avoid cutting into neighbors.
No transformed stills or independently resized poses substitute for paintings.

`tools/integrate_unit_idle_poses.py` appends candidate frames to the existing
atlas, checks every prior frame's pixels survived, and registers matching
battle and overworld clips. The retained previous recipe makes refinements
repeatable. Integration does not grant visual acceptance. Production packers
remain `tools/pack_unit_pose_art.py` and `tools/pack_overworld_creature_idle.py`.

Both surfaces play the same paintings. Existing action clips, independent idle
phase, reduced motion and ground anchors are preserved. Restarting the client
uses the new art on existing maps and saved battles; no map regeneration.

## Focused review

All 648 new arm-motion drawings were inspected at small and larger sizes.
Fifteen focused Windows playback cohorts covered all 81 changed units on the real
1280x720 battle board in both facings and the overworld shader at 74px extent.
They passed 344-444 checks each: eight rendered frames, independent
timing, reduced motion, fog, cached drawing and unchanged saved simulation.
Existing action pixels and non-idle clip metadata remain unchanged.

Per-unit acceptance hashes and review scope are recorded in
`battle-unit-animation-acceptance.json`; this does not accept unfinished units.
No full suite, Linux export, package build or full-match playtest was run.
Windows emitted the known root-certificate and unsupported GLES3 MSAA warnings,
with no script or shader failures. Task-owned captures and profiles are
disposable after review; original art, recipes and provenance are retained.

Rebuild selected alpha, run the main unit packing recipe, then extract the
overworld strip. For focused playback pass one to six unit IDs to
`tests/overworld_creature_idle_regression.py --godot <executable> --output <task directory> --units <unit IDs>`.
