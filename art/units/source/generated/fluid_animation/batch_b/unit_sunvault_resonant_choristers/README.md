# Resonant Chorister H3 animation sources

This original three-person unit keeps its central fair-haired staff bearer,
left brown-haired book reader and right dark-skinned hand-drum player. Each
person retains their own two arms and legs, white/gold/blue clothing, relative
formation and instrument. The staff's sun ring and all instrument crystals
are fixed original geometry, not extra generated projectiles.

Seven separate actions replace deficient movement, melee, ranged, guard, hit,
support and collapse. The reviewed original eight-pose idle is retained: staff
and forearm motion, book presentation and the drummer's hand articulation
remain at the established scale and timing. Support uses a dedicated kneeling
bow and rise rather than a ranged alias. Death uses three original endpoint-guided sections (kneeling, side fall and
settling) to ground all three bodies and the staff, book and drum.

Guides select original 512x256 poses, anatomical anchor [256,248], fixed 1.25
magnification and 0.8 extraction scale. The original opaque green excess is
at most 50; a protected 56 chroma band preserves original materials against
the flat green plate. No per-frame size normalization or synthetic motion.

Production uses the existing H3 service with 10 GiB VRAM reservation, 20 steps,
960x544 at 24 fps and 124 original frames per take. Save each sampler latent,
unload sampling models, then decode through a separate tiled VAE job. Preserve
all original videos, latents, graphs, prompts, guides, seeds and hashes,
including rejected takes. Per-take selections and the delivery file define
the reviewed original frame indices, timing and action joins.

Accepted delivery: 223 original video frames across move12, defend18, hit18,
ranged21, support28, melee49 and death77. The original eight idle frames and
240 ms timing, all ground anchors and exact overworld idle PNG are preserved.
The final atlas is 3228x3216 (41,524,992 RGBA bytes).

Both initial staff-strike attempts spun the staff or enlarged the sun-ring;
they are excluded. The accepted direct extension uses two observed recovery
poses as control guides for newly generated forward motion, followed by a
separately generated recovery. No reversed frames are delivered. Hit retains
only the first clean reaction (original frames0-20); later repeated reactions
and the red-background interval are excluded. Original failed takes remain.

Autonomous review covered every chronological original frame, enlarged
anatomy, equipment, alpha edges, gait seam, segment joins and every native
battle phase. Focused Windows Godot candidate760/live774 checks passed,
including Normal/Fast and reduced motion. All223 delivered frames match the
selected original pixels and anchors; other231 unit rows are unchanged.
Continuous video preview was unavailable; no manual game playtest is claimed.

The delivery file and per-take selections rebuild the accepted clips. All
source videos, sampler latents, prompts, guides, model graphs and hashes are
preserved. Unselected mattes and duplicate Comfy outputs are rebuildable and
removed with disposable review renders after validation.
