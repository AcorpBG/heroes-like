# Quenchbell Ironbacks production sources

One original armored quadruped, four hoofed legs, a single large brass bell horn,
small head horns, red shoulder gauges, layered dorsal steel/brass plates and
short tufted tail. Neutral T7 melee; Bellhorn Ram and Red-Gauge Run. Support is a
physical horn bow and foreleg paw, with no human hands or invented spell effects.
Preserve the reviewed eight original idle paintings and exact 260 ms map timing.

`prepare.py` preserves original sheet crops/scales, registers original guide
hoof/body contacts once and translates the legacy sheet 94 video pixels to align
the original largest shoulder gauge with accepted ready12. All videos share
960x640, extraction scale 0.5 and ground anchor [480,576]. Do not normalize,
stabilize or shift individual generated frames by their bounding boxes.

`run_generation.py sample/decode <take>` retains H3 latents before separate
tiled VAE decoding. Run each complete GPU stage through
`tools/creature_animation_lock.py gpu -- ...`, including terminal completion
waits, unload, matting and Godot rendering. Other assigned units share this GPU.
CPU guide preparation, hashing and visual inspection can proceed concurrently.

Preserve original MP4/FFV1/latents, all 124 decoded RGB hashes per take, exact
prompts/workflows/seeds/guides, model/code recipes and failed attempts. Local
`segment.py` uses pinned BiRefNet-matting and keeps source RGB/coordinates with
soft plate-edge unmixing. No environment changes are needed.

Spatial source plates use nearby confidently excluded background RGB for soft
edge unmixing. `edge_despill.py` separately removes measured green/magenta excess
only within two original pixels of the matte boundary. Exact alpha and every
interior RGB pixel remain unchanged; all original guides fall below its 24-point
threshold (green maximum 12, magenta 19). The complete original semantic extraction
recipe is retained. Movement selects one coherent original 0-51 gait cycle;
later repeated cycles with unwanted red illumination remain in the source video.

Candidate clips remain pending until personal chronological, enlarged, native,
reflected and actual action review passes. `run_native_review.py`,
`run_mirrored_native.py` and `capture_clock.py` observe the actual draw region
without changing game timing. `verify_delivery.py` checks source pixels and
anchors, preserved idle and map art, and non-target catalog rows. Imported
atlas RGBA is checked separately. Offscreen fixtures are not a manual game
playtest or continuous video playback; no full-suite/Linux claims are implied.

Publish only this UID while holding the shared content mutex and reading current
catalogs. Refresh the non-target expected rows from that current snapshot,
preserving the original own-unit baseline. Git staging/commit/push uses separate
Git mutex and indexed HEAD with only this unit replaced. Preserve unrelated
work, other workers, originals, caches, saves, backups and all RMG material.
Remove only task-owned inactive disposable reviews/logs/profiles and proven
Comfy duplicates/unselected rebuildable mattes after verified completion.

Support v1 is retained but rejected for its held forward hoof and final-frame snap. Support v2 adds original ready-pose recovery guides at76/104, with the same camera, scale and model settings. paired_actions.json joins this correction to the queued death lease without restarting its continuous waiter; run_actions.py still enforces at most two actions per lease.

The completed delivery selects move27, attack41, hit32, defend23, support34
and death46 original poses, preserving the existing eight-pose idle. The compact
3392x3696 atlas preserves every selected source pixel and anatomical anchor.
All868 original RGB frames from seven takes remain in lossless sources.
Candidate699, reflected699 and live713 focused assertions passed, together with
exact imported RGBA, original battle/map idle and other231 catalog-row checks.
Every211 candidate, reflected and imported/live pose was personally inspected,
plus24 actual normal-facing ram captures and live map idle phases0/3.
`completion.json` records the finished unit and measured cleanup. The roster
goal remains in progress. Continuous video playback, manual game and Linux
validation were not performed.

`run_live_review.py` imports just this UID's battle and idle textures in a
disposable two-raster Godot project. An isolated editor profile prevents writes
to the user's normal editor settings. Existing texture options are preserved;
the newly imported atlas is compared pixel for pixel before live rendering.
