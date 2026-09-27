# Furnace Pavis Teams H3 animations

Six dedicated H3 actions: move60, attack44, defend25, hit39, support42 and death44 (254 new frames). Preserve the original eight-frame260ms battle idle and identical overworld pixels. The near right hand retains one long hook-pole; the far left forearm carries the full-height iron-and-brass furnace shield.

Local MiniMax H3 uses original pose guides, 960x544,124frames at24fps,20steps and fixed extraction scale0.8 after1.25x guide placement. Each original sampler latent is saved before releasing large models and running a separate tiled VAE decode. Prompts, guides, workflows, seeds, originals, lossless decoded video, hashes and matte recipes are retained.

Walking selects the first reciprocal gait cycle, including the far boot passing behind the shield. Melee raises and drives the intact pole forward and recovers. Defense lowers into a held brace; hit recoils and returns; noncaster support lifts and re-seats equipment. Death folds onto the near side, head left and legs right, with pole in the foreground and shield on the body. Long stationary holds are trimmed; selection files record original frame indices, contact phases and deliberate gameplay timing. No synthetic interpolation or duplicate padding is used.

Run `produce.py process TAKE` to rebuild unselected mattes, `produce.py build TAKE` to rebuild its selected handoff, and `produce.py assemble` for the combined delivery. `stage_video.py` preserves and resumes generation. Review covered all chronological originals, enlarged anatomy/equipment/alpha, gait seam and every native battle phase. Continuous playback, manual playtesting and Linux execution were not performed.

Candidate845 and published859 focused checks passed on Windows. All254 selected pixels/anchors, provenance, original idle/map and the other231 unit records were verified. The3000x3688 atlas is44,256,000 RGBA bytes.
