# Kilnward Mallets fluid actions

Completed solo. Six dedicated MiniMax H3 actions replace deficient legacy clips; the existing eight articulated idle paintings and overworld pixels/timing are preserved.

| Action | Selected take | Frames | Timing |
| --- | --- | ---: | --- |
| Move | move_h3_v4 | 28 | 42 ms; 1176 ms loop |
| Attack | attack_h3_v3 | 39 | 40 ms; contact index 24/source 72; 1560 ms |
| Hit | hit_h3_v2 | 16 | 50 ms; 800 ms |
| Defend | defend_h3_v1 | 16 | 60 ms; 960 ms; final brace held |
| Support | cast_h3_v1 | 24 | 60 ms; 1440 ms; physical mallet salute |
| Death | death_h3_v1 | 38 | 50 ms; 1900 ms; persistent final corpse |

The live melee unit requires no ranged weapon. Identity remains one stocky black-bearded smith with brown headband, copper shoulder plates, wrist cuffs, segmented thigh armor, leather boots and a long apron bearing the red kiln emblem. Two hands keep their respective grips on one straight wooden shaft and rectangular iron mallet. Movement alternates near/far legs; attack lifts, strikes and recovers; recoil, crouching brace, upright support and grounded side fall are separate actions.

## Original sources and rebuild

Original pose lineage is art/animation/source/poses/unit_neutral_kilnward_mallets/packing.json. Older action art uses its recorded scale times 0.91 to match the later approximately 199px idle body. No per-frame scaling or root stabilization is used. Most H3 takes use 960x640, anchor [430,560], extraction scale 0.5. Attack v2/v3 use 960x768 and anchor [430,680] for raised-weapon headroom at the same body scale.

attack_keyposes_v1.png contains two original image-generated lifting/downstroke guides. Its prompt, reference hashes and original output path are preserved in the corresponding generation sidecar. Both poses use source-wide scale 0.323 and separately recorded anatomical ground anchors. They guide H3 motion rather than padding runtime frame counts.

Each take preserves config, exact prompt, original guide crops/hashes, sampling/decode graphs, model profile, seeds, submission/history, original latent, MP4 and lossless FFV1 RGB. All 1488 decoded original frames and 36 guides were verified. produce.py prepares, verifies, collects, mattes, reviews and builds selected frames; run_batch.py runs explicitly named takes in pairs. Sampling latents are preserved before encoder/denoiser unloading and separate tiled VAE decoding. Submitted takes are immutable; corrections use new versions.

Matting requires uniform corner medians (spread<=10) and chroma separation>=80. Initial magenta protected band 8 follows measured source maximum 6. Later green bands are 8 for defense/death/hit/move v4,10 for move v2/v3,24 for support and34 for attack v2/v3, including rare green source pixels in the recovery reference. All legitimate body/weapon components are retained. Unselected mattes and Comfy output/input duplicates are disposable and rebuildable from retained originals.

## Rejected takes and corrections

- Move v1 cycles through unsafe red/green/magenta plates. Red overlaps legitimate emblems; no destructive key workaround.
- Move v2 has clean green extraction but passing-pose resets near 32/33 and 93/94. Installed MiniMaxH3AddGuide code anchors exact requested pixel indices; no guessed frame-grid change. V3 removes intermediate passing guides.
- Move v3 walks coherently but loses the red apron emblem, partly concealed in its original contact reference. V4 uses the original front-ready identity reference with visible long apron/emblem and retains it throughout the selected full stride 26-53.
- Attack v1 deforms the hammer head and briefly detaches the shaft. Two original intermediate key poses improve rigidity in v2.
- Attack v2 jumps from ready 17 to raised 18 and recovery 97 to ready 98. V3 uses three spaced guides 34/68/85 and continuous lift/recovery; every source frame 64-76 is retained through the fast strike.
- Hit v1 invents a beam and orange illumination. V2 describes the physical recoil alone, retaining the original ready/recoil guides without those effects.

## Review and validation

All selected source/extracted chronologies, enlarged anatomy/grips/alpha edges, foot phases and loop boundary were reviewed. Native 128px overview rows, battle phases and live map-idle samples were inspected. This records frame-by-frame and native phase review, not continuous video playback or a manual game playtest.

Focused Godot 4.6.2 Windows candidate 575/live 589 checks pass, including Normal/Fast/reduced-motion timing, contacts, movement loops, presentation and unchanged simulation/save state. Isolated editor import passes. Existing Windows certificate-store/GLES3-MSAA diagnostics remain non-failing environment messages; no Linux execution or full-suite claim.

All 161 published frames match their selected original RGBA pixels and anatomical anchors. Eight idle frames, map pixels/timing and the other 231 unit records are unchanged. Atlas 1720x3536 fits the 4096 limit. Roster coverage after this delivery is 170/232 complete, 62 remaining; the overall goal remains in progress. Preserve originals, provenance, caches, saves, backups and unrelated local work.
