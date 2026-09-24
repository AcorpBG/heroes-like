# Citadel Pikeward H3 originals

The six deficient battle actions are replaced with original MiniMax H3
motion. The existing eight accepted hand/shield idle paintings are preserved.
The pikeward remains a melee creature; ranged stays an attack fallback, not a
claimed new ranged weapon. The support gesture is a physical military salute.

Identity: red-plumed steel helmet, ivory scarf, red quilted armor, teal tabard,
steel greaves, brown boots, one long hooked pike with red tassel and one angular
red/ivory/teal wave shield. The near hand holds the pike; the far arm bears the
shield and can support the shaft during a thrust. Exactly two arms/two legs.

## Production

Local ComfyUI MiniMax H3 FL2VA int8 ConvRot, Qwen3-VL 32B NVFP4 AWQ and H3 video
VAE generate 124 frames at 24fps, 960x544, 20 res_multistep/simple steps. Each
action has its own exact workflow, prompt, seed, guides, submission/history,
MP4 viewing copy, lossless FFV1 original and decoded RGB hashes. Original image
generation supplied the open-stride and salute guides; `key_guides/generation.json`
records all image masters, references and prompt hashes, including the excluded
first stride proposal.

All videos use a uniform green plate absent from the subject palette. Historical
`guide_*_magenta.png` names identify upload slots, not their actual plate color.
The extractor measures the plate, rejects unsafe gradients/color separation,
unmixes alpha, removes only disconnected plate noise without confidently opaque
pixels, and retains detached original equipment. No anatomy reconstruction,
frame interpolation, whole-sprite bob, ping-pong or duplicate-frame padding.

Reference paintings use their original anatomical scales; generated guide
registrations match the same body scale. Every video frame uses fixed 0.65
extraction scale and (480,475) anatomical anchor. Crouches and corpses are never
normalized to standing height. The old hit recipe was cropped around a stray
neighboring pike tip in the empty gap between its boots; both actual boots remain.

Legacy walking contacts repeat a leading-leg phase. An original generated open
stride replaces the repeated midpoint, with reciprocal leg motion assessed in
the full video rather than inferred from still endpoints. The first generated
stride was excluded. Enlarged tracing of the near leg beneath the red skirt
confirms forward contact at source0 and rear extension at source20, with the
far leg advancing under the shield. The small preview initially made this
occlusion ambiguous. The salute raises the full pike while the shield stays steady.

Death v1 is excluded because its legacy corpse guide reversed the head/feet
orientation during the final fall. The generated `dead_left_v1` original keeps
head left and feet right, allowing death v2 to settle without that reversal.
Source27 of death v2 briefly bends the shaft and is omitted; adjacent selected
source26 and28 retain its rotation without that malformed frame.

## Rebuild and review

`produce.py process TAKE` reconstructs the RGBA originals from the retained
lossless video. `review TAKE` creates disposable chronological sheets;
`build TAKE` follows explicit `selection.json` source indices, durations and
contact timing. `assemble` combines `delivery.json`. A new generation must use
a new take directory; submitted originals are immutable. Selected RGBA files
remain available for direct runtime atlas rebuilding.

Autonomous review covers all original chronological frames, enlarged grips,
anatomy, alpha edges on light/dark, gait boundary, contact/recovery and corpse.
Continuous video playback and a manual game playtest are not claimed. Native
phase renders and focused candidate/live checks complete acceptance. No full
repository suite or visible game launch is used.

## Accepted delivery

| Action | Original poses | Duration | Selection |
|---|---:|---:|---|
| Move | 20 | 1300ms loop | move_v1, one reciprocal cycle |
| Attack | 22 | 1100ms | attack_v1, contact at500ms |
| Defend | 12 | 720ms | defend_v1, terminal brace held |
| Hit | 16 | 765ms | hit_v1,90ms peak hold |
| Support | 19 | 1260ms | cast_v1,180ms salute hold |
| Death | 25 | 1625ms | death_v2, grounded terminal corpse |

114 new poses plus eight preserved idle poses. Explicit retiming compresses
stationary source holds while retaining dense transition samples. Runtime atlas
4048x4080,66,063,360 RGBA bytes; original body scale is preserved.
Focused Windows candidate186/live200 checks pass, including Normal/Fast/reduced
motion and unchanged simulation state. Native phase renders reviewed at actual
128px battle reference height. Existing Windows certificate-store and GLES3
MSAA warnings do not fail these checks; Linux was not run on this Windows host.
All eight prior idle pose pixels, anchors and timing are exact; map idle PNG is
byte-identical. Other unit entries are unchanged, and candidate/live atlas bytes
match. Live roster after publication:109 complete,0 partial,123 remaining of232.
The overall animation goal remains in progress.

Task previews, logs, test profiles, unused mattes and verified duplicate Comfy
exports are disposable. Original videos, generated guides and exact provenance,
selected RGBA frames and rebuild tooling remain in source control.
