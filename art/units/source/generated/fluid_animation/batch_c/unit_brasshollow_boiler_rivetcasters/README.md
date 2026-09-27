# Boiler Rivetcasters H3 animation source

Partial delivery: 167 original video frames across movement (31), melee (46), ranged (33), defense (22) and mechanical support (35). Original eight-frame 260ms articulated idle and overworld pixels are preserved. Hit, death and dead retain their earlier artwork and are not accepted as complete.

The two operators retain goggles, fabric face coverings, gloves and a left-facing wheeled cannon. Movement uses a selected reciprocal push cycle with wheel rotation; melee is an empty-fist strike; ranged uses lever-operated mounted recoil; support uses lever and valve work without magic.

`delivery.json` selects takes and records outstanding defects. `selection.json` records exact original frame indices, deliberate gameplay timing and the clean ranged frame 27 in place of ghosted frame 28. Every take preserves its prompt, guide lineage, workflows, sampler latent, original lossless video and hashes. The corrected kneeling and recoil guides preserve new original ImageGen art and provenance, including failed experiments.

Hit corrections still fail complete recoil/recovery because of changing identity or background. Death corrections still ghost the crew and morph the far wheel during collapse. Neither action is silently accepted; future work needs stronger identity and articulated rigid-chassis control, not another identical prompt.

Review covered complete chronological source sequences, enlarged anatomy/edges and loop endpoints, and all selected phases at native battle scale in offscreen Godot. Continuous playback was unavailable; sampled/phase inspection is not represented as continuous playback or a manual game test. Focused Windows checks passed: candidate 235, live 249. Source pixels, anchors, provenance, original idle/map and unrelated 231 unit records were verified. No full suite or Linux execution.

Rebuild from this directory with `produce.py process <take>`, `produce.py build <take>` for the selected takes, then `produce.py assemble`. This restores removed unselected mattes from original lossless video. Use the shared reviewed publication tool with clips `move attack ranged defend cast` and preserve-reviewed `idle`. Do not publish rejected hit/death takes.
