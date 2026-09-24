# Local video creature animation trials

## Heartseed Warden

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


## Antlerloom Striders: GPT6-Luna High production trial

One explicitly authorized Luna/high worker attempted the seven required actions for `unit_thornwake_stagknot_runners_veteran`, which had no accepted animation overhaul. Six actions were published after substantial coordinator review and correction. Support remains unfinished; this is a partial creature delivery, not autonomous full-creature completion.

| Published clip | Observed frames | Hold per frame |
|---|---:|---:|
| Idle / overworld idle | 16 | 125 ms |
| Move | 26 | 42 ms |
| Attack | 17 | 70 ms |
| Hit | 12 | 60 ms |
| Defend | 10 | 70 ms |
| Death | 16 | 83 ms |

The corpse uses the final grounded death frame. Source anatomy uses one fixed scale and ground anchor; the 3696 x 3864 battle atlas stays below the 4096 texture limit. Frames are observed video samples, without synthetic interpolation, reversal or duplicate padding. The source directory is `art/units/source/generated/video_trials/luna_antlerloom_full`; `prepare_h3.py` records action-specific guides and validates submitted wiring, while `process_h3.py` extracts transparent frames and rebuilds the candidate from `selection.json`. Published provenance and the reviewed handoff are under `art/animation/source/fluid/unit_thornwake_stagknot_runners_veteran`.

Twelve H3 renders produced 1,488 original frames, taking about 24 minutes 49 seconds in the generation service, excluding guides, extraction, review, correction and integration. Originals, captured workflows, prompts and guide hashes remain preserved, including rejected generations. All decoded source-frame hashes were independently verified. Video source directories are excluded from Godot import through `.gdignore`; only published runtime textures need engine import.

Coordinator interventions included correcting latent wiring, inconsistent guide scale, alpha noise, slow gameplay timing and attack contact (source frame 56, rather than 72). Rejected attempts included scale growth, an unsuitable changing background, damaged head/antlers and an unwanted detached hit object. The accepted hit interval begins after that object disappears. Idle, gait, attack recovery, held guard and grounded collapse were reviewed in chronological native-scale phases, with alpha edges checked on light and dark backgrounds.

Support is the explicit remaining gap. The first cast changed face/antler identity; subsequent casts lacked a clear rally gesture. Luna also twice failed to dispatch the requested original-ready-only guide plan: the captured final workflow still contained the generated midpoint. The helper was corrected afterward, but that intended guide plan has not been rendered or accepted. Captured historical workflows remain unchanged. This trial supports using Luna with close technical and visual supervision; it does not establish unattended reliability or a general model ranking.

Focused Windows candidate checks passed 161 assertions; published live-asset checks passed 165 after Godot import, including battle poses, timing modes, corpse persistence and overworld idle frames. No full repository suite, continuous manual playtest or Linux execution is claimed. Temporary contact sheets, validation renders, logs, profiles and unselected extracted PNGs are disposable and rebuildable from the retained source/tooling. Cleanup retained all twelve lossless originals, original MP4s, guides, provenance and 97 selected transparent frames; removed previews and unselected extractions can be rebuilt with the per-action process command.


### Coordinator follow-up: completed support

The coordinator continued solo after the Luna trial. A fourth support render (`cast_v4`) actually used the intended two original-ready endpoints with no generated midpoint; the captured submitted graph and its hashes verify that wiring. Generation took 123.857 seconds. The new result preserves the face and four-legged identity through a planted chest/head lift, proud antler rally hold and return to ready. Every one of the 124 chronological frames was inspected, followed by enlarged alpha and native battle-scale phases. Seventeen observed frames were selected and retimed proportionally to 1500ms; reduced motion holds the rally peak. RGB-only residual magenta removal leaves alpha unchanged. No continuous manual game-playback or Linux validation is claimed.

All seven core actions are now accepted for Antlerloom Striders. This completion belongs to the coordinator follow-up, not the Luna trial. The previous six clips retain all their pixels, frame counts, timing and anatomical anchors; the overworld idle texture and anchor are unchanged. All 114 packed poses were compared against their original transparent sources. To fit them without shrinking the creature or dropping frames, the packer reclaims asymmetric empty padding and records `pose_anchor_x`; battle rendering, mirrored enemies, persistent corpses and map extraction honor it. The complete atlas is 3888 x 3640 (56,609,280 RGBA bytes), slightly smaller than the former six-action texture.

Focused Windows checks passed 188 candidate assertions and 192 published assertions after import, including horizontal anchor equivalence in both facings. No full suite was run. `selection_full.json` rebuilds the completed set; `selection.json` preserves the original partial trial selection. Historical rejected attempts remain original provenance. Temporary render/review outputs and unselected extracted PNGs can be rebuilt from the preserved lossless source.
