# Ash-Oath Bailiffs H3 originals

Six deficient actions for `unit_embercourt_ash_oath_bailiffs`, preserving eight
accepted articulated idle poses and exact overworld artwork. Original female
human with dark tied hair, ivory/red cloak, silver lamellar armor, dark trousers,
brown boots; exactly two arms and legs. One straight hooked spear in the weapon
hand; one tall wood/steel pavise in the opposite arm. Preserve both grips, the
brass ring and chain, and rigid shaft length. Support is a physical salute,
not magic. Death lays the body, shield and spear down continuously.

Original pose-packing scales are retained; fixed extraction scale 0.8, anatomical
anchor (480,480). Local MiniMax H3 FL2VA int8 ConvRot, Qwen3-VL 32B NVFP4 AWQ,
video VAE, 960x544, 124 original frames at 24 fps, 20 res_multistep/simple steps.
Full API graphs, exact prompts, seeds, guide hashes, lossless FFV1, viewing MP4
and 124 decoded original pixel hashes are preserved per take. Uniform green
absent from the original palette is keyed through measured alpha unmix and
edge despill, retaining all disconnected solid subject components.

Rebuild using `produce.py process TAKE`, `build TAKE` and `assemble` with
`delivery.json`; rebuild the death composite with `assemble_death.py` after
restoring its selected source mattes. Selections record exact indices and timing.
Review covers all chronological originals, enlarged anatomy/equipment/grips,
alpha and cycle boundaries, then native battle-scale phases. Continuous video
playback and manual playtesting are not claimed. Focused offscreen checks only.

## Targeted corrections

Attack v1 disconnected the spearhead and bent the shaft during recovery. v2
added an original valid angle guide, but still bent the pole between guides.
v3 changed control strategy to first/last ready images only: its continuous
windup, forward/downward strike and recovery retain a rigid hooked spear.
The attack_v1 frame 17 remains as the historical v2 guide, not a runtime frame.

Hit v1 held the ready/recoil paintings and snapped between them. Hit v2 spreads
the action over the source duration and supplies gradual recoil and recovery.
Support v1 invented a blade at the blunt spear butt. Its frame 49 was corrected
with imagegen; support v2 uses that guide and preserves the blunt brass end.

Death v1 disconnected the weapon while falling. Death v2 introduces a kneeling
guide that lowers the spear onto the foreground before the body tips. The new
guide was generated from the original kneeling pose; v1 lacked the hook, v2
restored it but had an overlong shaft, and v3 shortens the shaft while retaining
the kneeling anatomy, grip and registration. Only v3 guides death v2. All
original corrected artwork and exact prompts/reference hashes are retained.

## Published complete delivery

| Action | Original frames | Frame duration | Total duration |
| --- | ---: | ---: | ---: |
| Move | 20 | 83 ms | 1660 ms |
| Attack | 24 | 45 ms | 1080 ms |
| Defend | 18 | 50 ms | 900 ms |
| Hit | 20 | 50 ms | 1000 ms |
| Support/cast | 26 | 50 ms | 1300 ms |
| Death | 52 | 45 ms kneeling, 40 ms lowering/fall | 2120 ms |

160 original H3 frames across six accepted actions. Melee contact is at 495 ms;
support peak at 700 ms. Eight accepted articulated idle poses retain exact
pixels, offsets and 240 ms timing. The overworld PNG is byte-identical. This
follow-up replaces only death; the five previously published H3 actions retain
exact pixels, offsets and timing. All other catalog rows are unchanged.

## Death correction and selection

Full death v2 breaks the spear in frames 39-40. v3 fades/occludes the shaft
behind the torso in frame 35 before it reappears in the foreground. Neither
full take is accepted. Only v2's valid standing-to-kneeling prefix is reused.
After the two failed corrections, the control strategy changed: supply explicit
60-degree and 25-degree spear guides for a separate kneeling lowering video,
then generate a separate fall starting with that video's grounded spear pose.
The rejected full originals remain available with their rejection records.

`death_lowered_v4` has an overlong shaft and is unused. v5's entire figure was
larger, so it uses one documented source-wide registration scale of .203 and
anchor (834,833), matching the .31-scale angle guides. Video extraction always
uses .8 and anatomical anchor (480,480); no per-frame anatomy normalization.
All corrected guide originals, prompts and hashes are retained.

`death_complete/selection.json` is the authoritative composite recipe:
8 original death_v2 prefix frames, 23 death_lowering_v1 frames and 21
death_settle_v1 frames. Lowering frames 36-64 contain an unnecessary repeated
rotation and are excluded; frames 35 and 65 retain consecutive spear angles
and a coherent grip. The fall retains release, weight shift, shield tipping,
body contact and cloth settling. Prolonged holds and two near-held samples
are omitted. No reversed frames, synthesized in-betweens, warps or duplicate
padding are used. The final corpse is also the persistent dead pose.

Review covered complete chronological originals, enlarged equipment/anatomy,
alpha against light/dark surfaces, interval joins and native battle-size phases.
Continuous video playback and manual playtesting are not claimed.

The first 54-frame death selection exceeded the atlas limit by two poses. The
reviewed 52-frame selection retains scale and fits a 3952x3952 atlas using
62,473,216 decoded RGBA bytes. Focused checks: 226 candidate and 240 live passed;
Godot import succeeded. Candidate and published atlas hashes match exactly.
Overworld idle was visually inspected and verified byte-identical.
Live roster: 116 complete, 1 partial, 116 remaining of 232. The overall animation
goal remains active. No full repository suite was run.

Original videos, generated guides, prompts, workflows and selected transparent
frames are retained. Unselected mattes and task-only review renders, logs,
profiles and hash-verified duplicate Comfy exports are rebuildable/disposable.
