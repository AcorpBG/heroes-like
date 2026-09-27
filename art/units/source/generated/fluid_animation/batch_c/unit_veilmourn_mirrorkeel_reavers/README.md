# Mirror-Keel Reavers H3 animation source

Seven dedicated actions are published: 220 selected original H3 frames. The replacement 49-frame idle is shared by battle and overworld. The previous eight-pose idle repeated short arm sweeps with an abrupt reset; its original atlas and baseline remain preserved.

Identity: two arms, two hands, two legs and two clawed feet; right long silver saber, left separate crescent boarding hook, dark silver plate, split ivory mask, violet helmet lanterns and torn teal cloth cape. The support action is a physical hook-hand salute, not spellcasting.

| Action | Frames | Frame duration | Playback |
|---|---:|---:|---|
| idle | 49 | 65 ms | loop |
| move | 24 | 65 ms | loop |
| attack | 32 | 40 ms | return to ready |
| defend | 24 | 40 ms | hold final |
| cast | 31 | 45 ms | return to ready |
| hit | 28 | 30 ms | return to ready |
| death | 32 | 45 ms | hold final |

Attack contact is selected index18 (720ms); support contact index17 (765ms). Death's last selected source frame48 supplies the persistent corpse. Selection files record exact chronological source indices and deliberate shortened holds. No duplicated/reversed/interpolated frames or per-frame scale normalization.

## Generation and corrections

Local staged MiniMax H3:960x544,124 frames24fps,20 res_multistep/simple, FL2VA int8 and Qwen3-VL32B NVFP4. Preserve sampled latent, release encoder/denoiser, decode VAE256/64 spatial and16/4 temporal. Green plate, fixed .65 scale and [480,480] ground anchor. Original videos, guides, prompts, workflows, hashes, rejected takes and timestamps remain in this directory.

Attack v1 and v2 add broad opaque white trails and remain rejected. Removing the overhead guide and requesting forward extension in v3 yields a visible raised saber strike; whole source frames35-36 are excluded for interrupted blade shape. Source34-to37 preserves the directed strike without inventing pixels. Hit source18/100 are excluded for blur. Long stationary holds are shortened in attack, support, hit and death. All other actions use their first takes.

`produce.py` prepares, extracts, reviews, selects and assembles. `stage_video.py` preserves original latent then releases large models before VAE decoding. `delivery.json`, per-take `selection.json` and `handoff.json` rebuild the exact selected production frames. Cleaned unused mattes can be rebuilt from the preserved lossless originals with `produce.py process <take>`.

## Review and validation

Autonomous review covered all chronological source phases, enlarged anatomy, grips and alpha, fixed-anchor joins and every selected native Godot phase at128px reference height. Imported battle and overworld idle were inspected. No continuous video playback, manual game playtest, Linux or full-suite claim.

Focused Windows Godot4.6.2 candidate729 and imported-live733 checks passed. Exact source pixels, anatomical offsets, timings, contact indices and provenance hashes verified; all other231 battle/map records remain unchanged. New map idle exactly matches the battle idle. Battle atlas3644x3232,47,109,632 RGBA bytes at original body scale. Current live roster143 complete/89 remaining; overall goal remains active. Pre-existing Windows certificate-store and GLES3 MSAA warnings persist without animation check failures.
