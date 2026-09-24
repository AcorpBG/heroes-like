# Heartseed Warden: local video animation trial

Owner-requested comparison against the accepted painted idle. After reviewing the trial, the owner selected local MiniMax H3 as the main workflow for all creature animations. The trial candidates themselves do not replace live game assets or increase the accepted-unit count.

## Result

Both local MiniMax H3 trials produced a 124-frame, 960x544 video at 24 fps. The first used the same accepted pose at both endpoints; the correction also constrained frame 61 with the accepted raised-shield pose. Generation took **128.672 seconds** and **128.254 seconds**, respectively, on the installed RTX 5090 configuration. These times exclude extraction/review and do not establish a fair end-to-end speed comparison with the previous painting workflow.

| Property | Accepted painted idle | H3 video-derived candidate |
|---|---|---|
| Frames and native duration | 8 poses, 1.24 seconds | 124 original frames; 62 extracted samples at 12 fps, about 5.17 seconds |
| Articulation | Clear authored shield/staff beats | Many smaller changes between poses, including wrist, shield and leaf motion |
| Identity/equipment | Reviewed original staff and shield | Both attempts grow an unwanted glowing lower staff tip; guided attempt also overshoots shield elevation before settling into its guide |
| Grounding | Authored anatomical anchors | One fixed anchor and scale; opaque bottom stays within one source pixel, without stabilization |
| Transparency | Original generated alpha | Magenta key, edge unmix/despill and isolated key-noise cleanup; fine edges still need temporal review |
| Game format | Live accepted atlas | Candidate packs and renders; 65 focused Windows assertions pass |
| Acceptance | Remains live | Rejected for production replacement because equipment changes mid-cycle |

The guided result is closer to the intended later poses, but it does **not** solve the prop defect. An extra endpoint or midpoint alone does not guarantee identity throughout the intervening frames. Use H3 as the owner-selected primary generation route, with original painted poses as guides and visual rejection before publication. The updated `heroes-creature-animation` skill covers action-specific endpoint/midpoint planning, extraction, matting, review and integration. Walking, attacks, death, continuous in-game playback and Linux execution have not been established by this idle trial; each new action still needs its own review.

## Reproduce

The local installation is `H:/ai/minimax-h3/ComfyUI`, using `H:/ai/envs/minimax-h3/python.exe` and `http://127.0.0.1:8189`. The tool accepts a different Python environment with Pillow, NumPy, SciPy and PyAV and a configurable ComfyUI URL; it does not activate conda or assume Windows for processing.

`tools/trial_video_creature_animation.py` provides `prepare`, `submit`, `status`, `collect` and `process`. Use `--output` for a new directory and `--mid-guide` on `prepare` for the correction. Submission refuses a busy queue and an already-submitted directory. It does not install models, stop other jobs, publish catalogs or start a visible game.

Installed model: `minimax_h3_fl2va_pruned_int8_convrot.safetensors`; Qwen3-VL-32B NVFP4/AWQ text encoder; INT8 H3 video VAE. Both trials use seed `24092484`, 20 `res_multistep` steps, `simple` schedule and the ordinary model, without the turbo LoRA. No audio decoding or soundtrack is included.

Sources and exact prompts/workflows are under `art/units/source/generated/video_trials/heartseed_h3_idle` and `heartseed_h3_idle_guided`. Each includes the accepted input provenance, original MP4, decoded RGB originals in lossless FFV1, extracted RGBA PNGs, candidate handoff, and side-by-side animated comparisons at original and doubled candidate playback speeds. Original accepted timing remains 155 ms per pose in both comparisons. Frame extraction does not synthesize, reverse, warp, stabilize or resize individual poses independently.

The magenta matte is appropriate to this creature's green/brown/ivory/amber palette. It is not a general segmentation model for creatures with magenta body parts, detached projectiles, smoke or translucent effects. The connected-subject cleanup is specific to this single-body idle. Opaque reference round-trip error is about 1.69 RGB levels and 2.85 alpha levels out of 255; that check measures the matte on its known input, not semantic correctness of generated video.

The guided candidate's complete atlas is 28,510,720 uncompressed RGBA bytes versus 24,440,832 for the accepted complete atlas (packing layout also changes). Both fit the existing 4096 limit. Neither passing packing checks nor having more frames establishes smooth or correct animation. Source and ordered native phases were inspected; the comparison files provide temporal playback for owner review. No continuous manual game-playback or full-suite result is claimed.
