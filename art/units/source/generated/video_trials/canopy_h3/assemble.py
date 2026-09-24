"""Assemble selected Canopy H3 clips; rebuilt candidates await visual review."""
import json
import sys
from pathlib import Path

ROOT = next(p for p in Path(__file__).resolve().parents if (p / 'project.godot').exists())
OUT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / 'tools'))
from publish_fluid_creature_animation import combine

unit = None
for take in ['cast_v1', 'move_v1']:
    unit = combine(unit, json.loads((OUT / take / 'handoff.json').read_bytes())['units'][0])
unit['visual_review'] = {'status': 'pending', 'notes': 'Original H3 frames selected; autonomous native review required before explicit publication.'}
(OUT / 'handoff.json').write_text(json.dumps({'schema_version': 1, 'units': [unit]}, indent=2) + '\n', encoding='utf-8')
previous = json.loads((ROOT / 'art/animation/source/fluid' / unit['unit_id'] / 'reviewed_handoff.json').read_bytes())['units'][0]
candidate = combine(previous, unit)
candidate['preserved_accepted_clips'] = previous.get('preserved_accepted_clips', [])
out = ROOT / '.artifacts/canopy_h3'
out.mkdir(parents=True, exist_ok=True)
(out / 'combined_handoff.json').write_text(json.dumps({'schema_version': 1, 'units': [candidate]}, indent=2) + '\n', encoding='utf-8')
