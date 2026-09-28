# Writwheel Reclaimers H3 animation delivery

Eight reviewed action clips replace the sparse legacy poses. Overworld playback uses the accepted idle; the corpse is the final death pose. Stable unit ID, gameplay and saves are unchanged.

| Action | Take | Original frames | Frame time |
|---|---|---:|---:|
| idle | idle_h3_v1 | 31 | 110 ms |
| move | move_h3_v1 | 22 | 65 ms |
| attack | attack_h3_v2 | 28 | 55 ms |
| ranged | ranged_h3_v3 | 26 | 55 ms |
| hit | hit_h3_v3 | 16 | 45 ms |
| defend | defend_h3_v2 | 17 | 55 ms |
| cast | cast_h3_v3 | 22 | 65 ms |
| death | death_h3_v2 | 30 | 65 ms |

The delivery selects 192 original frame references from 17 preserved takes (2,108 losslessly verified RGB frames). Rejected takes remain as provenance: changing backdrop colors, unwanted projectile/flash/smoke, a missing front wheel, or the first collapse head/backpack morph. No rejected footage is published. Each selection records source indices, timestamps and retiming; long idle/held intervals are shortened without invented or reversed frames.

The engineer retains two arms, two booted legs, goggles, mask, coil backpack and the brass toothed launcher. Fixed 960x640 canvas, [416,560] anatomical ground reference and 0.5 extraction scale apply to every frame, including the corpse. The runtime atlas is 3352x3244, below 4096, with original-pixel rectangle packing.

Coordinator review covered every chronological original frame of accepted takes, enlarged grip/anatomy/alpha details on dark and light grounds, loop endpoints, all native battle-size phases, battle contact and imported overworld idle. Continuous-video playback was unavailable; no continuous playback or manual game playtest is claimed.

Focused Windows Godot checks: candidate 662 passed, published/imported 666 passed. Exact selected pixels, anchors, clip timings, corpse mapping and rebuilt map-idle pixels/hashes were verified, together with 26 guides and 89 handoff provenance records. All other 231 catalog entries stayed identical. Existing root-certificate-store and GLES3 MSAA host messages did not fail these checks. No full suite or Linux validation.

Rebuild: restore cleaned unselected mattes from each preserved original_lossless.mkv with produce.py process <take> when needed; produce.py build <selected-take>, then produce.py assemble. Publish only the eight reviewed clips with tools/publish_fluid_creature_animation.py. Guides, prompts, workflows, latents, original videos, original decoded-pixel hashes, selected mattes and recipes remain. Temporary previews, tests and verified duplicate Comfy outputs are disposable.
