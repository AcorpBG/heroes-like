# Sluicefire Lindworms H3 originals

Replace deficient movement, melee, hit, support, defense and death for
`unit_embercourt_sluicefire_lindworms`. Preserve its existing eight-pose idle
after review of the shifting lower coils, tail curl and neck; keep its original
pixels, timing, anatomical registration and overworld strip unchanged.

Identity: one legless serpent, one angular dragon head, one continuous charcoal
scaled body and hooked tail, ivory dorsal plates, dark iron bands and contained
orange furnace vents. No arms, legs or wings. This is the base creature, not its
Veteran design. Support is a physical raised-neck hiss, not invented spellcasting.

Registered original atlas poses provide guides. Each rectangle, belly-ground
anchor, fixed scale and source hash is recorded. H3 uses 960x544, 124 frames at
24 fps, 20 res_multistep/simple steps, local MiniMax H3 FL2VA int8 ConvRot,
Qwen3-VL 32B NVFP4 AWQ and the int8 video VAE. Tiled decode uses spatial512/64
and temporal16/4 to bound memory. Extraction uses scale .8, anchor (480,480)
and a measured green plate absent from the creature palette. Preserve detached
solid details; never normalize frame size, synthesize motion or reverse frames.

`produce.py prepare/submit/collect/process/build TAKE` preserves the exact API
workflow, prompts, guides, seeds, lossless decoded originals and viewing video.
`delivery.json` selects accepted takes; `produce.py assemble` starts pending.
Review full chronological originals, enlarged anatomy/alpha, action joins and
native Godot phases before selected publication. Phase review is not continuous
video playback or a manual playtest. Failed takes remain original provenance.

Published six replacement actions after coordinator review on 2026-09-25:

| Clip | Original frames | Duration |
| --- | ---: | ---: |
| Move | 30 | 1560 ms |
| Attack | 23 | 1035 ms; contact540 ms |
| Defend | 12 | 660 ms; final held guard |
| Hit | 16 | 640 ms |
| Support | 22 | 1210 ms; peak605 ms |
| Death | 23 | 1495 ms; final persistent corpse |

126 selected H3 frames complement the eight preserved idle poses. Movement
uses one complete traveling-coil cycle. Attack excludes whole original32..49
frames containing an unwanted expelled beam; the retained31-to50 contact and
closing-jaw join was reviewed enlarged and at native scale. Nothing was painted
over or erased. Three settled defense/death hold samples were omitted to fit
the atlas, preserving all transition phases and the final persistent poses.
Long stationary lead-ins and holds are trimmed and retimed for battle response.

Reviewed all744 original phases chronologically, enlarged identity/coil/jaw/
armor/alpha on light and dark grounds, and all selected native Godot phases.
No continuous video playback or manual playtest is claimed. Candidate198 and
live212 focused checks pass (410 total), without the full suite. Windows
Godot4.6.2 offscreen only; no Linux execution claim. Existing root-certificate
and GLES3-MSAA warnings are nonfatal.

Atlas3996x3900 uses62,337,600 RGBA bytes. Candidate/live atlas hashes match.
Verified original idle pixels, offsets and timing, overworld PNG bytes, and
every unrelated catalog/idle row unchanged. All originals, exact workflows,
prompts, guides, lossless pixel hashes, recipes and selected RGBA remain.
Disposable previews, unselected mattes and verified Comfy duplicates are
rebuildable from retained sources. Generation queue empty; models unloaded.

Roster118 complete,1 partial,114 remaining of232; overall goal remains active.
