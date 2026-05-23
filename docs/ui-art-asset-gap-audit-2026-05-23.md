# UI Art Asset Gap Audit - 2026-05-23

## Scope

Owner request: check missing art assets and generate first-pass UI elements for the overworld, battle, and town interfaces using the image generation tool.

This audit began as a study-only UI art pass for:

- `scenes/overworld/OverworldShell.tscn`
- `scenes/battle/BattleShell.tscn`
- `scenes/town/TownShell.tscn`

Runtime ingestion was approved later on 2026-05-23 for selected crops from these sheets. The first runtime pass is limited to panel/frame skins for the existing overworld, battle, and town shells; it does not replace gameplay rendering, save data, or content manifests.

## Missing-Asset Check

Command used:

```bash
python3 - <<'PY'
import json, re
from pathlib import Path
roots=[Path('scenes'),Path('scripts'),Path('content'),Path('art')]
pat=re.compile(r'res://[^"\'\s)]+\.(?:png|webp|jpg|jpeg|svg)')
refs=[]
for root in roots:
    for p in root.rglob('*'):
        if p.is_file() and p.suffix in {'.gd','.tscn','.tres','.json','.md'}:
            text=p.read_text(errors='ignore')
            for m in pat.finditer(text):
                refs.append((str(p),m.group(0)))
missing=[]
for src,ref in refs:
    if not Path(ref.replace('res://','')).exists():
        missing.append((src,ref))
print(json.dumps({'reference_count':len(refs),'missing_count':len(missing),'missing':missing[:100]}, indent=2))
PY
```

Result:

- Referenced raster/vector assets checked: `1253`
- Missing referenced assets: `0`
- Existing `art/ui` runtime assets: only `main_menu_nano_banana_backdrop.png`

Conclusion: there are no broken UI image references. The actual gap is that the overworld, battle, and town interfaces are still mostly procedural Godot panels, labels, flat colors, and code-drawn glyphs/stage art rather than having a production UI skin.

## Generated Study Candidates

Generated with the built-in image generation tool, then converted from a flat chroma-key background to alpha PNGs with:

```bash
python3 "${CODEX_HOME:-$HOME/.codex}/skills/.system/imagegen/scripts/remove_chroma_key.py" \
  --input <chromakey-source> \
  --out <transparent-output> \
  --auto-key border \
  --soft-matte \
  --transparent-threshold 12 \
  --opaque-threshold 220 \
  --despill
```

Tracked study outputs:

| Interface | Candidate asset | Size | Mode | SHA-256 |
| --- | --- | --- | --- | --- |
| Overworld | `docs/art-studies/ui/2026-05-23/overworld_ui_skin_sheet_transparent.png` | `1536x1024` | `RGBA` | `758d85c91af6b7810f0e66b03e64c93c2fad2787ba19e8c1c535fb97e29c1951` |
| Battle | `docs/art-studies/ui/2026-05-23/battle_ui_skin_sheet_transparent.png` | `1536x1024` | `RGBA` | `cbcce2b590d1370fdee8c780b011cdbedaf33f8488104e8d42e3b75e73a7f051` |
| Town | `docs/art-studies/ui/2026-05-23/town_ui_skin_sheet_transparent.png` | `1536x1024` | `RGBA` | `47b58e308104ad199691ce531b79e3bf66850fbc192c73d234450532011dcc21` |

Alpha validation:

- All three final PNGs are `RGBA`.
- All four image corners are transparent.
- Each sheet has substantial opaque UI element coverage and antialiased partial-alpha edges.

## Prompt Summary

Common constraints:

- Original fantasy strategy UI, no copied game style.
- No text, letters, numbers, logos, or watermarks.
- Isolated UI elements on flat `#00ff00` chroma-key source.
- Materials and palette aligned with current game direction: aged wood, worn parchment, muted brass, dark iron, stone, restrained teal/burgundy accents.

Per-interface generated content:

- Overworld: resource bar, side-rail frame, minimap frame, command plates, medallions, route badge, hero portrait frame, ornaments.
- Battle: initiative track, active unit card, stack badge, health/morale meter frames, hex-selection ring, command plates, combat log and confirmation frames.
- Town: banner, crest medallion, construction card, recruitment/garrison frames, resource ledger, upgrade plaque, defense badge, town tabs, corner filigree.

## Runtime Ingestion

Selected crops from the study sheets were imported under `art/ui/runtime/` and wired through `scripts/ui/FrontierVisualKit.gd` as `StyleBoxTexture` panel skins. The existing flat `StyleBoxFlat` theme remains the fallback when a texture path is missing or invalid.

Runtime crop outputs:

- `art/ui/runtime/overworld/resource_bar.png`
- `art/ui/runtime/overworld/sidebar_frame.png`
- `art/ui/runtime/overworld/parchment_panel.png`
- `art/ui/runtime/overworld/wood_panel.png`
- `art/ui/runtime/overworld/minimap_frame.png`
- `art/ui/runtime/overworld/command_button.png`
- `art/ui/runtime/overworld/hero_frame.png`
- `art/ui/runtime/battle/initiative_bar.png`
- `art/ui/runtime/battle/combat_log_panel.png`
- `art/ui/runtime/battle/unit_card.png`
- `art/ui/runtime/battle/hex_focus_ring.png`
- `art/ui/runtime/battle/command_button_red.png`
- `art/ui/runtime/battle/command_button_blue.png`
- `art/ui/runtime/battle/battle_footer_panel.png`
- `art/ui/runtime/town/banner_frame.png`
- `art/ui/runtime/town/crest_medallion.png`
- `art/ui/runtime/town/parchment_panel.png`
- `art/ui/runtime/town/recruit_row.png`
- `art/ui/runtime/town/resource_ledger.png`
- `art/ui/runtime/town/build_panel.png`
- `art/ui/runtime/town/town_button.png`

Runtime wiring:

- `scripts/ui/FrontierVisualKit.gd` now exposes texture-backed panel helpers.
- `scenes/overworld/OverworldShell.gd` applies overworld frame/resource/sidebar/hero panel skins.
- `scenes/battle/BattleShell.gd` applies battle banner/log/unit/footer panel skins.
- `scenes/town/TownShell.gd` applies town banner/crest/parchment/recruit/ledger/build panel skins.

Non-headless screenshot validation:

```bash
GODOT_SILENCE_ROOT_WARNING=1 xvfb-run -a godot4 --path . tests/ui_runtime_skin_visual_report.tscn
```

Result: passed. The report asserts selected panels in all three shells are backed by the expected runtime `StyleBoxTexture` resources and writes screenshots to `.artifacts/ui_runtime_skin_visual_report/overworld.png`, `.artifacts/ui_runtime_skin_visual_report/battle.png`, and `.artifacts/ui_runtime_skin_visual_report/town.png`.

Visual inspection: the generated screenshots show the runtime skins applied to the live shells with readable text and without blocking the dominant overworld map, battle board, or town stage surfaces.

## Remaining Boundary

This first ingestion pass does not claim final UI art approval. Later UI art slices should:

- Replace generated-study-derived crops with curated production art when final art direction is approved.
- Keep rollback simple by routing texture use through `FrontierVisualKit`.
- Continue screenshot validation for overworld, battle, and town at supported viewports when changing UI skins.
- Avoid covering play surfaces with additional report panels or decorative frames.
