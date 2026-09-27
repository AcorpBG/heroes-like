# Scrip Haulers H3 animations

Six dedicated H3 actions: move52, attack40, defend22, hit31, support34 and death32 (211 new frames). Preserve the original eight-frame240ms articulated battle idle and identical overworld strip. Previous flat generated PNGs and prompts predate this pass and remain untouched.

The original brass-armored human holds a curved billhook in the near right hand and a rectangular shield on the far left forearm. Local MiniMax H3 uses original pose guides, 960x544,124frames at24fps,20steps and fixed extraction scale0.8 after1.25x guide placement. Sampling saves its original latent before model release and separate tiled VAE decoding. The interrupted cast decode was recovered from that exact saved latent; both submission records remain preserved.

Each take retains original latent, lossless video, MP4, prompts, guide images, workflows, hashes and matting recipe. Run `produce.py process TAKE` to rebuild disposable unselected mattes; `produce.py build TAKE` and `produce.py assemble` rebuild the selected handoff. `stage_video.py` resumes generation.

Attack frame31 has a disconnected blade and is excluded. The original30-to32 fast strike transition was reviewed enlarged and at native scale. Long stationary holds are shortened, recovery uses recorded timing, and the reciprocal walking cycle is deliberately retimed to32ms per frame. No synthetic interpolation or duplicated padding is used.

All chronological source frames, enlarged grips/limbs/alpha, gait seam and selected native battle phases were reviewed. Candidate716 and published730 focused checks passed on Windows; all211 source pixels and anchors, provenance, original idle and other231 unit records were verified. Continuous playback, manual playtesting and Linux execution were not performed.
