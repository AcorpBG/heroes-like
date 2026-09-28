# Cliffhawk Wardens H3 animation

214 original MiniMax H3 frames replace all seven battle actions. The 31-frame idle also supplies the overworld strip; the final death frame supplies the persistent corpse. The original human fighter, two-handed hooked pike, feather mantle and shoulder hawk remain the identity reference.

| Action | Accepted take | Frames | Frame duration |
|---|---|---:|---:|
| Idle | idle_h3_v2 | 31 | 90 ms |
| Move | move_h3_v2 | 31 | 40 ms |
| Attack | attack_h3_v2 | 31 | 35 ms |
| Defend | defend_h3_v1 | 20 | 35 ms |
| Hit | hit_h3_v2 | 28 | 30 ms |
| Physical rally | cast_h3_v2 | 30 | 40 ms |
| Death | death_h3_v1 | 43 | 35 ms |

Attack contact is selected index 16, original video frame 48, at 560 ms. Walking retains one complete reciprocal cycle. Idle articulates both forearms with a restrained pike adjustment. Rally raises the pike with both hands; this melee creature does not cast visual magic. Death includes the hawk taking off, a forearm brace, side fall and grounded final pose. Long source holds are shortened without reversing, duplicating or synthesizing frames.

## Originals and corrections

Each take preserves its original lossless decoded video, MP4, sampler latent, exact prompt, guide images, immutable sampling workflow/history, decode workflow and hashes. `selection.json` records exact video indices and runtime timing; `produce.py` recreates mattes and candidate handoffs. `delivery.json` selects the reviewed takes for `produce.py assemble`.

The initial idle and walk changed weapon geometry; the first attack invented a projectile; the first hit changed metal/feather colors with the plate; the first rally had unsafe mixed-background intervals and weak action. These five rejected originals and their reviews are retained. Only guard and death use their first takes.

Built-in image generation supplied the original midpoint art used for idle and rally. Exact prompts are in `matched_keys_prompt.txt`, `opposite_key_prompt.txt` and `rally_key_prompt.txt`; corresponding original PNGs and `.generation.json` records are retained. The attempted walking-key paintings repeated the same leading leg and are not used as walking guides. The accepted walk instead uses one consistent original pose with a matched first/last guide and no conflicting intermediate camera guide.

H3 settings: local FL2VA int8 ConvRot, Qwen3-VL 32B NVFP4, int8 VAE, 960x544, 124 frames at 24 fps, 20 res_multistep/simple steps. Sampling latents are saved before unloading large models and tiled VAE decoding. Accepted corrections use a fixed green plate. One anatomical scale per source painting and a fixed extraction scale retain the original body size; rally uses 0.6 extraction instead of 0.5 to fit its raised blade in the video canvas. No frame-specific body normalization.

## Review and verification

Coordinator reviewed all original frames chronologically, enlarged anatomy/grips/hawk/alpha on light and dark backgrounds, and all selected native Godot battle phases. Published battle and overworld samples were inspected. This is not a claim of continuous video playback, a manual game playtest or a Linux execution.

The final focused candidate check passed 709 assertions and the published check passed 713. A preliminary four-action native check passed 140; its 125 poses remained pixel/anchor-identical in the final candidate. All 214 selected original frames, 215 candidate/live poses including the corpse, 31 battle/map idle frames and 83 provenance hashes matched. All other 231 battle entries and overworld entries remained unchanged. All 12 immutable takes and 29 guides passed source checks. The atlas is 3968x2376, 37,711,872 RGBA bytes. Hit timing was corrected to the existing 30 ms minimum before publication; validation rules were unchanged. No full suite was run.

Task-only contact sheets, logs, test profiles, unused reproducible mattes and hash-verified Comfy duplicates are disposable. Original/generated art, videos, latents, prompts, selected source frames, provenance and caches are preserved.
