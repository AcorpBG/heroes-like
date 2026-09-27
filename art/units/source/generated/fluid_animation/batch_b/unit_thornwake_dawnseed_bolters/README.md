# Dawnseed Bolters H3 animation

Seven dedicated H3 actions are published with 248 selected original frames. The original eight-frame articulated idle is preserved, including its exact timing, anchors and overworld strip. Review was performed autonomously on chronological original frames, enlarged anatomy/equipment details and every native Godot phase at the actual 128px reference height.

| Action | Original frames | Timing | Reviewed behavior |
|---|---:|---:|---|
| Move | 42 | 55ms | Reciprocal root-foot gait, both hands retain crossbow |
| Melee | 52 | 30ms | Right fist windup, extension and regrip; left hand supports crossbow; contact index 29 |
| Ranged | 34 | 40ms | Loaded aim, release, recovery; contact index 14 |
| Guard | 20 | 45ms | Knee/hood tuck and raised crossbow, terminal held brace |
| Hit | 31 | 30ms | Torso recoil, original shed leaves, return to ready |
| Support | 33 | 40ms | Physical raised-fist rally and regrip; contact index 12 |
| Death | 36 | 50ms | Knees, forearm and shoulder descend into a grounded corpse |

The persistent dead pose is the exact last death frame. Timing deliberately shortens source holds without reversing or interpolating motion. Fast arm intervals retain consecutive originals. Ranged source frames 32-37 contain an outgoing bolt and are omitted whole across a coherent held-body boundary; the live game owns the projectile. No anatomy pixels were erased to hide that effect.

## Sources and rebuilding

Each version keeps its FFV1 original with all 124 decoded RGB hashes, MP4, sampler latent, exact prompt/workflows, seed, guide paintings and original-pixel lineage. Guides use the original legacy atlas at one anatomical scale, with 0.65 video extraction and a fixed [480,490] anchor. No per-frame scaling, reversal, interpolation or synthetic articulation.

`stage_video.py` preserves sampling before releasing encoder/denoiser/cache and decoding the original latent. `produce.py process TAKE` rebuilds disposable mattes from the FFV1; `review TAKE` creates temporary chronological sheets; `build TAKE` uses the recorded original frame selection; `assemble` combines delivery takes. Never resubmit or overwrite a preserved original.

The original foliage's measured opaque green chroma peaks at 104. Green-plate extraction protects 110 while retaining the existing corner-spread and chroma-separation gates. All confidently opaque disconnected components remain, including naturally shed leaves. `palette_review.json` records measured source hashes. Inspect native edges; mathematical separation is not visual acceptance.

## Rejected takes and corrections

- Move_v1 changes its magenta plate to yellow/green; strict extraction stops. Move_v2 uses the measured green palette.
- Attack_v1 holds and snaps between ready, windup and punch. Attack_v2 turns the crossbow into a large vertical longbow and fires a shaft. Controls were reassessed: three separate exact-endpoint v3 videos provide continuous windup, punch and regrip with visually matched joins and the original crossbow throughout.
- Defend_v1 and cast_v1 cycle the blue background. Their v2 corrections use the green palette. Cast_v2 incorrectly fires a crossbow shot; cast_v3 replaces the aiming guide with the original raised-fist pose and produces a physical support gesture.
- Death_v1 jumps from an upright kneeling torso into the corpse. Death_v2 removes intermediate kneeling/corpse holds and requests the complete fall.

Source and native reviews are chronological original frames, enlarged details and Godot phase renders. Continuous video playback, a manual game session, the full repository suite and Linux execution are not claimed.

Focused candidate/live validation: 835/849 checks, no failures. Headless import succeeded. The native run emitted the existing Windows root-certificate-store and GLES3 2D-MSAA warnings. Exact integration verification matched all 248 source frames, 99 provenance hashes and all 257 candidate/live poses (including retained idle and dead). Other 231 creature records and the complete overworld catalog/strip are unchanged. The 3776x3192 atlas stays within the 4096 limit at the reviewed anatomical scale.
