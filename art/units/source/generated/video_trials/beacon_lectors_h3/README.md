# Beacon Lectors H3 originals

Replace deficient movement, melee, ranged, defense, hit, support and death for
`unit_embercourt_beacon_lectors`. Preserve the reviewed eight-pose articulated
idle, its hand/cloth movement, anatomical offsets, timing and overworld artwork.

Identity: brown-haired human woman, exactly two arms/two legs, ivory/red split
robes and mantle, silver kneepads, brown boots/gloves, keys and scroll case.
Right hand at screen left holds one straight bell-staff with one iron bell and
one hanging amber lantern; left hand is free for invocation or joins the lower
shaft for melee/guard. Preserve attachments and rigid shaft throughout. Corpse
rests head left, boots right, staff lying beside her with bell/lantern left.

Existing registered runtime poses provide original key-pose references. Each
source rectangle, anatomical anchor, fixed scale and source hash is recorded.
960x544, 124 original frames at 24 fps, 20 res_multistep/simple steps, local
MiniMax H3 FL2VA int8 ConvRot / Qwen3-VL 32B NVFP4 AWQ / int8 video VAE. Extraction
uses .8 and anchor (480,480); uniform green absent from her palette is keyed by
measured alpha unmix/despill, preserving detached solid components. No body
normalization, synthesized interpolation, reversal or duplicate frame padding.

`produce.py prepare/submit/collect/process/build TAKE` retains immutable API
workflows, prompts, guides, seeds, original lossless frames and viewing video.
`delivery.json` selects reviewed takes; `produce.py assemble` builds a pending
candidate. Review complete chronological originals, enlarged anatomy/equipment,
alpha, seams and actual Godot battle/map size before selected publication.

Published all seven replacement actions after coordinator visual review on 2026-09-25:

| Clip | Selected original frames | Runtime duration |
| --- | ---: | ---: |
| Move | 30 | 1260 ms |
| Ranged | 24 | 1200 ms; release 600 ms |
| Cast | 24 | 1320 ms; support contact 770 ms |
| Defend | 10 | 600 ms; hold final upright two-handed brace |
| Death | 29 | 1450 ms; final pose is persistent corpse |
| Hit | 15 | 825 ms |
| Melee | 38 | 1520 ms; contact 440 ms |

Selections retain 170 original H3 frames. Original idle (eight poses) and
overworld PNG remain exact. Move uses one complete
cycle (4-33); ranged excludes whole frames50-55 containing an unwanted beam,
with a brisk palm extension at the runtime-owned release. Defend retains the
valid initial two-handed brace in v2 (0-36), excluding the later distorted
horizontal rotation. Hit v3 uses positive body-motion instructions to avoid
unwanted objects and effects generated in v1/v2. Long holds are deliberately
trimmed for gameplay tempo, preserving observed action order and articulation.

Melee combines 16 valid startup/strike frames from attack v1 with 22 original
recovery v5 frames. The complete v1 recovery remains rejected for shortening the
staff; v2 spins/bends and v3 equipment morphs remain rejected. Two newly generated
original intermediate poses in recovery_guides_v4 control the short return arc,
preserving the bell shell, lantern cage, grips and straight shaft. Their exact
prompt, references and fixed source scale are retained. No reverse playback,
duplicate padding or synthetic in-between frames are used at the join.

Recovery v4 sampled successfully but its untiled VAE decode stalled under GPU
memory pressure. Only that job was interrupted. Recovery v5 reused verified
uploaded guides and the cached sampler result, with tiled decoding (512/64
spatial, 16/4 temporal) completing in 29 seconds. The recipe verifies existing
input hashes or restores the exact missing uploaded filename after cleanup;
rebuilding does not require the transient server input files to survive.

Reviewed all 124 chronological frames for every take, enlarged equipment,
anatomy, alpha edges and cycle joins, plus native Godot battle-size phases and
map idle. No continuous video playback or manual playtest is claimed.
Candidate244 + live258 = 502 focused checks passed; no full suite. Published
atlas3840x4080, 62,668,800 RGBA bytes. Verified unrelated catalog rows unchanged,
all previously accepted clips pixel/offset/timing exact, and candidate/live
atlas hashes equal. Windows Godot4.6.2 offscreen;
no Linux execution claim. Known root-certificate/GLES3-MSAA warnings are nonfatal.

All lossless originals, viewing videos, exact prompts/workflows, guide images,
source hashes and selected RGBA remain. Disposable previews, unselected mattes
and hash-verified Comfy duplicates are rebuildable from those retained originals.
Roster after this slice:117 complete,1 partial,115 remaining of232. Goal active.
