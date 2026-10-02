# Seedglass Cantors production sources

Seven original MiniMax H3 actions supplement the retained, personally reviewed
eight-frame articulated idle. The initial death take is retained but rejected
for two abrupt pose changes; `death_h3_v2` uses original start/end guidance.
The original lossless video, RGB frame hashes, MP4, latent, model/runtime
profile, prompts, guide images and submitted workflows remain preserved.

To rebuild deleted unselected intermediate mattes, run `produce.py process`
with each take name in `delivery.json`, then `select_reviewed.py` and
`produce.py assemble`. Run these with Python containing Pillow, NumPy, SciPy
and PyAV. Each recipe re-extracts observed original video pixels; it does not
create motion, interpolate, reverse frames or normalize poses individually.

The ranged selection excludes original frame37 where the outgoing arrow still
touches the bow. Frames38-45 separate only the detached arrow across a verified
empty vertical gap; the game owns its flight. Whole original videos remain
unaltered. Clips use deliberately shortened holds and recorded frame timing.

`run_native_review.py`, `run_mirrored_native.py`, `run_ranged_native.py`,
`verify_imported_atlas.gd` and `verify_delivery.py` reproduce the focused native
and preservation checks. `completion.json` records the verified delivery and
cleanup. Disposable reviews and profiles are rebuilt from these sources.
