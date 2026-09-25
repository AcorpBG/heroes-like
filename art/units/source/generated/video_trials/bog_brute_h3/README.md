# Bog Brute H3 originals

Six deficient battle actions were replaced while preserving the eight
accepted articulated idle poses and map playback. This is the existing heavily
built human Mireclaw fighter: dark hair/beard, dull scale armor, reed ties,
leather boots, one short iron-banded wooden club and a hanging rusty chain/hook.
The near right hand holds the club; the empty far left hand may join its shaft
for attack/guard. Support is a physical empty-hand rally signal, not spellcasting.

Local MiniMax H3 FL2VA int8 ConvRot, Qwen3-VL32B NVFP4 AWQ and H3 video VAE;
960x544,124 frames at24fps,20 res_multistep/simple steps. Each take retains exact
model names, prompt, seed, guide hashes, submission/history, original MP4,
lossless FFV1 and every decoded RGB hash. Original pose rectangles and anatomical
anchors come from the preserved packing.json. Legacy references retain0.55scale;
accepted idle retains0.465scale. Fixed extracted scale0.65 and anchor(480,475)
preserve body size through crouching, raised equipment and fallen poses.

Magenta plate extraction measures uniform corners, rejects varying/unsafe colors,
unmixes/despills edges and preserves every alpha>=8 component with alpha>=128
original pixels. No per-frame resizing, warps, interpolated anatomy or duplicate
pose padding. Existing idle sources/pixels remain untouched.

Rebuild mattes with `produce.py process TAKE`, build selected frames with
`produce.py build TAKE`, then `produce.py assemble` using delivery.json.
`review TAKE` generates disposable chronological sheets. Exact chosen frame
indices and intentional retiming are recorded in selection.json after review.

Review covers chronological originals, enlarged anatomy/club/chain/alpha,
reciprocal gait and seam, action recovery, persistent corpse and native battle
scale. Continuous video playback/manual game playtesting is not claimed. Only
focused offscreen Windows candidate/live checks are used; no full suite.

## Selected actions

| Action | Take | Poses | Duration |
|---|---|---:|---:|
| Move | move_v1 | 20 | 1300ms loop |
| Attack | attack_v1 | 23 | 1150ms; contact650ms |
| Defend | defend_v1 | 12 | 660ms; final held |
| Hit | hit_v2 | 16 | 765ms including90ms recoil hold |
| Support | cast_v1 | 19 | 1260ms including180ms fist hold |
| Death | death_v1 | 22 | 1430ms; final corpse held |

112 new original video poses plus eight preserved accepted idle poses. Retiming
compresses long stationary holds while keeping the rapid swing/fall transitions.
The first hit take is rejected for an unwanted incoming object/residue and a
color-cycling backdrop. It is retained only as an original with rejection notes.
A simpler acting prompt and tighter ready/recoil guides produced a clean second
take. No failed hit_v1 frames are shipped. All seven original videos are retained.

Candidate validation passed176 focused checks. Every selected pose was reviewed
at actual battle reference scale: reciprocal walking, two-handed club strike,
held guard, recoil/recovery, empty-hand rally and settled body/club/chain. Accepted
idle movement remains readable. Native phase renders do not establish continuous
video playback or a manual playtest; neither is claimed.

Published live validation passed190 focused checks, including Normal/Fast/reduced motion and unchanged simulation state. Candidate/live atlas pixels match (3696x3168,46,835,712 RGBA bytes). Eight accepted idle poses retain exact pixels, offsets and timing; the overworld PNG is byte-identical and other unit entries are unchanged. Live roster111 complete,121 remaining of232. The overall goal remains active.
