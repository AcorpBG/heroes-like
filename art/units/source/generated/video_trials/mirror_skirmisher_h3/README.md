# Mirror Skirmisher H3 originals

Six deficient battle actions are replaced for `unit_mirror_duelist`, while
preserving the eight accepted articulated idle poses and existing map playback.
The Sunvault melee fighter retains a closed gold/blue helmet, white ponytail,
blue/silver armor with gold trim, white tabard, trailing iridescent ribbons,
one double-ended spear and one small buckler strapped to the far left forearm.
The near right hand keeps the spear; the far hand may join its shaft for thrust.
Support is a physical rally salute. No new magic or ranged weapon is introduced.

Local MiniMax H3 FL2VA int8 ConvRot, Qwen3-VL32B NVFP4 AWQ and H3 video VAE;
960x544,124 original frames at24fps,20 res_multistep/simple steps. Each take
preserves model names, exact prompt/seed/guides, submission/history, original
MP4, lossless FFV1 and every decoded RGB hash. Original reference rectangles and
anatomical anchors come from the existing packing.json. Legacy guide scale0.7
and accepted idle scale0.52 are preserved through fixed extraction scale0.8
and ground anchor(480,475); no per-frame body normalization.

Uniform green is absent from the character palette and preserves blue/white/gold
armor and ribbons. Extraction measures the original corner plate, rejects unsafe
spatial/color variation, unmixes and despills alpha edges, retaining every
alpha>=8 connected component containing opaque alpha>=128 original pixels.
No warps, interpolated frames, duplicate padding or repainted anatomy are used.

Rebuild with `produce.py process TAKE`, `build TAKE` and `assemble`. Selected
source indices/timing live in selection.json and delivery.json. `review TAKE`
creates disposable chronological sheets. Originals include rejected takes.

Review covers every chronological original frame, enlarged equipment/anatomy
and alpha edges against light/dark backgrounds, gait boundaries, attack recovery,
held guard and settled corpse, followed by native Godot battle-scale phases.
Continuous video playback and manual game playtesting are not claimed. Only
focused offscreen candidate/live checks are used, never the full suite.

The first attack is rejected: it repeatedly spins the spear and adds a magenta
projectile/body glow. Its originals remain, but none of its frames ship.
The correction uses ready/straight-thrust guides and a simple physical exercise
prompt instead of the overhead windup. The legacy recoil painting loses the
spear and is excluded as a guide; the hit generation starts from intact ready.

## Selected actions

| Action | Take | Poses | Duration |
|---|---|---:|---:|
| Move | move_v1 |31|1705ms loop|
| Attack | attack_v2 |25|1200ms; contact540ms|
| Defend | defend_v1 |14|700ms; final held|
| Hit | hit_v1 |16|700ms including100ms flinch hold|
| Support | cast_v1 |18|1050ms including200ms salute hold|
| Death | death_v1 |26|1430ms; final corpse held|

130 selected original video frames plus eight preserved idle poses. Frame timing
removes long motionless stretches and preserves dense original thrust/brace/fall
transitions. No attack_v1 frames are selected. All seven original video pairs,
their prompts/guides/provenance and the selected transparent source frames remain.

Candidate checks passed194 and published checks passed208 on Windows, including
Normal/Fast/reduced-motion behavior and unchanged simulation state. Every selected
pose was reviewed in the native battle-scale phase render; map idle was checked
through its native renderer. This does not claim continuous video playback.
The candidate and live atlas hashes match (4000x3696,59,136,000 RGBA bytes).
Eight existing idle poses retain exact pixels, offsets and timing. The map-idle
PNG is byte-identical, and all other unit rows remain unchanged. Roster coverage
is112 complete,120 remaining of232; the overall goal remains active.
