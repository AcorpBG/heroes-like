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
| Movement | solo_pipeline/move_rigid_phase_v6 | 16 | 672ms | Continuous rolling loop |

144 selected original H3 poses. Eight accepted articulated idle poses are retained.
The ranged selection omits source56-60 around unwanted projectile residue;
release55 and recovery61 contain the clean mechanism. Runtime owns the projectile.

Movement is now accepted from the solo phase-controlled take; the five earlier
movement takes remain rejected. move_v1 unfolds supports and grows stray rods;
move_v2 preserves the body but barely turns its spokes; move_v3 uses a newly
authored wheel-phase guide yet still changes spoke topology without convincing
continuous rotation. Two corrections have failed, so no equivalent prompt retry
was queued. The solo reassessment supplied visibly different eight-spoke phases
at stable axle centers before submitting another take.
The wheel_guide original, exact image-generation prompt and hashes are retained
as source/provenance, not a completed movement animation.

Follow-up control experiments also remain rejected. move_v4 magnifies the
whole input reference twofold (fixed extraction scale0.425) to expose the
wheel detail, but its spokes barely turn. move_v5 translates the carriage
360 source pixels, approximately one wheel circumference, while retaining
the same scale; the wheels still slide instead of rolling. All124 frames
of each and enlarged registered wheel phases were inspected. No movement
frames were selected or published. Originals and guide-placement provenance
are retained. Further equivalent prompt retries are not justified without
reliable wheel-phase control. These failed originals remain intact.

Focused Windows Godot validation:227 candidate,227 mirrored and241 live checks passed,
including Normal/Fast/reduced-motion and presentation/simulation checks.
Native phase review passed, including the new rolling cycle in both facings.
Atlas3432x3752,51,507,456 decoded RGBA bytes. All other231 unit rows and all232
overworld visuals/timing remain unchanged;137 retained action/dead poses were
verified pixel/anchor-exact. A stale Godot texture cache was caught in live
screenshots, refreshed, and checked against the lossless source with Godot's
configured alpha-border processing before repeating live rendering. No Linux
run or manual playtest is claimed. Live roster:193 complete,39 remaining of232.

Further guide repair (2026-09-28): wheel_phase_guides_v2 requested three distinct spoke angles; v3 supplied an enlarged original-wheel reference and explicitly requested a half-spoke turn. Both generated paintings retained essentially the original spoke orientation. They remain rejected guides and were not sent to H3. Original masters, prompts, reference crop and hashes remain preserved.

The 2026-10-01 solo reassessment authored an isolated alternate wheel angle in
wheel_near_control_v4, then two consistent complete carriage phase guides.
solo_pipeline pins those original phases every8frames. It preserves the original
sampler latent before releasing large models and decoding;124 original RGB
frames are losslessly preserved and hash-verified. Selected32..47 are consecutive,
with no wheel warps, padding, interpolation, reversal or per-frame registration.
42ms retains source24fps timing; source48 provides the matching loop phase.

Rebuild the new matte with solo_pipeline/produce.py process move_rigid_phase_v6,
prepare the pending candidate with solo_pipeline/select_solo_move.py, then run
the focused creature fixture and inspect original/native phases before accepting.
Publish only move through tools/publish_fluid_creature_animation.py. Refresh
Godot imports after repacking, run solo_pipeline/verify_imported_atlas.gd, and
run solo_pipeline/verify_solo_move.py --baseline-dir with snapshots of the
prepublication manifest,map,atlas and idle strip. Disposable previews and
validation profiles are rebuilt; original guides,takes,selected mattes and
provenance are retained. Work was completed without subagents.
