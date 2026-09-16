# Battle animation production workflow

Scope: original articulated clips for every authored unit, with consistent
identity, equipment, scale and ground contact. Current roster: 160; visual
acceptance and evidence are recorded in `combat-unit-animation-and-size.md`
and `battle-unit-animation-acceptance.json`.

## Authority and order

The owner approved local raster background removal and edge cleanup, while paid
image APIs remain unauthorized. Use the built-in image-generation workflow for
new paintings. Preserve originals and exact prompts/reference hashes. Never
synthesize missing poses with transforms, geometry or procedural recoloring.

Finish generation/refinement/integration in complete batches, then run consolidated
tests and platform exports. Do not test/export after each pose. Production
previews guide art choices but are not gameplay acceptance. Prepared, packed,
integrated and visually accepted remain distinct states.

## 1. Pose design

Use one fixed original identity painting and explicit anatomical/action constraints.
For ambiguous opposite steps, a pose diagram can be the primary edit target and
the original painting the costume reference. `tools/battle_pose_guide.py`
produces authoring diagrams only; those pixels never become game assets.

State near/far limb ownership, equipment count, weapon grip and contact mechanics.
Do not use the last moving frame as the next identity anchor: that accumulated
drift and repeated the same lead leg. Repeated wording-only retries do not solve
a structural ambiguity. Change the reference mechanism, record the exact remaining
gap, and continue a different complete-unit batch if it still fails.

Rigid walkers can use one fixed planted reference with individually painted foot
lifts interleaved with planted contact. Preserve each hip/knee/foot chain, torso
position and equipment. Rootcrown's four-hoof sequence uses explicit limb identity;
Emberpack/Tunnelmark use fixed travel anchors and separate near/far lifts.
A chain carrier needs a gathered travel hold clear of the leg sweep.

Inspect release mechanics: sling cords open; fired crossbow strings relax;
loaded travel/melee stays distinct from unloaded recovery. Preserve scale of
weapons relative to head/torso, not merely the presence of a weapon-shaped object.
A guard needs a visible grip and complete shield. Death retains owned equipment,
and the final corpse/wreck is a distinct persistent pose.

## 2. Raster preparation

Inspect actual alpha on contrasting backgrounds before rejecting or modifying it.
`tools/prepare_battle_pose_cutouts.py --inspect-source` exposes composites.
Some generated alpha peaks at 254 rather than 255; preserve it without opaque
normalization. A painted checkerboard in RGB is not transparent alpha.

Prefer a viable original plus deterministic owner-approved matte removal over a
generative extraction that changes anatomy. Preserve original canvas/layout and
interior paint. For pale materials on neutral backgrounds, choose an absent vivid
chroma color without reflected spill; never automatically key a character color.

Recipes declare bounded thresholds and explicit protected regions/seeds.
`color_distance` uses bounded RGB distance with int32 arithmetic.
`all_keyed_is_background` is an inspected opt-in for enclosed apertures, not a
global default. Protect legitimate pale cloth, steel, fur, ropes and detached
equipment. Component statistics help locate crop boundaries but do not authorize
discarding owned paint. Record failed originals separately from selected sources.

## 3. Deterministic assembly

`tools/pack_unit_pose_art.py` only crops, uniformly downsamples and anchors
selected existing pixels. Recipes preserve source hashes and selections.
Never independently fit every pose's silhouette to a bounding box: lifted feet
and extended weapons must not change the body's size.

Runtime frames are 512x256 with explicit atlas columns/indices. Carry the recipe's
`ground_margin` into `pose_ground_margin`; anchor the anatomical line, not the
transparent canvas bottom. Source-left paintings use explicit
`pose_source_facing`; facing reflection is rendering, not a newly authored pose.

`tools/battle_pose_preview.py` shows grounded clips at gameplay scale.
One-shot clips follow action progress (normal events currently 700ms); looping
idle/move clips use authored frame cadence. Keep a ready-to-brace transition
non-looping and hold its final frame. Reduced motion uses the informative static
frame. At least two distinct painted frames are required for animated states;
the persistent dead state may have one.

Inspect the complete atlas for neighboring fragments, clipped extremities,
equipment drift, silhouette/ground discontinuity and matte contamination.
Review the full gait, attack/recovery, guard/hit, collapse and corpse together.

## 4. Gameplay acceptance

Use real battle snapshots/events, both facings, translated movement and queued
enemy reactions. Inspect 1920x1080 action samples and 1280x720 idle/dead samples.
An unobscured corpse fixture is necessary because a survivor may legitimately
occupy and visually cover the casualty's freed cell.

Fast/reduced headless tests use controlled observation clocks and label that
scope. Rendered tests retain real clocks. A screenshot taken after an event
expires is a capture failure, not automatically an art defect: retain the failed
report, inspect actual elapsed time, and use one focused unchanged replay.
Do not retry until green or weaken assertions.

After visual inspection, record each atlas and pose-metadata hash in
`docs/battle-unit-animation-acceptance.json` and update manifest review status.
Tests reject stale acceptance after art, clip, facing or ground changes.
Acceptance metadata itself does not alter gameplay or prove future changes.

## 5. Sources, packaging and cleanup

Keep source/generated paintings, alternatives, selected cutouts, packing recipes,
hashes and provenance under `art/animation/source/`; only runtime atlases ship.
Each unit's `provenance.json` and referenced generation records explain exactly
what was selected or rejected. Do not rewrite historical rejected drafts as
successful generation.

Keep Linux/Windows payloads equal except platform configuration. A metadata-only
review refresh can reuse previous playback evidence only after comparing complete
package payloads and proving all actual art, compiled owners and runtime pose data
unchanged. Fresh package startup/body checks must still read current metadata.

Use bounded task-owned evidence directories and supervised long-running probes.
Do not confuse a tool observation timeout with a terminal engine process.
Temporary exports/prefixes can be removed only after exact ownership, retention
and active-handle checks; retain caches, original art, saves and required evidence.

Detailed former production notes remain in
`.artifacts/battle-unit-animation-size-20260913/full-roster-validation-20260916/workflow-notes-before-closure.md`.
They describe historical attempts and counts, not current acceptance.
