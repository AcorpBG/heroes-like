# Fenbell Chainstalkers movement candidate

Status: movement published following owner source-video review. Existing six accepted actions remain unchanged.

The magenta original was rejected when its background changed to green at frame14. The blue_v2 original keyed consistently but the boot crossed the hook around frames52-62. Original videos, prompts and rejection reasons are retained.

The built-in image tool repaired the carrying guide: a gathered chain suspends the hook outside the thigh above the boots. key_guides/generation.json records the exact original, prompt and hashes. carry_v3 uses that pose for both endpoints in local MiniMax H3 (seed2026092420,960x544,124frames,24fps,20steps). Generation took121.055seconds. Input scale .42 and extraction .25/.42 retain roughly225px body height, with fixed ground anchor480,475.

All124 chronological frames and enlarged light/dark samples were inspected. Both legs exchange support and the hook clears the boots. The owner watched the original video, confirmed the shoulder turn looks natural and hook clears the legs, and explicitly requested publication. Coordinator review remained chronological frames and native phase rendering. No manual game playtest is claimed. The previous browser preview route was policy-blocked; no workaround was attempted.

Candidate selection44-80 every2frames retains19 observed poses at70ms (1330ms), accelerated from approximately1583ms. No duplicate padding, reverse poses, interpolation or per-frame rescaling.117 focused Windows candidate checks passed, including offscreen Godot battle-scale rendering. Candidate checks establish integrity; owner motion review supplies the visual acceptance decision. Only movement was published. No Linux run or full suite.

Rebuild with carry_v3/produce.py process then build. The lossless FFV1s preserve exact decoded RGB frames, alongside MP4s and workflow/prompt/source provenance. Only19 selected candidate RGBA frames are retained; other extractions and temporary reviews are rebuildable. Do not resubmit existing jobs.
