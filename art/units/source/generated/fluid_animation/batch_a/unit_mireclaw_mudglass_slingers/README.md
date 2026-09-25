# Mudglass Slingers H3 source motion

Partial production: the18-frame H3 hit/recovery clip is reviewed and published.
Movement, melee, sling throw, defense, support and death remain in progress.
Preserve the reviewed eight-pose articulated idle and
its map artwork/timing. Replace movement, melee punch, sling throw, defense,
hit, physical rally support and death/corpse with reviewed original H3 motion.

Identity: adult human slinger with long brown ponytail, green face scarf, olive
leather, yellow reed fringe, pale belt charms and brown boots. Image-left hand
owns the single two-cord leather sling; image-right hand is free and loads it.
The runtime owns the flying projectile. No painted duplicate projectile.

Original older action poses use one fixed scale of 1.03 to match the newer idle
body (220 versus 226 pixels in the ready references). All extracted frames use
scale 0.8 and ground anchor [480,480], including the corpse. No per-frame size
normalization, reversed frames, artificial interpolation or synthesized poses.
The saturated green guide plate is separated from original olive material;
the 32-unit protected foreground band preserves opaque clothing colors.

configure.py defines original pose guides and action briefs. Submitted take
folders are immutable. stage_video.py saves the original sampled video latent,
releases encoder/denoiser/cache, then decodes separately with VAE. Models/settings:
local MiniMax H3 at 960x544, 124 frames/24fps, 20 res_multistep/simple steps,
256/64 spatial and 16/4 temporal tiled decoding. Preserve videos, latents, prompts,
guides, hashes and source-frame provenance for accepted and rejected takes.

Review is autonomous: chronological original frames, enlarged anatomy/cords/alpha,
loop/segment joins and actual-size offscreen Godot phases. Do not claim continuous
video playback or a manual game playtest from these checks. Focused tests only.

Hit selection: original frames0,4,6,7,8,9,10,12,18,24,62,66,70,74,78,82,86,90
at55ms per frame. The long settled hold24..62 is condensed with its join reviewed.
The one-leg move, sling-transferring melee, duplicated-sling throwing interval and
color-cycling defense are excluded. Defense chroma calibration was tested but
left colored edge fringes; it remains rejected. Original failed videos are retained.

Validation for this partial delivery:21 candidate and35 imported-live focused checks
passed. All231 other battle/map rows, unmodified old action pixels, eight idle
paintings/240ms timing and the overworld PNG remained exact; candidate/live atlases
are pixel-identical. Focused offscreen Windows Godot checks only; no full suite.
