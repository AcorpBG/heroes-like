# Bogplate Maulers H3 movement

Published for `unit_mireclaw_bogplate_maulers`: 31 observed frames (source 0 through 120, every fourth frame), 42 ms each, 1302 ms cyclic travel. The six earlier accepted clips retain their pixels, timing and anchors; map idle is byte-identical. This completes its seven required melee-creature actions.

`produce.py` prepares and audits this unit-specific graph, submits once, reads the existing job, collects lossless originals, removes the background and rebuilds a candidate. It reuses only HTTP/submission/collection utilities from the older Heartseed trial helper; it supplies its own identity, prompt, guide placement, workflow and matte. With a Python environment containing Pillow, NumPy, SciPy and PyAV:

- `produce.py process --attempt guided_v2` rebuilds all transparent samples from the preserved FFV1 source.
- `produce.py review --attempt guided_v2` rebuilds disposable chronological review sheets under `.artifacts/bogplate_move_h3`.
- `produce.py build --attempt guided_v2` rebuilds the selected movement handoff and a temporary combined candidate preserving previous reviewed actions.

The original walk contact source comes from the unit's existing `packing.json`, with original scale 0.17. H3 guides use one fixed 0.36 source scale and anchor (480, 490); extracted frames use 0.17/0.36. This retains the original anatomical reference, rather than normalizing every pose's bounds. Camera, body mass, two-handed hammer grip, shaft and block head remain coherent through alternating boot contacts, bent-knee passing and toe-off.

The initial H3 attempt in this directory was rejected when its background hue cycled through red, orange, yellow and green. The strict magenta matte deliberately stops at source frame 10. Preserve that source; do not relax the extractor to pretend it passed. The built-in image tool then produced two opposite-contact guides: `opposed_contact_v1.png` repeats the original leading-leg stance and is rejected; `opposed_contact_v2.png` moves the near knee behind and provides the far-foot-forward cue. Exact prompts, reference hashes and generated master hashes are in `guide_generation.json` and the adjacent prompt files.

`guided_v2` uses that corrected midpoint at source frame 61, original matched endpoints, local MiniMax H3, 960 x 544, 124 frames at 24 fps, 20 steps and `res_multistep`. Captured API graphs and generation histories identify actual models, seed, uploads and prompt ID. The first render took 116.611 seconds; the corrected render took 118.344 seconds. Neither timing includes reference generation, extraction, review or integration.

All 124 corrected source frames were inspected chronologically, with enlarged anatomy/equipment and alpha on light/dark backgrounds, then native battle-size phases. The loop seam was visually near-matched; its premultiplied pixel difference was about 0.057 versus 0.163 median adjacent-frame difference (supporting evidence, not a substitute for review). Alpha extraction checks a uniform magenta plate, unmixes color, removes residual magenta RGB spill and discards only disconnected low-alpha key noise. It does not shift, warp, interpolate or reverse poses.

Validation: 129 focused Windows candidate assertions and 143 published assertions after Godot import. All 248 original decoded frames across both H3 attempts were hash-verified against captured source PNGs. The original videos, workflows, prompts, guides, provenance and 31 selected RGBA frames remain; unselected extractions and test/review outputs are rebuildable. No full repository suite, continuous manual playtest or Linux execution is claimed.
