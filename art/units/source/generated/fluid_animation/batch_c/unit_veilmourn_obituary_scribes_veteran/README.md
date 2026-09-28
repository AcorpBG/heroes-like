# Lastword Registrars H3 production

Eight dedicated actions for `unit_veilmourn_obituary_scribes_veteran`, using the original faceless hood, black robes and ivory stole, scroll back frame, hip inkwell and two-handed quill spear with attached parchment and brass seals. Battle and overworld share the accepted idle. The final death original supplies the persistent corpse.

Local MiniMax H3 ordinary int8, 124 original frames per take at 24 fps, 20 res_multistep/simple steps, no Turbo LoRA. Sampling latents are preserved, then encoder/denoiser are released before tiled VAE decoding. All guides use a 960 x 704 canvas, anatomical anchor [448, 628] and fixed 0.5 extraction scale. No per-frame normalization, reversed footage, interpolation or duplicate padding.

Original battle poses provide ready, extension, recoil and corpse guides. Built-in image generation supplies low guard and raised open-palm support guides. Guard correction additionally uses unchanged original 36 from the first guard take as an intermediate guide; that matte is retained even though the failed take is not published.

Rejected attack v1 for spear-tip separation and detached parchment fragments during the overhead transition. Corrected v2 uses a low guard and direct thrust. Rejected guard v1 for a floating brown/green ghost over the spearhead during the transition. Its pixels are connected to foreground, so it was regenerated instead of masked away. Both rejected originals remain preserved.

Rebuild with produce.py, stage_video.py, run_batch.py, delivery.json and per-take configs/selections. Preserve original videos, lossless FFV1 RGB frames, sampler latents, guides/prompts/provenance and selected matte frames. Unselected mattes, temporary native renders and hash-verified duplicate ComfyUI outputs are rebuildable.

## Accepted actions and validation

| Action | Selected original frames | Timing | Contact index |
|---|---:|---|---:|
| idle / overworld idle | 31 | 110 ms | - |
| movement | 31 | 45 ms | - |
| melee thrust | 33 | 45 ms, contact held 100 ms | 13 |
| ranged release | 27 | 50 ms, contact held 100 ms | 11 |
| hit | 25 | 35 ms | - |
| defend | 20 | 50 ms, final pose held | - |
| support | 21 | 65 ms | 10 |
| death | 31 | 55 ms, final pose is persistent corpse | - |

Autonomously reviewed all 1,240 chronological original frames, enlarged transitions on light/dark backgrounds and every selected native battle phase. The idle visibly raises and lowers the spear with both forearms. Movement alternates leg support. The separate attack and ranged clips preserve continuous grips and equipment through release and recovery. Support lifts the free hand and returns it to the spear; defense bends the knees and widens the stance. Death drops to the knees before falling to a grounded corpse.

Focused Windows Godot checks: candidate 743 passed; installed 747 passed, including Normal, Fast, reduced motion and shell presentation. Isolated headless import succeeded. Verified exact pixels and anchors for 219 source poses and 220 candidate/live poses including corpse, exact map strip, all 98 provenance hashes, 23 guide hashes and 1,240 preserved original RGB frames. The other 231 unit and map records are unchanged. Atlas: 3008 x 3856, 46,395,392 uncompressed RGBA bytes. Native battle and overworld outputs reviewed. No continuous playback, manual playtest, Linux test or full suite is claimed.

Roster tracker after publication: 162 of 232 units have all seven core actions accepted; 70 still lack one or more core actions. This unit also has its dedicated ranged action accepted. The broader roster goal remains active.
