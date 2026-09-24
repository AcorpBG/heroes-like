# River Guard original H3 animation sources

This delivery replaces the deficient movement, melee thrust, shield brace, hit
reaction, rally/support salute and death for `unit_river_guard`. The eight
previously accepted hand/shield idle paintings remain the baseline. The unit is
melee; the ranged fallback remains its attack alias, not a claimed ranged clip.

The original red quilted coat, brass kettle helmet, ivory sash, long hooked spear
and oval wave-painted shield are retained. Source guide registrations use one
anatomical scale per painting, then one fixed 0.65 extraction scale and source
anchor (480,475). No per-frame body normalization, geometric tween, reversed
death, synthetic duplicate poses or whole-sprite bobbing supplies the motion.

## Originals and reproducibility

Each take retains its exact prompt, seed, workflow, uploaded guide hashes, job
identity/history, lossless FFV1 original, viewing MP4 and decoded RGB hashes.
`key_guides/generation.json` records the original support-pose image generation.
The first salute painting was excluded because its shaft shortened and the tip
touched the top edge; the corrected second painting guides the support motion.

Local ComfyUI uses MiniMax H3 FL2VA int8 ConvRot, Qwen3-VL 32B NVFP4 AWQ and the
H3 video VAE, 124 original frames at 24 fps, 960x544, 20 res_multistep/simple steps.
No external generation service is used for video. Image generation supplied the
new salute guide; other guides are original existing authored unit paintings.

`produce.py` measures the uniform chroma plate, verifies corner agreement and
unmixes its color without moving anatomy. The guard has neither saturated green
nor magenta material. `defend_v2` and `hit_v3` use green; other takes use magenta. Historical
`guide_*_magenta.png` filenames describe the upload slot, not necessarily its
actual plate color; `config.json` and the images are authoritative.

To rebuild extracted originals, run `produce.py process TAKE`; `review TAKE`
creates disposable chronological review sheets; `build TAKE` uses the explicit
selected frame/timing recipe. `assemble` combines `delivery.json` in order.
Regeneration requires a new take directory; submitted originals are immutable.
Selected RGBA frames are retained for atlas rebuilding without a video decoder.
Nonselected RGBA and duplicate Comfy exports are disposable after original/hash
verification. Original videos, guides, prompts and rejected source provenance
are preserved.

## Rejected takes

- `move_v1`: generated plate changed colors and developed a spatial gradient;
  extraction could not safely preserve the subject.
- `defend_v1`: adaptive extraction exposed cyan edge fringes during generated
  backdrop transitions. Its coherent pose motion does not excuse those pixels.
- `hit_v1`: the model added an incoming arrow. The replacement describes only a
  recoil, with no external event represented in the sprite.
- `hit_v2`: generated cyan/magenta background cycling with lightning-like marks,
  rather than a uniform plate. Rejected as original content, not hidden by a
  more permissive matte. The next take uses green and literal joint motion.

## Review scope

Review covers all 124 chronological source frames per take, enlarged equipment,
hands/feet and alpha edges on light/dark backgrounds, gait boundary, attack
extension, continuous collapse and settled corpse. This is frame-sequence review;
continuous video playback and a manual game playtest are not claimed. The
owner delegates selection and publication to the agent; no routine approval is
required. Native phase rendering and focused runtime checks complete acceptance.

## Published selection and checks

| Action | Original take | Poses | Runtime duration |
| --- | --- | ---: | ---: |
| Movement | move_v2 | 20 | 1000 ms loop |
| Melee attack | attack_v1 | 21 | 1155 ms; extension at 495 ms |
| Defense | defend_v2 | 10 | 725 ms; hold final brace |
| Hit | hit_v3 | 14 | 675 ms |
| Support salute | cast_v1 | 19 | 1305 ms |
| Death | death_v1 | 26 | 1690 ms; hold settled corpse |

The selected source indices and explicit holds are in each `selection.json`.
These are deliberate combat retimings of reviewed chronological source intervals,
with dense samples through fast motion and fewer samples during static holds.
No frame interpolation or duplicated poses is used to inflate the frame count.

Focused offscreen Godot 4.6.2 checks passed: 180 for the candidate and 194 for the
published unit, including phase/frame resolution, timing, Normal/Fast/reduced
motion and the selected runtime presentation paths. Native 128px phase renders
were visually inspected at original resolution. No full suite or manual game
playtest was run. Existing certificate-store and GLES3 MSAA messages are unrelated
environment warnings; there were no reported animation failures.

Independent preservation comparison verified all eight accepted idle paintings,
offsets and timing exactly; the overworld idle PNG is byte-identical. Its source
sheet, indices, crop and hashes correctly reference the new atlas. Other unit
catalog rows and map idle entries are unchanged. Candidate and live atlas hashes
match. The atlas is 3920x4032, 63,221,760 uncompressed RGBA bytes; no frame exceeds
the texture boundary. This completes River Guard, bringing the live coverage to
108 complete, 0 partial and 124 still needing the full quality pass out of 232.
The overall roster goal remains active.
