# Gaugeplate Bailiffs H3 animation

Six dedicated H3 actions are accepted after original-frame and native Godot review. The original eight-pose articulated idle is retained exactly, including its overworld catalog and strip.

| Action | Selected original frames | Timing |
| --- | ---: | --- |
| Move | 42 | 65 ms/frame; 2.730 s loop |
| Attack | 35 | 35 ms/frame; contact at index 16/source 37 |
| Defend | 24 | 45 ms/frame; last guard pose held |
| Hit | 26 | 30 ms/frame; recoil and recovery |
| Support | 30 | 40 ms/frame; salute contact at index 9/source 26 |
| Death | 49 | 35 ms/frame; 1.715 s; final corpse held |

The 206 selected action frames retain original decoded pixels, with fixed matte/extraction settings. Death combines the first 25 reviewed kneeling/leaning frames from `death_v2` and 24 final-descent frames from `death_settle_v3`; exact video indices are in `delivery.json`. It transfers weight through the bent elbow before rolling onto its side. The join uses the same original low-lean guide and avoids duplicating the joining hold. Other clips retain the dedicated reciprocal gait, hammer anticipation/strike/recovery, raised shield, clean recoil and physical hammer salute appropriate to a noncaster.

## Identity and scale

One short, stocky armored humanoid: rounded brass diving helmet and boiler pipes, two blue glass lenses, ribbed brass mask, blue cloth joints and blue/white tabard. The near right hand carries one short, rigid double-ended dial hammer; the far left forearm carries one round brass pressure-gauge shield. Preserve both grips, two arms, two boots and the original equipment geometry.

The older action paintings are larger than the accepted later idle. Every new guide uses the same 0.83 anatomical scale from those action paintings and a fixed 0.5 video extraction scale. The source canvas is 960x544 with anchor [480,490]; no changing-bounds stabilization, per-frame normalization or corpse enlargement. Original idle pixels, timing, offsets and map strip remain unchanged.

Green was selected after measuring every opaque guide: maximum G-minus-max(R,B) is 25. Extraction protects a band of 40 while retaining corner-spread<=10 and chroma-separation>=80 gates. All confidently opaque connected pieces remain; alpha removal does not edit anatomy or repair generated equipment.

## Rebuild

Each take preserves prompt, guide paintings and hashes, seed, sampler/decode workflows, sampler latent, MP4 and lossless FFV1 with all 124 decoded RGB hashes. `stage_video.py` preserves the sampling result before releasing encoder/denoiser/cache and decoding the original latent with a tiled VAE. `run_batch.py` groups unfinished takes in pairs. Do not overwrite originals or resubmit an active job.

`produce.py process TAKE` rebuilds disposable mattes from the original FFV1, `review TAKE` rebuilds chronological sheets, `build TAKE` uses recorded original indices and timing, and `assemble` merges the selected delivery. Publication requires source/anatomy, original-frame continuity and native-scale review. No duplicated padding, reversal, interpolation or synthetic articulation.

Review uses chronological original frames, enlarged details, loop/segment boundaries and Godot phase renders. Continuous video playback, a manual game session, full-suite validation and Linux execution are not claimed.

## Rejected takes

- `hit_v1` invents a luminous incoming projectile and shield sparks in frames 20-35. Recoil begins before the effect clears, so omitting those frames would remove part of the motion. `hit_v2` instead describes the actor's backward balance correction and recovery without an external impact cue.
- `death_v1` grows a bright white patch beneath the gauntlet/body in frames 25-30. `death_v2` adds the original kneeling and leaning paintings, but its late frames 81-92 raise the torso then snap to a corpse with a transient white artifact. Only its valid first descent through frame 76 contributes to the delivery.
- After these failures, the control was changed to a dedicated final-collapse segment, `death_settle_v3`, conditioned only on the original low-lean and grounded-corpse paintings. The resulting support transfer and side-roll is gradual, with intact equipment and no white artifact. All 124 original frames were reviewed chronologically, with enlarged selected details and native-scale selected phases.

Rejected originals and intervals remain preserved and excluded from publication. Selected walking and support footage contains a small original boiler-exhaust wisp, retained without painting or cropping it away.

## Publication verification

The complete candidate passes 272 focused Godot checks and the imported live unit passes 286. All 206 published action poses match selected source pixels and anchors; all 77 bound provenance hashes match; the eight original idle poses and timing are unchanged. The 3536x3876 atlas fits the 4096 limit, and the persistent dead pose equals the last death pose. All 215 candidate/live poses are identical. All 231 other creature records and the complete overworld catalog/strip remain unchanged. Native battle and two overworld idle phases were inspected after import. The Windows certificate-store error and unsupported GLES3 MSAA warning are pre-existing environment messages; no new import or script errors occurred.
