# Prism Adept H3 animation sources

The existing eight original idle poses (240 ms each) have been reviewed and
retained: both elbows lift and lower the projector, the head and shoulders
follow, and planted boots preserve ground contact. Seven deficient actions
receive separate original H3 footage: movement, physical punch, ranged firing,
hit recovery, held crouch defense, instrument presentation/support and death.

Identity: short brown hair, forehead goggles, exposed face, white/gold split
coat with blue lining, brown satchel, two arms and legs, one gold/blue/violet
prism projector. Right hand normally holds its rear, left supports its front.
Only the physical punch releases the rear grip. No source-baked projectile;
runtime retains shot ownership. Death ends head-left, following the original
side-fall guides rather than the differently oriented alternative corpse.

Guides use the original 512x256 cells, anchor [256,248], fixed magnification
1.25 and extraction scale 0.8. The original opaque green excess is at most 49;
a protected 56 chroma band preserves it while keying the uniform green plate.
Never normalize individual poses or create motion by warping sprites.

Preserve sampled latents before releasing encoder/denoiser/cache and decoding
in a separate tiled VAE pass. Preserve all original videos, prompts, seeds,
graphs, guide hashes, frame times and matte recipes. Review chronological
original frames, enlarged grips/face/alpha edges, joins and native battle phases
before selectively publishing. A generated take is not automatically accepted.

## Runtime memory profile

The initial movement attempt was explicitly cancelled under sustained Windows
GPU memory pressure while other applications were open. Its job/configuration
and interruption history remain. The replacement and subsequent takes reserve
10 GiB for GPU headroom, with partial model offload; original quality settings
and guides are unchanged. Sampling recovered from over 90 seconds per step
to about 5.3 seconds per step. No other user applications were closed.

## Published selection

| Action | Original H3 frames | Duration |
|---|---:|---:|
| Move | 18 | 1530 ms loop |
| Defend | 15 | 750 ms, final guard held |
| Melee punch | 32 | 1485 ms |
| Ranged | 37 | 1710 ms |
| Support | 19 | 1120 ms |
| Hit | 23 | 920 ms |
| Death | 52 | 2340 ms, final corpse held |

196 original video frames are published. The eight original 240 ms idle poses
and existing overworld idle pixels remain exact. The 3120x3840 atlas preserves
anatomical scale and every selected source pixel (47,923,200 RGBA bytes).

Attack/ranged v1 contained unwanted flashes and are rejected. Their v2 takes
use an inactive-instrument physical brief and preserve both legitimate hands.
Hit v1 supplies only clean impact frames36..44; its opening beam and abrupt
recovery are excluded. Endpoint-only hit_recover_v2 supplies gradual recovery.
Support omits the unwanted pulse67..71 and joins the same clean raised pose
to its original lowering motion. Death combines corrected standing-to-kneeling,
the original kneeling-to-side-fall interval and corrected elbow/shoulder descent;
the two abrupt v1 transitions are excluded. All originals remain preserved.

Full chronological original-frame review, enlarged grips/anatomy/alpha edges,
gait seam, inter-take joins and every native battle phase were inspected.
Continuous video preview was unavailable; this is not a manual gameplay test.
Windows focused candidate checks: 270 passed. Published checks: 284 passed.
Original-pixel/anchor/provenance verification passed for all 196 new frames;
idle pixels/timing and the other 231 catalog and overworld rows remain exact.
Existing host certificate-store and GLES3 MSAA warnings did not fail checks.
No full repository suite or Linux execution was performed.

Rebuild missing mattes from each preserved lossless video with `produce.py
process <take>` (honoring the hit extraction interval), then `produce.py build
<take>` and `produce.py assemble`. The delivery file owns cross-take timing.
Per-take handoffs record the source-review stage; the root delivery and final
review.json files record the final native acceptance. Unselected mattes, task
review/validation outputs and hash-verified Comfy duplicates are disposable.
