# Rootcrown Knotstags production sources

Solo MiniMax H3 production uses seven dedicated actions: idle, gait, crown
sweep, recoil, guard, physical rally and grounded collapse. Original guides
preserve the six-legged creature, three attached crown pods, bark and foliage,
camera and fixed anatomical ground reference. Runtime extraction uses one .5
scale for all original frames, without interpolation or pose normalization.

The seven `*_h3_v1` takes are rejected. Their inherited legacy standing and
walking guides depict four legs, contradicting the curated six-legged original.
`prepare_v2.py` replaces those standing guides with the actual curated identity
at one fixed .45 source scale. The `move_h3_v2` trial is reviewed before the
remaining corrected actions are generated. The original grounded corpse may
hide its folded far-side legs; it never guides standing/walking anatomy.

The shared overworld extractor stores idle frames in one horizontal strip.
Idle selection must keep that strip within 4096px as well as the battle atlas;
choose a complete reviewed original motion interval with enough articulated
phases, rather than retaining long nearly static holds just for a frame count.

The original lossless RGB video, hashes, MP4, latent, prompts, guide sources and
submitted model/workflow settings are retained for every take. Pending takes
are not accepted by generation or structural checks alone. `delivery.json`
records the reviewed selected takes and `selection.json` records exact observed
frame indices, timing and contacts.

To rebuild unselected extracted intermediates, run `produce.py process` with
each take, then `select_reviewed.py` and `produce.py assemble`. Rebuilding uses
the retained original video pixels and recorded matte settings.

`run_native_review.py`, `run_mirrored_native.py`, `verify_delivery.py` and
`verify_imported_atlas.gd` reproduce focused playback, preservation and import
checks. Disposable previews, isolated profiles and logs are removed after
review; original sources, accepted frames and caches remain.
