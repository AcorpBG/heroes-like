# Graft Matriarchs H3 animations

Original two-armed Thornwake tree archer. Decorative shoulder branch loops are not extra hands. Preserve the ivory crown, amber stones, red bindings, bow and multi-root gait. The accepted eight-frame battle/overworld idle is retained.

Local MiniMax H3 uses original key poses, 960x544, 124 frames at24fps,20 sampling steps and fixed scale0.8 after1.25x guide placement. Sampling preserves its latent before model release and separate tiled VAE decode. Each take retains its prompt, guides, workflow, original latent, MP4, lossless decoded video, per-frame hashes and extraction recipe.

`delivery.json` selects take frames and the melee sequence; `produce.py assemble` rebuilds the handoff. `stage_video.py` is resumable generation tooling. Selected transparent frames are original video samples; unselected mattes can be rebuilt with `produce.py process TAKE`.

Melee uses the valid raise/lower intervals of `attack_v1` around a corrected two-hand shove from `attack_v2`; the unwanted fired bolt is excluded. Ranged excludes source61-62 with an airborne bolt so the game retains projectile ownership. `hit_v1` is rejected for crown smearing and bow loss; `hit_v2` keeps one recoil and recovery. `death_v1` is rejected for reversing head/root orientation; its original frame76 supplies the matching final guide for `death_v2`. That reference frame is retained even though it is not published directly.

Review uses all chronological original frames, enlarged anatomy/edges, joins and offscreen native Godot phases. No continuous video playback, manual game playtest or Linux execution is claimed. Final native acceptance is recorded in the delivery and published provenance.

Published selection: move44, melee53, ranged45, defense20, hit26, support33, death38 (259new frames). Candidate868 and published882 focused checks passed on Windows. Exact source pixels/anchors/provenance and retained idle/map were verified; the other231 unit rows stayed unchanged.
