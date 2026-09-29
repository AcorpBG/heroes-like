# Scrapbow Teams H3 production

Completed solo. Seven dedicated H3 actions supply 203 selected original frames: movement, melee, ranged, hit, defense, physical support and death. The existing eight-frame articulated idle remains pixel-identical: the tall gunner raises and lowers his crossbow with both arms while the shorter loader gestures beside him. Battle and overworld idle pixels, anchors and timing are preserved.

Identity: exactly two masked human crew, one tall muscular gunner at screen right and one shorter crouching loader at screen left. Brown leather armor, blue headbands/cloth, gunner boots, loader goggles and back quiver. One rigid heavy wooden crossbow with steel fittings and blue bow limbs. Each person retains two arms and two legs. The loader must not merge with the gunner, vanish, or acquire the gunner's weapon.

Original poses come from art/animation/source/poses/unit_neutral_scrapbow_teams/packing.json. Its old action sheets use one uniform 0.72 registration factor to match the later idle body height (roughly 145 runtime pixels). Idle sources retain their original scale. H3 guides use 960 x 640, anatomical anchor [430,550], extracted scale 0.5. No per-frame scale or position normalization. Every guide has exact source path, rectangle, anchor, scale and hashes in reference.json.

The selected ranged take uses magenta with protected foreground chroma 32. Other selected takes use green with protected chroma 12. The core leather/blue/skin palette measures green chroma at most 12; the original continuity sheets' rare higher-green pixels were visually located in background gaps near quiver arrows, the string/stock and below the tassets. The initial conservative 74 band retained plate fringes, so move v2 and death v1 were rematted using explicit extraction_settings.json without changing their original videos or guides. Corner uniformity (spread <=10) and chroma separation (>=80) remain strict. Retain disconnected foreground components containing opaque pixels, including the second crew member and fallen equipment.

The corrected shove and duck key poses are original generated art in correction_keyposes_v1.png. Both use the same 0.26 source-wide scale, with separate recorded crops and anatomical anchors. The shove keeps the crossbow facing right instead of rotating/reversing it; the duck lowers the crossbow intact and gives the loader a distinct protective gesture. Exact image-generation prompt, reference and hashes are retained.

Run run_batch.py with explicit take names; it samples in pairs, preserves latents, releases the large models, then decodes. Each action config records exact original guides, action beats, seed, model graph, scale and plate. Preserve submitted takes immutably; corrections use a new version. produce.py retains and pixel-verifies lossless videos, extracts keyed frames, builds chronological previews and assembles only explicitly selected frames. The runtime owns projectile flight: any generated detached projectile requires a reviewed empty-gap separation and original-pixel recipe before publication.

Selected actions:

| Action | Take | Frames | Duration | Contact |
|---|---|---:|---:|---:|
| Move | move_h3_v2 | 21 | 1050 ms loop | alternating crew steps |
| Ranged | ranged_h3_v2 | 43 | 1505 ms | 910 ms |
| Melee | attack_h3_v2 | 32 | 1120 ms | 455 ms |
| Hit | hit_h3_v2 | 30 | 900 ms | recoil and recovery |
| Defend | defend_h3_v1 | 15 | 600 ms | held brace |
| Support | cast_h3_v2 | 26 | 1040 ms | 280 ms |
| Death | death_h3_v1 | 36 | 1260 ms | final grounded crew |

Every selected take's complete 124-frame chronology and enlarged equipment/limb transitions were inspected on dark and light backgrounds, followed by all 203 native Godot phases, battle phases and preserved map-idle phases. This is frame-by-frame review, not a continuous-playback or manual-playtest claim. Frame indices and deliberate gameplay retiming are recorded per take. No reversed, interpolated or duplicate padding frames.

Rejected originals remain: move v1 changes backdrop colors; ranged v1 distorts the bow during recovery; attack v1 reverses and distorts its weapon; hit v1 invents an incoming beam/flash and loses the clean plate; support v1 fires during its weapon raise. The revised support is a loader fist signal with the gunner's weapon held low. Ranged v2 retains the actual recoil but excludes attached-effect frames 63-64 and separates only completely detached runtime-owned projectile pixels in 65-69 across verified empty vertical gaps. Complete original videos and mattes for these selected frames remain unchanged.

The candidate passed 286 focused checks, published delivery passed 300, and isolated headless Godot import succeeded. Verification confirmed all 1,488 original RGB frames, 34 guide hashes, 203 runtime frame pixels/anchors, unchanged eight-frame idle and map pixels/timing, and unchanged other 231 unit records. Runtime atlas is 3520 x 3784, within 4096. Existing Windows certificate-store and unsupported GLES3 MSAA warnings were observed; no animation check failed. No full suite or Linux execution claim.

Original videos, sampled latents, key-pose master, guides, prompts, workflows and provenance remain, including rejected takes. Only selected mattes are retained; produce.py process rebuilds unselected mattes from the lossless video (rejected plate failures still require review). Task previews, test profiles and byte/pixel-verified duplicate Comfy outputs are disposable after validation. Caches, saves and unrelated work remain untouched.
