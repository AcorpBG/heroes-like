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
`delivery.json`. Selections record observed frame indices and gameplay timing.
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

## Published partial delivery

| Action | Original frames | Frame duration | Total duration |
| --- | ---: | ---: | ---: |
| Move | 20 | 83 ms | 1660 ms |
| Attack | 24 | 45 ms | 1080 ms |
| Defend | 18 | 50 ms | 900 ms |
| Hit | 20 | 50 ms | 1000 ms |
| Support/cast | 26 | 50 ms | 1300 ms |

108 original frames across five accepted actions. Melee contact is at 495 ms;
support peak at 700 ms. Eight accepted articulated idle poses retain their
exact pixels, offsets and 240 ms timing. The overworld PNG is byte-identical.
Legacy death pixels, offsets and timing are also unchanged, but that action
is not accepted as meeting the new quality goal. All other catalog rows are
unchanged. Candidate and production atlas hashes match exactly.

Death remains unresolved: v2 still breaks the spear in frames 39-40. v3 removes
intermediate guides, but fades/occludes the shaft behind the torso in frame 35
before it reappears in the foreground in 36-38. Three original takes are kept;
none is published. After two unsuccessful corrections, stop this setup. A new
pass needs explicit anatomy-matched guides for the rigid spear lowering arc,
with a visible grip and coherent equipment release; do not simply reroll seeds.

The 3040x3264 atlas uses 39,690,240 decoded RGBA bytes. Focused offscreen checks:
172 candidate and 186 live passed. Native battle-size phases and overworld idle
were visually inspected. Original chronological frames supplied transition
review; continuous video playback and a manual playtest are not claimed.
Live roster: 115 complete, 2 partial, 117 remaining of 232. The overall animation
goal remains active. No full repository suite was run.

Original videos, generated guides, prompts, workflows and selected transparent
frames are retained. Unselected mattes and task-only review renders, logs,
profiles and hash-verified duplicate Comfy exports are rebuildable/disposable.
