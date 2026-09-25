# Bargebow Crews H3 originals

Seven deficient actions for `unit_embercourt_bargebow_crews`, preserving eight
accepted articulated idle poses and their overworld playback. Original human
operator, silver/brass helmet and shoulder armor, red/ivory coat, teal scarf,
brown gloves/boots, bolt case mounted alongside the ballista by the hip. Exactly two arms and legs; one wooden/brass
tripod ballista with three rigid support feet, one bow and one string.
Walking carries the assembly; other actions leave it planted. Melee uses a
free-hand punch, support a physical hand signal, ranged the actual mechanism.
The game owns the traveling projectile. Death separates the falling operator
from the planted mechanism. No added magic or equipment.

Guides retain original pose-packing scales, output scale 0.8 and anchor (480,480).
No per-frame scaling or synthetic articulation. Local H3 FL2VA int8 ConvRot,
Qwen3-VL32B NVFP4 AWQ, video VAE; 960x544, 124 original frames at 24 fps,
20 res_multistep/simple steps. Every take preserves exact guides, prompts,
workflow/model names, seed, history, MP4, lossless FFV1 and decoded pixel hashes.
Measured uniform green plate removal preserves teal, steel and brass, and
retains disconnected solid anatomy/equipment components.

Rebuild `produce.py process TAKE`, `build TAKE`, then `assemble` using delivery.json.
Selections record actual original indices, timing and review observations.
Review covers all chronological originals, enlarged anatomy/mechanism/grips,
alpha, cycle seam and native battle-scale phases. Continuous video playback
and manual playtesting are not claimed. Focused offscreen checks only.

## Accepted production clips

| Action | Original frames | Frame duration | Total duration |
| --- | ---: | ---: | ---: |
| Move | 20 | 83 ms | 1660 ms |
| Attack | 23 | 45 ms | 1035 ms |
| Defend | 16 | 50 ms | 800 ms |
| Hit | 20 | 45 ms | 900 ms |
| Support/cast | 20 | 55 ms | 1100 ms |
| Ranged | 28 | 50 ms | 1400 ms |
| Death | 25 | 60 ms | 1500 ms |

152 selected original frames across seven actions. Ranged source frames 40-41
contain an unwanted painted projectile and are omitted as whole frames;
source 39 transitions to 42, with the runtime projectile event at 600 ms.
Melee contact is 540 ms. No anatomy or equipment was erased to hide defects.
The eight retained idle poses keep their exact pixels, offsets and 240 ms timing.
The existing overworld PNG is byte-identical to its pre-publication version:
one invisible RGB pixel (alpha zero) changed during re-export, so the original
PNG bytes and hash were restored after confirming every visible pixel and all
alpha values were unchanged. No other creature catalog rows were modified.

The 2992x3840 atlas uses 45,957,120 decoded RGBA bytes. Focused candidate checks:
224 passed; final live checks: 238 passed. All native battle-scale contact phases
were inspected, including equipment separation in death and the clean ranged
release boundary. Continuous playback and manual playtesting were not performed.
Live roster after this slice: 115 complete, 1 partial, 117 remaining of 232.
Original videos, guides, prompts, workflows and selected transparent frames are
retained; task-only review renders/logs/profiles and duplicate exports are disposable.
