"""Rebuild Millstone's selected H3 handoff; publication remains explicit."""
import json
import sys
from pathlib import Path

ROOT = next(p for p in Path(__file__).resolve().parents if (p / 'project.godot').exists())
OUT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / 'tools'))
from publish_fluid_creature_animation import combine

TAKES = ['move_guided_v3', 'hit_guided_v2', 'cast_guided_v2']
unit = None
for take in TAKES:
    entry = json.loads((OUT / take / 'handoff.json').read_bytes())['units'][0]
    unit = combine(unit, entry)
unit['visual_review'] = {'status': 'pending', 'notes': 'Selected original video frames; autonomous native review required before explicit publication.'}
(OUT / 'handoff.json').write_text(json.dumps({'schema_version': 1, 'units': [unit]}, indent=2) + '\n', encoding='utf-8')
previous = json.loads((ROOT / 'art/animation/source/fluid' / unit['unit_id'] / 'reviewed_handoff.json').read_bytes())['units'][0]
candidate = combine(previous, unit)
candidate['preserved_accepted_clips'] = previous.get('preserved_accepted_clips', [])
target = ROOT / '.artifacts/millstone_h3'
target.mkdir(parents=True, exist_ok=True)
(target / 'combined_handoff.json').write_text(json.dumps({'schema_version': 1, 'units': [candidate]}, indent=2) + '\n', encoding='utf-8')
