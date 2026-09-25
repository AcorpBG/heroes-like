# Daybreak Colossus H3 sources

Published seven mechanical actions with 168 selected original H3 frames:
move 25, melee attack 23, ranged 25, defend 16, hit 25, support 25, death 29.
The eight original idle poses at 260 ms and overworld PNG are preserved exactly.
Dead holds the final grounded collapse frame.

Original identity: ivory/gold four-legged cannon engine, one rigid purple-glass
cannon, orange sun lens, spoked halo and pale-blue glass fins. No rider or human
arms. Fixed 1.25x guides on 960x544 at [480,480], extracted at 0.8 scale without
per-frame normalization. Green-key foreground protection is 40 chroma units.

Each independent 124-frame/24fps take uses 20 steps with 10 GiB VRAM reserve.
Original sampler latents are saved before model unloading and separate tiled
VAE decoding. Retain lossless source video, MP4, latents, guides, prompts,
model/workflow settings, hashes and source-frame selections. Unselected mattes
can be rebuilt with produce.py process; do not overwrite submitted references.

Reviewed all 868 chronological source frames, enlarged anatomy/alpha edges,
selected joins and all candidate/live native battle phases plus map idle.
Selections remove repeated shots/recoils and long holds, the long ranged beam,
and the blurred collapse-barrel interval. Support is a physical high-cannon
salute; defense remains low and braced; hit recovers to ready. Frame timing is
explicitly retimed in each selection.json. No invented/interpolated poses.

Windows focused candidate 242 and live 256 checks passed. Exact selected pixels,
anchors and provenance were verified; all 231 other catalog rows are unchanged.
Runtime atlas is 3952x3920, 61,967,360 RGBA bytes. Original idle pixels are exact.
Continuous video playback was unavailable through the permitted preview route;
no manual game playtest, full repository suite or Linux validation is claimed.
