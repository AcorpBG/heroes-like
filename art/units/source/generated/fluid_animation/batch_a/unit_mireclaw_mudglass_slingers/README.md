# Mudglass Slingers H3 source motion

Partial production: hit 18, physical rally/support 17, death 25 plus its final
corpse, and reciprocal walking 20 are reviewed and published. Melee punch, sling
throw and defense remain in progress. Preserve the original eight-pose articulated idle, 240ms timing
and byte-exact map artwork, plus every accepted H3 frame during later additions.

Identity: adult human slinger with long brown ponytail, green face scarf, olive
leather, yellow reed fringe, pale belt charms and brown boots. Image-left hand
owns the single two-cord leather sling; image-right hand is free and loads it.
The runtime owns the flying projectile. No painted duplicate projectile.

Original older action guides use one fixed scale of 1.03 to match the newer idle
body (220 versus 226 pixels in ready references). Extracted frames use scale 0.8
and ground anchor [480,480], including the corpse. No per-frame normalization,
reversed frames, artificial interpolation or synthesized poses. The green plate
uses a 32-unit protected foreground chroma band to retain opaque olive material.

configure.py records the original guides and action briefs. Submitted take
folders are immutable. stage_video.py saves the original video latent, releases
large models, then decodes separately. batch_stage.py can retain model caches
across a sampling batch before a VAE-only decode pass. Local MiniMax H3 settings:
960x544, 124 frames at 24fps, 20 res_multistep/simple steps; tiled decoding 256/64
spatial and 16/4 temporal. Preserve originals, latents, prompts, guides and hashes.

Selections and timing are explicit in each selection.json. Hit condenses the long
settled reaction hold 24..62. Support condenses the chest-level fist hold; death
retains each knee-collapse and side-fall transition while shortening held kneeling
and corpse intervals. Walking uses original frames 40..78 in steps of two, 83ms
per phase, with the 78-to-40 cycle boundary checked against original frame 80.
All selected frames are original observations at one scale.

Rejected sources remain excluded: move_v1 repeats one leading leg; attack_v1
moves the sling into the punching hand; ranged_v1 duplicates the sling during the
overhead interval; defend_v1 cycles background colors. Its calibrated chroma trial
still left colored fringes, so it remains rejected rather than eroding artwork.

Review is autonomous: complete chronological originals, enlarged anatomy/cords/
alpha, segment joins and every packed phase in offscreen Godot at 128px reference
height. No continuous video playback or manual game playtest is claimed.
Hit delivery passed 21 candidate and 35 imported-live focused checks. The combined
hit/support/death candidate passed 67 focused checks; the imported-live delivery passed 81.
Adding movement passed 89 combined-candidate and 103 imported-live focused checks.
Other 231 battle/map rows, all previously accepted pixels and timing, untouched actions
and the map PNG were preserved exactly. The corpse equals the final death frame. No full suite or Linux runtime check was run.
