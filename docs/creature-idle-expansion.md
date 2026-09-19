# Expanded creature idle loops

Owner-selected visual follow-up, 2026-09-19. This first batch replaces two-pose
idles with eight original painted poses on six common neutral creatures, shared
by battle and overworld. The other 154 units retain their existing idle artwork.

| Creature | Frame duration | Motion |
| --- | --- | --- |
| Roadwardens | 240 ms | Breathing, attentive head movement, cape settling |
| Fenhound Runners | 210 ms | Breathing, ears, blink and tail-tip movement |
| Sunscale Lanternmoths | 130 ms | Articulated wingbeat and antenna/leg follow-through |
| Fenmirror Gallowshells | 270 ms | Braced shell movement, claws and hanging bells |
| Rootcrown Knotstags | 240 ms | Head lift, breathing, leaves and suspended pods |
| Gloambell Wake Mantas | 180 ms | Fin undulation and trailing lantern tendrils |

All battle stacks now use a stable identity-specific idle phase, including the
existing two-frame roster. Selecting a stack does not reset that phase. Event
clocks for movement, attacks and reactions keep their existing behavior.

## Art and integration

The built-in image-generation tool painted six eight-pose sheets. Exact prompts,
reference hashes, generator output identifiers and review notes are stored in
`art/animation/source/poses/<unit_id>/idle-v2/generation.json`. Original RGBA
sheets remain beside them as `original.png`. The tool does not expose a model ID.

`prepare.json` and `tools/prepare_idle_pose_alpha.py` rebuild `alpha.png`, clearing
only inspected near-transparent noise at alpha 0–8. RGB and stronger alpha are
preserved. No recoloring, deformation, duplicated stills or synthesized poses.

Each unit's main `packing.json` retains all prior frames and appends eight new
idle drawings. One scale per creature and explicit anatomical anchors preserve
grounding; individual poses are never stretched to their bounds. The previous
recipe is retained in `idle-v2/previous-packing.json`. Existing action frame
pixels and all non-idle clip metadata remain unchanged.

The unit animation manifest selects the appended frames in the existing battle
atlases. `tools/pack_overworld_creature_idle.py` extracts the same frames into
compact strips with a shared crop/ground anchor. No additional runtime animation
system, gameplay fields or RMG changes are required. Restarting the client uses
the new art on existing maps and saved battles; map regeneration is unnecessary.

## Focused review

All 48 drawings were inspected, including at 74px map scale and on the live
1280×720 Windows battle board in both facings. The updated
`tests/overworld_creature_idle_regression.py` passes 444 checks: eight distinct
rendered map poses, all eight live battle frames, independent timing, reduced
motion, fog removal, stable map command caching and unchanged saved simulation.
PNG compression is deferred until after battle sampling so it cannot hide
frames from the observer. Initial capture sampling and a fixture indentation
error were corrected before the final passing run.

Per-unit acceptance in `battle-unit-animation-acceptance.json` records the six
new atlas/pose hashes separately from the prior roster review. That distinction
does not claim the other 154 units received new artwork. Source packing and
registered acceptance checks cover the changed content. No full suite, Linux
export, package build or full-match playtest was run. Windows import produced
sandbox certificate/editor-settings warnings; the final runtime had no script
or shader errors. Temporary captures, logs and profiles are removed after review.

Rebuild a unit with `tools/prepare_idle_pose_alpha.py <prepare.json>`, then
`tools/pack_unit_pose_art.py <packing.json> <runtime atlas>`, followed by
`tools/pack_overworld_creature_idle.py`. Re-run focused playback with
`tests/overworld_creature_idle_regression.py --godot <executable> --output <task directory>`.
