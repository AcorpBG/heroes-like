# Blackbranch Cutthroat H3 originals

Replace six deficient battle actions, preserving the eight accepted articulated
idle paintings and their map playback. The cutthroat remains a melee unit with
one curved hooked short blade in the near hand and a small round wooden/brass
buckler on the far forearm. Green ragged hood/skirt, leather armor, wrapped boots,
dark hair and human anatomy remain consistent. Support is a physical blade signal.

## Production and rebuild

Local MiniMax H3 FL2VA int8 ConvRot, Qwen3-VL32B NVFP4 AWQ and H3 video VAE;
960x544,124frames24fps,20 res_multistep/simple steps. Per-take workflows preserve
exact model names, guides, seed, prompt, submitted job, history, original MP4,
lossless FFV1 and every decoded RGB hash. Generated guide originals and exact
prompts/references are recorded in `key_guides/generation.json`.

Uniform magenta is absent from the green/brown/brass palette. Measured flat-plate
unmix/despill preserves original clothing and detached equipment; alpha>=8
components survive when containing confidently opaque original pixels. No anatomy
reconstruction, interpolation or duplicate-pose padding. Original pose guides use
0.55scale to match accepted idle0.45; every extracted video frame uses fixed
0.65scale and anatomical anchor(480,475). Fallen/crouched poses are not normalized
to standing height. Raised weapons do not define body scale or ground contact.

Two image-generation contact proposals failed to make leg reversal unambiguous.
Both are retained and excluded. The walk control was reassessed: H3 receives
original matching endpoints and explicit reciprocal gait instructions rather than
repeatedly pinning an uncertain midpoint. Acceptance requires leg tracing in the
resulting sequence. A separate original raised-blade pose guides the support clip.

`produce.py process TAKE` rebuilds mattes from retained lossless originals;
`review TAKE` creates disposable chronological sheets; `build TAKE` applies exact
selected original frame indices/timing. `assemble` follows `delivery.json`.
Submitted originals are immutable; retries get new take directories.

Autonomous review covers full chronological frames, enlarged anatomy/grips and
light/dark alpha edges, complete gait and seam, contact/recovery, corpse and
actual-size native renders. Continuous video playback or manual game playtesting
is not claimed. Focused Windows candidate/live checks only; no full suite or
visible game launch. Final selections and checks are recorded after review.

## Published selection

| Action | Original take | Poses | Duration |
|---|---|---:|---:|
| Move | move_v1, reciprocal cycle38-76 | 20 | 1100ms loop |
| Attack | attack_v1, anticipation/slash/recovery | 21 | 1050ms; contact400ms |
| Defend | defend_v1, lowered buckler guard | 12 | 660ms; final held |
| Hit | hit_v2 recoil + hit_v1 recovery | 16 | 800ms |
| Support | cast_v1, raised-blade rally and return | 20 | 1200ms |
| Death | death_v1, kneel/side fall/settling | 23 | 1495ms; final held |

112 new original poses; eight previously accepted idle poses remain unchanged.
Exact frame indices and deliberate retiming are in each selection.json.

The first hit take invented an arrow/impact particles early in the clip; that
interval is excluded. The retry has clean recoil but changes background later.
extract_ranges.json permits only its flat-magenta0-38 prefix: green/red/gradient
backgrounds are not used. join_hit.py joins its selected22-32 recoil to the first
take's clean40-48 recovery at the matching raised-buckler pose. Both whole original
videos and rejection records remain. Rebuild both parts, then run join_hit.py
before assemble. Part handoff hashes document the join. Full hit_v2 review should
use its original video because excluded intervals intentionally have no matte.

Native candidate review passed176 focused checks. At actual battle reference
size, the gait alternates knee leads; blade/buckler remain in their hands; guard
and recoil are distinct; rally returns to ready; the fallen body and props settle
on the ground. The preserved idle retains visible arm articulation. Review used
chronological originals, enlarged frames and native phase renders, not continuous
video playback or a manual game session. Windows offscreen validation only.

Published live validation passed190 focused checks, including Normal/Fast and reduced-motion routes. Candidate/live atlas pixels match (3256x3080,40,113,920 RGBA bytes). All eight retained idle poses, their offsets/timing and overworld PNG remain byte/pixel exact; other units are unchanged. Roster110 complete,122 remaining of232.
