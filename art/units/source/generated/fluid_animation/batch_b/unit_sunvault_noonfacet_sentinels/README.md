# Noonfacet Sentinels H3 animation

Published 186 original H3 frames across six dedicated actions. Preserve the accepted eight-frame, 240 ms idle and exact overworld strip.

| Action | Original frames | Frame duration | Contact index |
|---|---:|---:|---:|
| move | 41 | 50 ms | - |
| attack | 38 | 40 ms | 16 |
| defend | 23 | 45 ms | - |
| cast | 34 | 55 ms | 15 |
| hit | 27 | 35 ms | - |
| death | 23 | 60 ms | - |

## Visual review

Ivory/gold armor, navy underlayers, split tabard, closed helmet, right-hand twin-point sunburst polearm and left kite shield stay recognizable. Walk alternates both legs; attack winds up, strikes downward and returns; defense bends knees and tucks behind the shield; support raises the weapon in a ceremonial salute; hit leans backward and recovers; death kneels, rolls onto its side and grounds the intact equipment. Dead uses the final death frame. All chronological originals, enlarged grips/edges, selected boundaries and native Godot phases were reviewed. Continuous video playback was unavailable and is not claimed.

Defend_v1 is rejected for insufficiently visible articulation. Defend_v2 uses the original crouched guard. Cast_v1 and cast_v2 stretch the polearm and invent a pointed lower tip; cast_v3 uses reviewed attack_v1 source22 as its complete-weapon guide. Hit_v1 and hit_v2 invent impact light effects; hit_v3 describes a controlled physical backward lean instead. Rejected originals remain preserved. Attack source26/28/30/32/34 contain detached 43-55 pixel plate specks above the shoulder: audited original-pixel rectangle exclusions retain every connected subject pixel.

## Source and rebuild

Original legacy action guides use one fixed 0.93 anatomical factor to match the later accepted idle, with fixed 0.65 video extraction. No per-frame normalization or synthetic articulation. Selections shorten long holds and explicitly retime original 24-fps samples for combat. No interpolation, reversed frames or duplicate padding.

Each take preserves its original FFV1/MP4 video, sampled latent, prompt, seed, submitted workflows, original guide lineage/hashes and matte recipe. Flat green extraction checks corner spread<=10 and chroma separation>=80, with foreground chroma protection20 and all confidently opaque components retained. Rebuild missing disposable mattes from original_lossless.mkv using produce.py process, then build selected takes and assemble. Source dependencies used as later guides must be rebuilt first. Publish the six selected clips with preserved reviewed idle; restore the original map row and strip after the publisher refreshes that route.

## Focused validation

Candidate 258 / live 272 checks pass. Verified all 186 new source-frame pixels, anatomical anchors and clip timings, 66 provenance hashes, preserved eight idle frames and exact map catalog/strip. Other 231 creature rows remain unchanged. Atlas 4056x3960, 64,247,040 RGBA bytes. Imported battle and map artwork inspected. No full suite, manual game playtest or Linux execution. Roster: 146 complete, 86 remaining; overall goal remains active.
