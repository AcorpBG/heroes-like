# Charter Colossus original H3 animation

Accepted seven-action battle and overworld delivery for
`unit_embercourt_charter_colossus`: 119 selected original frames.

| Action | Frames | Duration | Behavior |
|---|---:|---:|---|
| Idle | 19 | 2812 ms | Shield elbow lift and staff-wrist articulation; returns to ready |
| Move | 20 | 1660 ms | Reciprocal heavy marching gait |
| Attack | 28 | 1260 ms | Rigid-staff wind-up, forward strike, quarter-turn recovery; contact at 855 ms |
| Defend | 10 | 750 ms | Knees bend into a held shield guard |
| Hit | 8 | 520 ms | Torso recoil and recovery; secondary shudder excluded |
| Support | 14 | 1050 ms | Physical raised-shield rally salute, no invented magic |
| Death | 20 | 1500 ms | Kneel, roll onto side, grounded body and staff; persistent final corpse |

The original ivory armor, iron joints, bronze fittings, scarlet panels/tassels,
shield arm and middle staff grip remain. Exactly two arms and two legs.
The original articulated idle supplies reference scale. Older action paintings
use one fixed 1.18 guide enlargement against that reference. Every extracted
video frame uses scale 0.8 and anatomical anchor [480,480]; no per-frame size
normalization, invented articulation, reversed poses or interpolation.

Local MiniMax H3 uses 960x544, 124 frames at 24 fps, 20 res_multistep/simple steps,
FL2VA int8 ConvRot, Qwen3-VL32B NVFP4 AWQ and the int8 video VAE. Per-take configs,
prompts, guide hashes, workflows, histories, original lossless video and viewing
MP4 are retained. Green-plate unmix/despill preserves original geometry and all
solid-connected prop components. Selected RGBA and every guide source remain.

## Selected corrections

`delivery.json` names the exact takes. Attack combines `attack_raise_v2`, the
first coherent arc of `attack_strike_v2`, and `attack_recover_v3` beginning from
that strike's actual contact pose. Initial/terminal holds and later flourishes
are excluded. Recovery begins at source34 after the post-contact hold; its
native join was inspected, preserving scale and fitting the 4096 texture limit.
The 4092x4004 atlas occupies 65,537,472 uncompressed RGBA bytes.

`attack_v1` is rejected for a bent staff. `hit_v1` is rejected for a swollen
foreshortened tip. `attack_recover_v2` was stopped when its starting guide became
obsolete. `hit_v2` and `hit_v3` sampled successfully but stalled at decoding;
no decoded output from those attempts is claimed. Their source instructions and
submission/recovery records are retained. `hit_v4` supplies the accepted recoil;
matching held postures36/74 join the first recoil to the final recovery, removing
an intervening secondary shudder. Exact selections and deliberate gameplay
retiming are recorded in each `selection.json`.

## Staged production and rebuilding

`stage_video.py` saves the unmodified video component of H3's AV latent, releases
the large models and execution cache, verifies at least 16 GB free VRAM, then
runs a VAE-only decode. It preserves the latent, both workflows/submissions and
hashes. Final hit/recovery use 256/64 spatial and16/4 temporal tiles; earlier
successful takes used512/64. The service runs with4GB reserved VRAM. The staged
hit decode completed in15 seconds after repeated unresponsive single-job decodes.

For a new take with its own config, run `python stage_video.py <take>`; never
overwrite an earlier submitted take. For retained footage, `produce.py process
<take>` recreates mattes from its lossless original, `build <take>` rebuilds a
candidate selection, and `assemble` combines the named delivery takes. Publication
still requires visual review and the selected-clip publisher. HTTP latent
preservation avoids a Windows-only service-file dependency.

## Acceptance

Every original chronological frame, enlarged anatomy/alpha edges, attack joins,
all final native battle phases and imported map idle were reviewed autonomously.
Candidate193 and published197 focused Windows offscreen Godot checks passed;
isolated import passed and source atlas bytes match the reviewed candidate.
Other creature rows are unchanged. No continuous video playback, manual playtest,
Linux run or full-suite validation is claimed. Temporary reviews/tests and
verified redundant Comfy outputs are removed; originals and caches are preserved.
