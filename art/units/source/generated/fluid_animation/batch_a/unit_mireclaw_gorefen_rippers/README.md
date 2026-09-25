# Gorefen Rippers animation sources

Target: `unit_mireclaw_gorefen_rippers`, the Mireclaw T6 quadruped, distinct from
`unit_gorefen_ripper`. Preserve the existing eight-frame articulated idle and its
260 ms timing. Six separate MiniMax H3 takes supply movement, melee, hit,
defense, physical support and death; candidates require visual and native review.

Identity: one long-snouted grey-brown crocodilian, four clawed legs, one curled
tail, red dorsal/tail spines, tan rope harness and ivory bone ornaments. The
forelegs and head face right; hindlegs are left. No weapon, rider or magic.
Support is a planted rally roar. Death ends head-right with all limbs and tail
grounded. Near/far paw contacts must remain distinct throughout movement.

`configure.py` records original atlas indices and fixed anatomical anchors.
The 960x544 guides magnify the original by 1.25; extraction uses 0.8, preserving
the original body scale without normalizing poses by their bounds. The original
opaque palette has maximum green excess 64; the initial protected band of 72 retained visible green boundary spill.
Enlarged light/dark review selected band 32 in `extraction_settings.json`; this
unmixes plate contamination while retaining fine original geometry. The source
configs and videos remain unchanged. Alpha review remains required per take.

`stage_video.py` preserves the original sampled latent, unloads the large models,
then decodes it in a separate tiled VAE job. `produce.py` retains lossless decoded
frames, exact timestamps, hashes, source recipes, prompts and pending handoffs.
Submitted takes are immutable. Selection/review files record accepted intervals
and any exclusions; successful generation alone does not authorize publication.

## Published selection

All required clips are accepted: retained idle 8 (260 ms), movement 42 (65 ms),
defense 16 (45 ms with a 120 ms final hold), support 22 (65 ms), death 25 (60 ms),
attack 26 (45 ms, contact 14) and hit 21 (35 ms). The corpse uses the final death
frame. `delivery.json` records chronological source segments and deliberate retiming.

The first melee take grows during its lunge: only its anticipation and recovery
are used. The second supplies the stable strike; its snapped onset/recovery are
excluded. The first hit take has insufficient recoil; the second has abrupt
transitions and supplies only the endpoint guide at frame 32. Separate endpoint-only
recoil and recovery footage supplies the published hit. Original failed videos
and latents remain preserved; no reversal, interpolation or synthetic articulation.

539 candidate  and 562 imported-live focused checks pass, including every attack
pose through the actual battle shell, recovery/input locking and presentation
speeds. All 152 selected H3 poses match their packed pixels and anatomical offsets;
original idle/defense/movement and the map PNG remain exact. Other 231 catalog/map
rows are unchanged. The compact atlas is 3568x2960 (40.29 MiB RGBA). Review used
complete source frame chronology, enlarged edges/joins and native phase rendering;
no continuous video-player inspection or manual game playtest is claimed.
