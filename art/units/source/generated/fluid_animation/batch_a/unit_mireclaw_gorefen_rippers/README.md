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
