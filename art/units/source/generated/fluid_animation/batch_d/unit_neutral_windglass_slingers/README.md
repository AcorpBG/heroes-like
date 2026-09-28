# Windglass Slingers H3 animation

Published eight dedicated actions: idle 31, move 31, melee 25, defend 21, hit 24, physical support 26, death 34, ranged 30. The 222 selected original frames supply battle animation and the 31-frame overworld idle; the final death frame supplies the persistent corpse. The packed battle atlas is 1728 x 4076 (26.87 MiB decoded RGBA).

MiniMax H3 generated thirteen preserved takes with the installed int8 model and local staged sampling/tiled decoding. The original pose sheet provides identity guides at fixed 0.93 anatomical scale. The corrected built-in image_gen melee key keeps the sling in the low right hand while the empty left fist punches; its master, exact prompt and input hash are in keys/. Guide normalization is source-wide, never per-frame resizing or invented motion.

Selected takes and original indices/timings are in delivery.json and each selection.json. Rebuild with run_batch.py, produce.py process/review/build, then produce.py assemble. Long source holds are shortened for combat timing; dense observed phases retain transitions. Idle lasts 2790ms, gait 1860ms, melee 875ms, defend 735ms, hit 720ms, support 1040ms, death 1190ms and ranged 1050ms. No reversed frames, interpolation or synthetic body warps.

Rejected melee v1 has effects and a changing background; v2 has doubled/floating cords; entry v3 transfers the sling between hands because the inherited contact guide has the wrong grip. Those takes are source-only, including the unused v2 recovery selection. Initial hit/support defects are documented in their reviews. Ranged source frames 56-57 contain an unwanted flying object and are excluded as entire source frames, preserving the clean release and recovery.

Review covered all chronological originals, enlarged anatomy/equipment and light/dark alpha edges, all selected phases at the Godot 128px battle reference size, and the live map idle. No continuous-playback, manual-game or Linux validation is claimed. The unavailable continuous-preview route was not bypassed.

Focused Windows Godot checks: candidate 743 and live 747, both zero failures. Exact verification: 222 original frames, 223 candidate/live poses including corpse, 31 map idle frames, 97 provenance hashes, thirteen take prompts/seeds and 31 guide hashes; all other 231 unit catalog entries unchanged. The full suite was not run. Existing root-certificate/MSAA warnings are unrelated to these passing checks.

Preserve original lossless videos, MP4s, latents, guides, key art, prompts, recipes and failed takes. Unselected mattes, temporary review/test files and hash-verified duplicate Comfy outputs are disposable; required selected mattes remain with the handoff. Rebuild deleted mattes from the original lossless video and recorded extraction settings.
