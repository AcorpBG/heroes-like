# Aurora Ballista H3 originals

Six deficient actions for `unit_aurora_ballista` are replaced while retaining
the eight accepted articulated idle poses and map playback. The original unmanned
machine keeps its navy/ivory/gold chassis, gold-spoked wheels, hinged outriggers,
two iridescent crystal bow limbs, gold strings, central rail and tall rear lens
housing. Melee uses the armored front ram; ranged uses mechanical bow release;
support uses relay calibration. Runtime projectile behavior is unchanged.

Local MiniMax H3 FL2VA int8 ConvRot, Qwen3-VL32B NVFP4 AWQ and H3 video VAE;
960x544,124 original frames at24fps,20 res_multistep/simple steps. Each take
preserves exact model names, prompt, seed, registered guide hashes, submission
and history, original MP4, lossless FFV1 and all decoded RGB frame hashes.
Reference rectangles/anchors come from the existing packing.json. Legacy
scale0.72 and accepted idle scale0.60734 retain original machine size through
fixed extraction scale0.85 and anchor(480,475), including tilted/fallen poses.

The uniform green plate is absent from the original machine palette. Extraction
measures corner color, rejects unsafe variation, unmixes/despills edges and keeps
every alpha>=8 component containing alpha>=128 pixels. Detached wreck parts and
thin strings are retained. No frame-wise resizing, warps, synthetic articulation,
interpolation or duplicated frame padding is used.

Rebuild mattes with `produce.py process TAKE`, selected handoffs with `build TAKE`
and the combined candidate with `assemble`, using delivery.json. selection.json
records exact original frame indices, timestamps and deliberate retiming.
`review TAKE` creates disposable chronological sheets. Originals are retained,
including any rejected take; only selected transparent frames are shipped.

Review covers all chronological originals, enlarged mechanism/alpha details,
loop boundary and native Godot battle/map-scale phases. Continuous video
playback and manual playtesting are not claimed. Only focused offscreen checks
are used, never the full repository suite.

## Selected production actions

| Action | Original take | Frames | Playback | Contact |
| --- | --- | ---: | ---: | ---: |
| Attack | attack_v1 | 25 | 1125ms | 810ms |
| Ranged | ranged_v1 | 24 | 1200ms | 700ms |
| Defend | defend_v1 | 14 | 700ms | Held final brace |
| Hit | hit_v1 | 17 | 680ms | Recoil then recovery |
| Support | cast_v1 | 22 | 1320ms | 420ms lens peak |
| Death | death_v1 | 26 | 1430ms | Held final wreck |

128 selected original poses. Eight accepted articulated idle poses are retained.
The ranged selection omits source56-60 around unwanted projectile residue;
release55 and recovery61 contain the clean mechanism. Runtime owns the projectile.

Movement remains unaccepted. move_v1 unfolds supports and grows stray rods;
move_v2 preserves the body but barely turns its spokes; move_v3 uses a newly
authored wheel-phase guide yet still changes spoke topology without convincing
continuous rotation. Two corrections have failed, so no equivalent prompt retry
is queued. The remaining work needs clear, physically coherent wheel phases at
stable axle centers. Existing movement is preserved without claiming acceptance.
The wheel_guide original, exact image-generation prompt and hashes are retained
as source/provenance, not a completed movement animation.

Focused Windows Godot validation:196 candidate and210 live checks passed,
including Normal/Fast/reduced-motion and presentation/simulation checks.
Native phase review passed for the six selected actions. Atlas3432x3484,
47,828,352 decoded RGBA bytes. Candidate/live atlas hashes match. All other
unit rows, all eight idle poses and offsets/timing, existing move poses and
offsets/timing, and the overworld PNG were verified unchanged. No Linux run
is claimed. Live roster:112 complete,1 partial,120 remaining of232.
